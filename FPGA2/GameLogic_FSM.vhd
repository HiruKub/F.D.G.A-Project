--------------------------------------------------------------------------------
-- Project    : FPGA Camera-Based Monster Battle System (EDGE Spartan-7 Dual Board)
-- Module     : GameLogic_FSM.vhd
-- Target     : Xilinx Spartan-7 (XC7S15) / Vivado
-- Description: Core Game Logic Engine & Finite State Machine for FPGA 2
--              - 5-Button Control (Up, Down, Left, Right, Enter) with Debounce & Edge Detection
--              - Title Screen (ST_TITLE)
--              - All-in-One VGA Interface (Outputs to FPGA 1 VGA Compositor)
--              - Monster Selection & Inventory Persistence
--              - Camera Enemy Spawn (ST_CAM_CAPTURE uses 1.5s Auto-Timer ONLY to ensure SPI data arrives)
--              - Battle System (Action Menu, Skills, Capture, Run)
--              - Safe Capture: Prevents downgrading inventory level
--              - 8-bit Level-Scaled Damage & HP System:
--                  * Max HP = (Level * 2) + 16 (8 bits: 0..255)
--                  * Base DMG = (Level / 2) + 2 (8 bits: 0..255)
--                  * Elemental: Advantage x2, Neutral x1, Disadvantage /2
--                  * Capture: HP <= 25% of Max HP (or <= 4)
--              - Onboard LED Diagnostics:
--                  * led(1:0) = enemy_type_in (Dominant color element)
--                  * led(2)   = enemy_lvl_lsb_in (Level offset)
--                  * led(3)   = '1' during ST_CAM_CAPTURE (Snapshot active)
--                  * led(7:4) = state_code_out (Current Opcode 0..13)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity GameLogic_FSM is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000; -- 50 MHz Master Clock
        BUTTON_ACTIVE_LOW : boolean := TRUE
    );
    port (
        clk : in std_logic;
        reset : in std_logic; -- Active-High System Reset

        -- Physical Push Buttons (Raw Inputs with internal Debounce)
        btn_up_raw : in std_logic; -- D-PAD UP
        btn_down_raw : in std_logic; -- D-PAD DOWN
        btn_left_raw : in std_logic; -- D-PAD LEFT
        btn_right_raw : in std_logic; -- D-PAD RIGHT
        btn_enter_raw : in std_logic; -- ENTER / ACTION / CONFIRM

        -- Enemy Data Interface from FPGA 1 (via SPI status byte)
        enemy_type_in : in std_logic_vector(1 downto 0); -- Dominant Element (00: Fire, 01: Plant, 10: Water)
        enemy_lvl_lsb_in : in std_logic; -- 2nd Color LSB ('0' = Lv, '1' = Lv+5)

        ------------------------------------------------------------------------
        -- Interface to FPGA 1 (VGA Compositor & HUD Renderer)
        ------------------------------------------------------------------------
        -- Scene State Code (Opcode 4-bit):
        -- 0000: Title, 0001: Select Mon, 0010: Camera, 0011: Capture Cam,
        -- 0100: Prepare, 0101: Action Menu, 0110: Skill Menu, 0111: Player Atk,
        -- 1000: Enemy Atk, 1001: Capt Monster, 1010: Evade, 1011: Victory,
        -- 1100: Loss, 1101: VictoryCap
        state_code_out : out std_logic_vector(3 downto 0);

        -- Cursor / Selection Indices for VGA Box rendering
        cursor_out : out std_logic_vector(1 downto 0);

        -- Player Monster Status Outputs (Top-Left HUD)
        player_type_out : out std_logic_vector(1 downto 0); -- 00: Fire, 01: Plant, 10: Water
        player_lvl_out : out std_logic_vector(5 downto 0); -- Current Level (6 bits: 0..63)
        player_hp_out : out std_logic_vector(7 downto 0); -- Current HP (8 bits: 0..255)
        player_max_hp_o : out std_logic_vector(7 downto 0); -- Max HP (8 bits: 0..255)

        -- Enemy Monster Status Outputs (Top-Right HUD)
        enemy_type_out : out std_logic_vector(1 downto 0); -- Dominant Element
        enemy_lvl_out : out std_logic_vector(5 downto 0); -- Current Level (6 bits: 0..63)
        enemy_hp_out : out std_logic_vector(7 downto 0); -- Current HP (8 bits: 0..255)
        enemy_max_hp_o : out std_logic_vector(7 downto 0); -- Max HP (8 bits: 0..255)

        -- Diagnostic Onboard LEDs (Displays received camera data & Opcode)
        led : out std_logic_vector(7 downto 0)
    );
end entity GameLogic_FSM;

architecture Behavioral of GameLogic_FSM is

    -- Element Type Constants (2 bits)
    constant ELEM_FIRE : std_logic_vector(1 downto 0) := "00";
    constant ELEM_PLANT : std_logic_vector(1 downto 0) := "01";
    constant ELEM_WATER : std_logic_vector(1 downto 0) := "10";
    -- FSM State Definitions
    type state_type is (
        ST_INIT,
        ST_TITLE, -- 0: หน้าแรก (Title Screen)
        ST_SELECT_MON, -- 1: ฉากเลือกมอนสเตอร์ในคลัง (3 ตัวเริ่มต้น Lv 1)
        ST_CAM_LIVE, -- 2: ส่องกล้องดูภาพสด (Live Camera Feed)
        ST_CAM_CAPTURE, -- 3: แช่ภาพนิ่ง (Snapshot Freeze) และรับผลสแกนสี
        ST_BATTLE_INTRO, -- 4: ฉากเปิดตัวศัตรู (Prepare / Wild Monster Appeared)
        ST_ACTION_MENU, -- 5: เมนูคำสั่งหลัก (0: ATK, 1: CAPT, 2: RUN)
        ST_SKILL_MENU, -- 6: เมนูเลือกสกิล (0: Elemental, 1: Normal)
        ST_PLAYER_ATK, -- 7: ผู้เล่นโจมตี (คิดดาเมจ ชนะ x2 / เสมอ x1 / แพ้ /2)
        ST_ENEMY_ATK, -- 8: ศัตรูโจมตีสวน
        ST_CAPTURE_TRY, -- 9: ตรวจสอบเงื่อนไขจับมอนสเตอร์ (HP <= 25% of Max HP)
        ST_RUN_ESCAPE, -- 10: หลบหนีออกจากการต่อสู้ (Evade)
        ST_VICTORYKO, -- 11: ได้รับชัยชนะเพราะตีตาย (Victory)
        ST_DEFEAT, -- 12: พ่ายแพ้ (Loss)
        ST_VICTORYCAP -- 13: ได้รับชัยชนะเพราะจับสำเร็จ (VictoryCap)
    );

    signal current_state : state_type := ST_INIT;

    -- Internal State Code signal
    signal state_code_int : std_logic_vector(3 downto 0) := "0000";

    -- Debounced Single-Clock Rising-Edge Button Pulses (from u_debounce)
    signal btn_up_pulse, btn_down_pulse, btn_left_pulse, btn_right_pulse, btn_enter_pulse : std_logic := '0';

    -- Persistent Monster Inventory (Levels start at 1, max 63)
    signal inv_lvl_fire : unsigned(5 downto 0) := to_unsigned(1, 6);
    signal inv_lvl_plant : unsigned(5 downto 0) := to_unsigned(1, 6);
    signal inv_lvl_water : unsigned(5 downto 0) := to_unsigned(1, 6);

    -- Active Battle Registers (8-bit HP: Default Level 1 HP = (1*2) + 16 = 18)
    signal p_type : std_logic_vector(1 downto 0) := ELEM_FIRE;
    signal p_level : unsigned(5 downto 0) := to_unsigned(1, 6);
    signal p_hp : unsigned(7 downto 0) := to_unsigned(18, 8);
    signal p_max_hp : unsigned(7 downto 0) := to_unsigned(18, 8);

    signal e_type : std_logic_vector(1 downto 0) := ELEM_PLANT;
    signal e_level : unsigned(5 downto 0) := to_unsigned(1, 6);
    signal e_hp : unsigned(7 downto 0) := to_unsigned(18, 8);
    signal e_max_hp : unsigned(7 downto 0) := to_unsigned(18, 8);

    -- Cursor Selection Registers
    signal mon_select_idx : unsigned(1 downto 0) := "00"; -- 0: Fire, 1: Plant, 2: Water
    signal menu_idx : unsigned(1 downto 0) := "00"; -- 0: ATK, 1: CAPT, 2: RUN
    signal skill_idx : std_logic := '0'; -- 0: Normal Tackle, 1: Elemental Strike

    -- Timer for Animations/Pauses/Snapshot (1.5 seconds @ CLK_FREQ_HZ)
    constant TIMER_1_5_SEC : integer := (CLK_FREQ_HZ * 3) / 2;
    signal timer_cnt : integer range 0 to TIMER_1_5_SEC := 0;
    signal timer_done : std_logic := '0';

    -- Prev state
    signal prev_state : state_type := ST_INIT;
    ----------------------------------------------------------------------------
    -- 8-bit Level-Scaled Damage Calculator Function
    -- Base DMG = (Attacker_Level / 2) + 2
    -- Rules:
    --   Advantage    = Base * 2 (Shift left 1)
    --   Neutral      = Base * 1
    --   Disadvantage = Base / 2 (Shift right 1, minimum 1)
    ----------------------------------------------------------------------------
    function calc_damage(
        atk_type : std_logic_vector(1 downto 0);
        def_type : std_logic_vector(1 downto 0);
        atk_level : unsigned(5 downto 0);
        is_elem_skill : std_logic
    ) return unsigned is
        variable base_dmg : unsigned(7 downto 0);
        variable dmg : unsigned(7 downto 0);
    begin
        -- Base DMG scales with level: (atk_level / 2) + 2 (8-bit representation)
        base_dmg := ("000" & atk_level(5 downto 1)) + 2;

        if is_elem_skill = '0' then
            -- Normal Tackle: Flat Base DMG (scaled with Level, neutral to element)
            dmg := base_dmg;
        else
            -- Elemental Strike: Type Matching
            if (atk_type = ELEM_FIRE and def_type = ELEM_PLANT) or
                (atk_type = ELEM_PLANT and def_type = ELEM_WATER) or
                (atk_type = ELEM_WATER and def_type = ELEM_FIRE) then
                -- Advantage: Base * 2 (Shift left 1)
                dmg := base_dmg(6 downto 0) & '0';
            elsif (atk_type = def_type) then
                -- Neutral: Base * 1
                dmg := base_dmg;
            else
                -- Disadvantage: Base / 2 (Shift right 1, minimum 1)
                dmg := "0" & base_dmg(7 downto 1);
                if dmg = 0 then
                    dmg := to_unsigned(1, 8);
                end if;
            end if;
        end if;
        return dmg;
    end function;

    ----------------------------------------------------------------------------
    -- 8-bit Normalized HP Mapping Function (Scale to 0..255)
    -- Formula: (current_hp * 255) / max_hp
    -- Ensures full health bar = 255 pixels for FPGA 1 VGA renderer
    ----------------------------------------------------------------------------
    function map_hp_255(
        cur_hp : unsigned(7 downto 0);
        max_hp : unsigned(7 downto 0)
    ) return std_logic_vector is
        variable temp : unsigned(15 downto 0);
        variable res : unsigned(15 downto 0);
    begin
        if cur_hp = 0 or max_hp = 0 then
            return x"00";
        elsif cur_hp >= max_hp then
            return x"FF";
        else
            temp := cur_hp * to_unsigned(255, 8);
            res := temp / max_hp;
            return std_logic_vector(res(7 downto 0));
        end if;
    end function;

begin

    ----------------------------------------------------------------------------
    -- 1. Hardware Debounce & Edge Detector Sub-Module Instantiation
    ----------------------------------------------------------------------------
    u_debounce : entity work.btn_debounce
        generic map(
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            BUTTON_ACTIVE_LOW => BUTTON_ACTIVE_LOW
        )
        port map(
            clk => clk,
            reset => reset,
            btn_up_raw => btn_up_raw,
            btn_down_raw => btn_down_raw,
            btn_left_raw => btn_left_raw,
            btn_right_raw => btn_right_raw,
            btn_enter_raw => btn_enter_raw,
            btn_up_pulse => btn_up_pulse,
            btn_down_pulse => btn_down_pulse,
            btn_left_pulse => btn_left_pulse,
            btn_right_pulse => btn_right_pulse,
            btn_enter_pulse => btn_enter_pulse
        );

    ----------------------------------------------------------------------------
    -- 2. State & Datapath Synchronous Process
    ----------------------------------------------------------------------------
    p_fsm_sync : process (clk, reset)
        variable calc_dmg : unsigned(7 downto 0);
        variable capt_limit : unsigned(7 downto 0);
        variable spawn_lvl : unsigned(5 downto 0);
    begin
        if reset = '1' then
            current_state <= ST_INIT;
            prev_state <= ST_INIT;
            mon_select_idx <= "00";
            cursor_out <= "00";
            menu_idx <= "00";
            skill_idx <= '0';
            timer_cnt <= 0;
            timer_done <= '0';

            -- Reset Inventory Levels to 1 (Max 63)
            inv_lvl_fire <= to_unsigned(1, 6);
            inv_lvl_plant <= to_unsigned(1, 6);
            inv_lvl_water <= to_unsigned(1, 6);

            -- Default Level 1 HP = (1*2) + 16 = 18 (8-bit)
            p_type <= ELEM_FIRE;
            p_level <= to_unsigned(1, 6);
            p_hp <= to_unsigned(18, 8);
            p_max_hp <= to_unsigned(18, 8);

            e_type <= ELEM_PLANT;
            e_level <= to_unsigned(1, 6);
            e_hp <= to_unsigned(18, 8);
            e_max_hp <= to_unsigned(18, 8);

        elsif rising_edge(clk) then
            prev_state <= current_state;
            if current_state /= prev_state then
                timer_cnt <= 0;
                timer_done <= '0';
                -- Animation, Pause & Snapshot Delay Timer
            elsif current_state = ST_CAM_CAPTURE or
                current_state = ST_BATTLE_INTRO or
                current_state = ST_PLAYER_ATK or
                current_state = ST_ENEMY_ATK or
                current_state = ST_CAPTURE_TRY then
                if timer_cnt = TIMER_1_5_SEC then
                    timer_done <= '1';
                    timer_cnt <= 0;
                else
                    timer_cnt <= timer_cnt + 1;
                    timer_done <= '0';
                end if;
            else
                timer_cnt <= 0;
                timer_done <= '0';
            end if;

            -- Default Cursor output is 0
            cursor_out <= "00";

            -- State Transitions & Game Logic
            case current_state is
                when ST_INIT =>
                    current_state <= ST_TITLE;

                    ----------------------------------------------------------------
                    -- ST_TITLE: หน้าแรกของเกม (กด Enter เพื่อเริ่มเกม)
                    ----------------------------------------------------------------
                when ST_TITLE =>
                    if btn_enter_pulse = '1' then
                        current_state <= ST_SELECT_MON;
                        mon_select_idx <= "00";
                    end if;

                    ----------------------------------------------------------------
                    -- ST_SELECT_MON: เลือกมอนสเตอร์ในคลัง (3 ตัวเริ่มต้น Lv 1)
                    -- ปุ่ม ซ้าย (Left) / ขวา (Right) เลื่อนเลือกมอนสเตอร์
                    -- ปุ่ม Enter ยืนยัน
                    -- Max HP = (Level * 2) + 16 (8-bit)
                    ----------------------------------------------------------------
                when ST_SELECT_MON =>
                    if btn_left_pulse = '1' or btn_up_pulse = '1' then
                        if mon_select_idx = "00" then
                            mon_select_idx <= "10";
                        else
                            mon_select_idx <= mon_select_idx - 1;
                        end if;
                    elsif btn_right_pulse = '1' or btn_down_pulse = '1' then
                        if mon_select_idx = "10" then
                            mon_select_idx <= "00";
                        else
                            mon_select_idx <= mon_select_idx + 1;
                        end if;
                    end if;

                    cursor_out <= std_logic_vector(mon_select_idx);

                    case mon_select_idx is
                        when "00" =>
                            p_type <= ELEM_FIRE;
                            p_level <= inv_lvl_fire;
                            p_max_hp <= ("0" & inv_lvl_fire & '0') + 16;
                            p_hp <= ("0" & inv_lvl_fire & '0') + 16;
                        when "01" =>
                            p_type <= ELEM_PLANT;
                            p_level <= inv_lvl_plant;
                            p_max_hp <= ("0" & inv_lvl_plant & '0') + 16;
                            p_hp <= ("0" & inv_lvl_plant & '0') + 16;
                        when others =>
                            p_type <= ELEM_WATER;
                            p_level <= inv_lvl_water;
                            p_max_hp <= ("0" & inv_lvl_water & '0') + 16;
                            p_hp <= ("0" & inv_lvl_water & '0') + 16;
                    end case;

                    -- Confirm Selected Monster
                    if btn_enter_pulse = '1' then
                        current_state <= ST_CAM_LIVE;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_CAM_LIVE (Opcode 2): ส่องกล้องดูภาพสด รอกดชัตเตอร์ (Enter)
                    ----------------------------------------------------------------
                when ST_CAM_LIVE =>
                    if btn_enter_pulse = '1' then
                        current_state <= ST_CAM_CAPTURE;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_CAM_CAPTURE (Opcode 3): แช่ภาพนิ่ง รอ FPGA 1 ประมวลผลเสร็จ
                    -- ปลดล็อกด้วย Timer 1.5 วินาทีอัตโนมัติ (ไม่เปิดให้กด Enter ข้าม
                    -- เพื่อการันตีว่า FPGA 1 มีเวลานับสีเสร็จและส่งข้อมูล SPI กลับมาครบ)
                    ----------------------------------------------------------------
                when ST_CAM_CAPTURE =>
                    if timer_done = '1' then
                        -- ชนิดศัตรู: รับตรงจาก FPGA 1 (2 บิต: 00=Fire, 01=Plant, 10=Water)
                        case enemy_type_in is
                            when ELEM_FIRE => e_type <= ELEM_FIRE;
                            when ELEM_PLANT => e_type <= ELEM_PLANT;
                            when ELEM_WATER => e_type <= ELEM_WATER;
                            when others => e_type <= ELEM_FIRE;
                        end case;

                        -- เลเวลศัตรู: รับบิต LSB สีที่ 2 จาก FPGA 1 ('0' = เท่าเรา, '1' = เรา + 5)
                        if enemy_lvl_lsb_in = '1' then
                            if p_level > 58 then
                                spawn_lvl := to_unsigned(63, 6);
                            else
                                spawn_lvl := p_level + 5;
                            end if;
                        else
                            spawn_lvl := p_level;
                        end if;

                        e_level <= spawn_lvl;
                        e_max_hp <= ("0" & spawn_lvl & '0') + 16;
                        e_hp <= ("0" & spawn_lvl & '0') + 16;

                        current_state <= ST_BATTLE_INTRO;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_BATTLE_INTRO: เปิดตัวศัตรู (กด Enter เพื่อข้าม)
                    ----------------------------------------------------------------
                when ST_BATTLE_INTRO =>
                    if timer_done = '1' or btn_enter_pulse = '1' then
                        current_state <= ST_ACTION_MENU;
                        menu_idx <= "00";
                    end if;

                    ----------------------------------------------------------------
                    -- ST_ACTION_MENU: เมนูคำสั่งหลัก (0: ATK, 1: CAPT, 2: RUN)
                    -- ปุ่ม บน/ล่าง เลื่อนเมนู, ปุ่ม Enter ยืนยัน
                    ----------------------------------------------------------------
                when ST_ACTION_MENU =>
                    -- 2D Grid Menu Navigation:
                    -- Top Row   : [ATK ("00")]   [CAPT ("01")]
                    -- Bottom Row: [RUN ("10")]
                    case menu_idx is
                        when "00" => -- ATK (Top-Left)
                            if btn_right_pulse = '1' then
                                menu_idx <= "01"; -- ขวา ไป CAPT
                            elsif btn_down_pulse = '1' then
                                menu_idx <= "10"; -- ล่าง ไป RUN (ใต้ ATK)
                            elsif btn_left_pulse = '1' then
                                menu_idx <= "01"; -- ซ้าย วนไป CAPT
                            elsif btn_up_pulse = '1' then
                                menu_idx <= "10"; -- บน วนไป RUN
                            end if;

                        when "01" => -- CAPT (Top-Right)
                            if btn_left_pulse = '1' then
                                menu_idx <= "00"; -- ซ้าย ไป ATK
                            elsif btn_down_pulse = '1' then
                                menu_idx <= "10"; -- ล่าง ไป RUN
                            elsif btn_right_pulse = '1' then
                                menu_idx <= "00"; -- ขวา วนไป ATK
                            elsif btn_up_pulse = '1' then
                                menu_idx <= "10"; -- บน วนไป RUN
                            end if;

                        when others => -- RUN ("10", Bottom-Left)
                            if btn_up_pulse = '1' then
                                menu_idx <= "00"; -- บน ไป ATK (บน RUN)
                            elsif btn_right_pulse = '1' then
                                menu_idx <= "01"; -- ขวา ไป CAPT
                            elsif btn_down_pulse = '1' then
                                menu_idx <= "00"; -- ล่าง วนไป ATK
                            elsif btn_left_pulse = '1' then
                                menu_idx <= "01"; -- ซ้าย วนไป CAPT
                            end if;
                    end case;
                    cursor_out <= std_logic_vector(menu_idx);

                    if btn_enter_pulse = '1' then
                        case menu_idx is
                            when "00" => -- ATK
                                current_state <= ST_SKILL_MENU;
                                skill_idx <= '0';
                            when "01" => -- CAPT
                                current_state <= ST_CAPTURE_TRY;
                            when others => -- RUN
                                current_state <= ST_RUN_ESCAPE;
                        end case;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_SKILL_MENU: เลือกสกิล (0: Normal Tackle, 1: Elemental Strike)
                    -- ปุ่ม บน/ล่าง สลับสกิล, ปุ่ม Enter โจมตี
                    ----------------------------------------------------------------
                when ST_SKILL_MENU =>
                    if btn_up_pulse = '1' or btn_down_pulse = '1' or btn_left_pulse = '1' or btn_right_pulse = '1' then
                        skill_idx <= not skill_idx;
                    end if;
                    cursor_out <= "0" & skill_idx;

                    if btn_enter_pulse = '1' then
                        current_state <= ST_PLAYER_ATK;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_PLAYER_ATK: ผู้เล่นโจมตี (8-bit Level Scaled Damage)
                    ----------------------------------------------------------------
                when ST_PLAYER_ATK =>
                    calc_dmg := calc_damage(p_type, e_type, p_level, skill_idx);
                    cursor_out <= "0" & skill_idx;
                    if timer_done = '1' or btn_enter_pulse = '1' then
                        if e_hp <= calc_dmg then
                            e_hp <= (others => '0');
                            current_state <= ST_VICTORYKO;
                        else
                            e_hp <= e_hp - calc_dmg;
                            current_state <= ST_ENEMY_ATK;
                        end if;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_ENEMY_ATK: ศัตรูโจมตีสวน (8-bit Level Scaled Elemental Strike)
                    ----------------------------------------------------------------
                when ST_ENEMY_ATK =>
                    calc_dmg := calc_damage(e_type, p_type, e_level, '1');
                    cursor_out <= "0" & '1';
                    if timer_done = '1' or btn_enter_pulse = '1' then
                        if p_hp <= calc_dmg then
                            p_hp <= (others => '0');

                            -- ลด Level ในคลังลง 1 เมื่อพ่ายแพ้ (ขั้นต่ำ Level 1)
                            case p_type is
                                when ELEM_FIRE =>
                                    if inv_lvl_fire > 1 then
                                        inv_lvl_fire <= inv_lvl_fire - 1;
                                    end if;
                                when ELEM_PLANT =>
                                    if inv_lvl_plant > 1 then
                                        inv_lvl_plant <= inv_lvl_plant - 1;
                                    end if;
                                when others => -- ELEM_WATER
                                    if inv_lvl_water > 1 then
                                        inv_lvl_water <= inv_lvl_water - 1;
                                    end if;
                            end case;

                            if p_level > 1 then
                                p_level <= p_level - 1;
                            end if;

                            current_state <= ST_DEFEAT;
                        else
                            p_hp <= p_hp - calc_dmg;
                            current_state <= ST_ACTION_MENU;
                            menu_idx <= "00";
                        end if;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_CAPTURE_TRY: ตรวจสอบจับศัตรู
                    -- เกณฑ์สำเร็จ: เลือดเหลือ <= 25% ของ Max HP (e_max_hp / 4) หรือ <= 4
                    ----------------------------------------------------------------
                when ST_CAPTURE_TRY =>
                    capt_limit := "00" & e_max_hp(7 downto 2); -- Max HP / 4
                    if capt_limit < 4 then
                        capt_limit := to_unsigned(4, 8);
                    end if;

                    if timer_done = '1' or btn_enter_pulse = '1' then
                        if e_hp <= capt_limit then
                            -- จับสำเร็จ: บันทึกเฉพาะเมื่อศัตรูมีเลเวลสูงกว่าเดิมในคลัง (ป้องกันเลเวลลดลง)
                            case e_type is
                                when ELEM_FIRE =>
                                    if e_level > inv_lvl_fire then
                                        inv_lvl_fire <= e_level;
                                    elsif inv_lvl_fire < 63 then
                                        inv_lvl_fire <= inv_lvl_fire + 1;
                                    end if;

                                when ELEM_PLANT =>
                                    if e_level > inv_lvl_plant then
                                        inv_lvl_plant <= e_level;
                                    elsif inv_lvl_plant < 63 then
                                        inv_lvl_plant <= inv_lvl_plant + 1;
                                    end if;

                                when others =>
                                    if e_level > inv_lvl_water then
                                        inv_lvl_water <= e_level;
                                    elsif inv_lvl_water < 63 then
                                        inv_lvl_water <= inv_lvl_water + 1;
                                    end if;
                            end case;

                            -- หากจับตัวที่ต่างธาตุกับตัวเรา มอนสเตอร์ตัวที่กำลังใช้อยู่จะได้ Level +1 ด้วย
                            if p_type /= e_type then
                                case p_type is 
                                    when ELEM_FIRE =>
                                        if inv_lvl_fire < 63 then
                                            inv_lvl_fire <= inv_lvl_fire + 1;
                                        end if;
                                    when ELEM_PLANT =>
                                        if inv_lvl_plant < 63 then
                                            inv_lvl_plant <= inv_lvl_plant + 1;
                                        end if;
                                    when ELEM_WATER =>
                                        if inv_lvl_water < 63 then
                                            inv_lvl_water <= inv_lvl_water + 1;
                                        end if;
                                    when others =>
                                        null;
                                end case;
                            end if;
                            current_state <= ST_VICTORYCAP;
                        else
                            -- จับไม่สำเร็จ: โดนศัตรูโจมตีสวนฟรี 1 ครั้ง
                            current_state <= ST_ENEMY_ATK;
                        end if;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_RUN_ESCAPE: วิ่งหนีสำเร็จ -> กด Enter กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                when ST_RUN_ESCAPE =>
                    if btn_enter_pulse = '1' then
                        current_state <= ST_SELECT_MON;
                    end if;

                    ----------------------------------------------------------------
                    -- ST_VICTORYKO / ST_DEFEAT / ST_VICTORYCAP: จบการต่อสู้ -> กด Enter กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                when ST_VICTORYKO | ST_DEFEAT | ST_VICTORYCAP =>
                    if btn_enter_pulse = '1' then
                        current_state <= ST_SELECT_MON;
                    end if;

                when others =>
                    cursor_out <= "00";
                    current_state <= ST_INIT;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 3. Output Assignment Process (Combinational Mapping for FPGA 1)
    ----------------------------------------------------------------------------

    -- Monster Status (HP mapped to full-scale 0..255 for FPGA 1 VGA bar)
    player_type_out <= p_type;
    player_lvl_out <= std_logic_vector(p_level);
    player_hp_out <= map_hp_255(p_hp, p_max_hp);
    player_max_hp_o <= x"FF"; -- Always 255 for full-scale health bar

    enemy_type_out <= e_type;
    enemy_lvl_out <= std_logic_vector(e_level);
    enemy_hp_out <= map_hp_255(e_hp, e_max_hp);
    enemy_max_hp_o <= x"FF"; -- Always 255 for full-scale health bar

    -- State Code for VGA Scene Compositor (Opcode 4-bit)
    process (current_state)
    begin
        case current_state is
            when ST_TITLE => state_code_int <= "0000"; -- 0: Title
            when ST_SELECT_MON => state_code_int <= "0001"; -- 1: select char
            when ST_CAM_LIVE => state_code_int <= "0010"; -- 2: camera
            when ST_CAM_CAPTURE => state_code_int <= "0011"; -- 3: capture
            when ST_BATTLE_INTRO => state_code_int <= "0100"; -- 4: prepare
            when ST_ACTION_MENU => state_code_int <= "0101"; -- 5: action
            when ST_SKILL_MENU => state_code_int <= "0110"; -- 6: skill menu
            when ST_PLAYER_ATK => state_code_int <= "0111"; -- 7: ATK
            when ST_ENEMY_ATK => state_code_int <= "1000"; -- 8: E ATK
            when ST_CAPTURE_TRY => state_code_int <= "1001"; -- 9: Capt
            when ST_RUN_ESCAPE => state_code_int <= "1010"; -- 10: Evade
            when ST_VICTORYKO => state_code_int <= "1011"; -- 11: Victory
            when ST_DEFEAT => state_code_int <= "1100"; -- 12: Loss
            when ST_VICTORYCAP => state_code_int <= "1101"; -- 13: VictoryCap
            when others => state_code_int <= "0000";
        end case;
    end process;

    state_code_out <= state_code_int;

    ----------------------------------------------------------------------------
    -- 4. Diagnostic LED Outputs
    -- led(1:0) = enemy_type_in (00: Fire, 01: Plant, 10: Water)
    -- led(2)   = enemy_lvl_lsb_in (0: same lv, 1: lv+5)
    -- led(3)   = '1' during ST_CAM_CAPTURE (Snapshot active)
    -- led(7:4) = state_code_out (Current Opcode 0..13)
    ----------------------------------------------------------------------------
    led(1 downto 0) <= enemy_type_in;
    led(2) <= enemy_lvl_lsb_in;
    led(3) <= '1' when current_state = ST_CAM_CAPTURE else
    '0';
    led(7 downto 4) <= state_code_int;

end architecture Behavioral;