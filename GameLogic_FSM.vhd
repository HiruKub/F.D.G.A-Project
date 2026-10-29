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

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY GameLogic_FSM IS
    GENERIC (
        CLK_FREQ_HZ : INTEGER := 50_000_000; -- 50 MHz Master Clock
        BUTTON_ACTIVE_LOW : BOOLEAN := TRUE
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC; -- Active-High System Reset

        -- Physical Push Buttons (Raw Inputs with internal Debounce)
        btn_up_raw : IN STD_LOGIC; -- D-PAD UP
        btn_down_raw : IN STD_LOGIC; -- D-PAD DOWN
        btn_left_raw : IN STD_LOGIC; -- D-PAD LEFT
        btn_right_raw : IN STD_LOGIC; -- D-PAD RIGHT
        btn_enter_raw : IN STD_LOGIC; -- ENTER / ACTION / CONFIRM

        -- Enemy Data Interface from FPGA 1 (via SPI status byte)
        enemy_type_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- Dominant Element (00: Fire, 01: Plant, 10: Water)
        enemy_lvl_lsb_in : IN STD_LOGIC; -- 2nd Color LSB ('0' = Lv, '1' = Lv+5)

        ------------------------------------------------------------------------
        -- Interface to FPGA 1 (VGA Compositor & HUD Renderer)
        ------------------------------------------------------------------------
        -- Scene State Code (Opcode 4-bit):
        -- 0000: Title, 0001: Select Mon, 0010: Camera, 0011: Capture Cam,
        -- 0100: Prepare, 0101: Action Menu, 0110: Skill Menu, 0111: Player Atk,
        -- 1000: Enemy Atk, 1001: Capt Monster, 1010: Evade, 1011: Victory,
        -- 1100: Loss, 1101: VictoryCap
        state_code_out : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- Cursor / Selection Indices for VGA Box rendering
        cursor_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);

        -- Player Monster Status Outputs (Top-Left HUD)
        player_type_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- 00: Fire, 01: Plant, 10: Water
        player_lvl_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current Level (6 bits: 0..63)
        player_hp_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Current HP (8 bits: 0..255)
        player_max_hp_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Max HP (8 bits: 0..255)

        -- Enemy Monster Status Outputs (Top-Right HUD)
        enemy_type_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- Dominant Element
        enemy_lvl_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current Level (6 bits: 0..63)
        enemy_hp_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Current HP (8 bits: 0..255)
        enemy_max_hp_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Max HP (8 bits: 0..255)

        -- Diagnostic Onboard LEDs (Displays received camera data & Opcode)
        led : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ENTITY GameLogic_FSM;

ARCHITECTURE Behavioral OF GameLogic_FSM IS

    -- Element Type Constants (2 bits)
    CONSTANT ELEM_FIRE : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    CONSTANT ELEM_PLANT : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
    CONSTANT ELEM_WATER : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
    -- FSM State Definitions
    TYPE state_type IS (
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

    SIGNAL current_state : state_type := ST_INIT;

    -- Internal State Code signal
    SIGNAL state_code_int : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";

    -- Debounced Single-Clock Rising-Edge Button Pulses (from u_debounce)
    SIGNAL btn_up_pulse, btn_down_pulse, btn_left_pulse, btn_right_pulse, btn_enter_pulse : STD_LOGIC := '0';

    -- Persistent Monster Inventory (Levels start at 1, max 63)
    SIGNAL inv_lvl_fire : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL inv_lvl_plant : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL inv_lvl_water : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);

    -- Active Battle Registers (8-bit HP: Default Level 1 HP = (1*2) + 16 = 18)
    SIGNAL p_type : STD_LOGIC_VECTOR(1 DOWNTO 0) := ELEM_FIRE;
    SIGNAL p_level : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL p_hp : unsigned(7 DOWNTO 0) := to_unsigned(18, 8);
    SIGNAL p_max_hp : unsigned(7 DOWNTO 0) := to_unsigned(18, 8);

    SIGNAL e_type : STD_LOGIC_VECTOR(1 DOWNTO 0) := ELEM_PLANT;
    SIGNAL e_level : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL e_hp : unsigned(7 DOWNTO 0) := to_unsigned(18, 8);
    SIGNAL e_max_hp : unsigned(7 DOWNTO 0) := to_unsigned(18, 8);

    -- Cursor Selection Registers
    SIGNAL mon_select_idx : unsigned(1 DOWNTO 0) := "00"; -- 0: Fire, 1: Plant, 2: Water
    SIGNAL menu_idx : unsigned(1 DOWNTO 0) := "00"; -- 0: ATK, 1: CAPT, 2: RUN
    SIGNAL skill_idx : STD_LOGIC := '0'; -- 0: Normal Tackle, 1: Elemental Strike

    -- Timer for Animations/Pauses/Snapshot (1.5 seconds @ CLK_FREQ_HZ)
    CONSTANT TIMER_1_5_SEC : INTEGER := (CLK_FREQ_HZ * 3) / 2;
    SIGNAL timer_cnt : INTEGER RANGE 0 TO TIMER_1_5_SEC := 0;
    SIGNAL timer_done : STD_LOGIC := '0';

    -- Prev state
    SIGNAL prev_state : state_type := ST_INIT;
    ----------------------------------------------------------------------------
    -- 8-bit Level-Scaled Damage Calculator Function
    -- Base DMG = (Attacker_Level / 2) + 2
    -- Rules:
    --   Advantage    = Base * 2 (Shift left 1)
    --   Neutral      = Base * 1
    --   Disadvantage = Base / 2 (Shift right 1, minimum 1)
    ----------------------------------------------------------------------------
    FUNCTION calc_damage(
        atk_type : STD_LOGIC_VECTOR(1 DOWNTO 0);
        def_type : STD_LOGIC_VECTOR(1 DOWNTO 0);
        atk_level : unsigned(5 DOWNTO 0);
        is_elem_skill : STD_LOGIC
    ) RETURN unsigned IS
        VARIABLE base_dmg : unsigned(7 DOWNTO 0);
        VARIABLE dmg : unsigned(7 DOWNTO 0);
    BEGIN
        -- Base DMG scales with level: (atk_level / 2) + 2 (8-bit representation)
        base_dmg := ("000" & atk_level(5 DOWNTO 1)) + 2;

        IF is_elem_skill = '0' THEN
            -- Normal Tackle: Flat Base DMG (scaled with Level, neutral to element)
            dmg := base_dmg;
        ELSE
            -- Elemental Strike: Type Matching
            IF (atk_type = ELEM_FIRE AND def_type = ELEM_PLANT) OR
                (atk_type = ELEM_PLANT AND def_type = ELEM_WATER) OR
                (atk_type = ELEM_WATER AND def_type = ELEM_FIRE) THEN
                -- Advantage: Base * 2 (Shift left 1)
                dmg := base_dmg(6 DOWNTO 0) & '0';
            ELSIF (atk_type = def_type) THEN
                -- Neutral: Base * 1
                dmg := base_dmg;
            ELSE
                -- Disadvantage: Base / 2 (Shift right 1, minimum 1)
                dmg := "0" & base_dmg(7 DOWNTO 1);
                IF dmg = 0 THEN
                    dmg := to_unsigned(1, 8);
                END IF;
            END IF;
        END IF;
        RETURN dmg;
    END FUNCTION;

    ----------------------------------------------------------------------------
    -- 8-bit Normalized HP Mapping Function (Scale to 0..255)
    -- Formula: (current_hp * 255) / max_hp
    -- Ensures full health bar = 255 pixels for FPGA 1 VGA renderer
    ----------------------------------------------------------------------------
    FUNCTION map_hp_255(
        cur_hp : unsigned(7 DOWNTO 0);
        max_hp : unsigned(7 DOWNTO 0)
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE temp : unsigned(15 DOWNTO 0);
        VARIABLE res : unsigned(15 DOWNTO 0);
    BEGIN
        IF cur_hp = 0 OR max_hp = 0 THEN
            RETURN x"00";
        ELSIF cur_hp >= max_hp THEN
            RETURN x"FF";
        ELSE
            temp := cur_hp * to_unsigned(255, 8);
            res := temp / max_hp;
            RETURN STD_LOGIC_VECTOR(res(7 DOWNTO 0));
        END IF;
    END FUNCTION;

BEGIN

    ----------------------------------------------------------------------------
    -- 1. Hardware Debounce & Edge Detector Sub-Module Instantiation
    ----------------------------------------------------------------------------
    u_debounce : ENTITY work.btn_debounce
        GENERIC MAP (
            CLK_FREQ_HZ       => CLK_FREQ_HZ,
            BUTTON_ACTIVE_LOW => BUTTON_ACTIVE_LOW
        )
        PORT MAP (
            clk             => clk,
            reset           => reset,
            btn_up_raw      => btn_up_raw,
            btn_down_raw    => btn_down_raw,
            btn_left_raw    => btn_left_raw,
            btn_right_raw   => btn_right_raw,
            btn_enter_raw   => btn_enter_raw,
            btn_up_pulse    => btn_up_pulse,
            btn_down_pulse  => btn_down_pulse,
            btn_left_pulse  => btn_left_pulse,
            btn_right_pulse => btn_right_pulse,
            btn_enter_pulse => btn_enter_pulse
        );

    ----------------------------------------------------------------------------
    -- 2. State & Datapath Synchronous Process
    ----------------------------------------------------------------------------
    p_fsm_sync : PROCESS (clk, reset)
        VARIABLE calc_dmg : unsigned(7 DOWNTO 0);
        VARIABLE capt_limit : unsigned(7 DOWNTO 0);
        VARIABLE spawn_lvl : unsigned(5 DOWNTO 0);
    BEGIN
        IF reset = '1' THEN
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

        ELSIF rising_edge(clk) THEN
            prev_state <= current_state;
            IF current_state /= prev_state THEN
                timer_cnt <= 0;
                timer_done <= '0';
                -- Animation, Pause & Snapshot Delay Timer
            ELSIF current_state = ST_CAM_CAPTURE OR
                current_state = ST_BATTLE_INTRO OR
                current_state = ST_PLAYER_ATK OR
                current_state = ST_ENEMY_ATK OR
                current_state = ST_CAPTURE_TRY THEN
                IF timer_cnt = TIMER_1_5_SEC THEN
                    timer_done <= '1';
                    timer_cnt <= 0;
                ELSE
                    timer_cnt <= timer_cnt + 1;
                    timer_done <= '0';
                END IF;
            ELSE
                timer_cnt <= 0;
                timer_done <= '0';
            END IF;

            -- Default Cursor output is 0
            cursor_out <= "00";

            -- State Transitions & Game Logic
            CASE current_state IS
                WHEN ST_INIT =>
                    current_state <= ST_TITLE;

                    ----------------------------------------------------------------
                    -- ST_TITLE: หน้าแรกของเกม (กด Enter เพื่อเริ่มเกม)
                    ----------------------------------------------------------------
                WHEN ST_TITLE =>
                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_SELECT_MON;
                        mon_select_idx <= "00";
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_SELECT_MON: เลือกมอนสเตอร์ในคลัง (3 ตัวเริ่มต้น Lv 1)
                    -- ปุ่ม ซ้าย (Left) / ขวา (Right) เลื่อนเลือกมอนสเตอร์
                    -- ปุ่ม Enter ยืนยัน
                    -- Max HP = (Level * 2) + 16 (8-bit)
                    ----------------------------------------------------------------
                WHEN ST_SELECT_MON =>
                    IF btn_left_pulse = '1' OR btn_up_pulse = '1' THEN
                        IF mon_select_idx = "00" THEN
                            mon_select_idx <= "10";
                        ELSE
                            mon_select_idx <= mon_select_idx - 1;
                        END IF;
                    ELSIF btn_right_pulse = '1' OR btn_down_pulse = '1' THEN
                        IF mon_select_idx = "10" THEN
                            mon_select_idx <= "00";
                        ELSE
                            mon_select_idx <= mon_select_idx + 1;
                        END IF;
                    END IF;

                    cursor_out <= STD_LOGIC_VECTOR(mon_select_idx);

                    CASE mon_select_idx IS
                        WHEN "00" =>
                            p_type <= ELEM_FIRE;
                            p_level <= inv_lvl_fire;
                            p_max_hp <= ("0" & inv_lvl_fire & '0') + 16;
                            p_hp <= ("0" & inv_lvl_fire & '0') + 16;
                        WHEN "01" =>
                            p_type <= ELEM_PLANT;
                            p_level <= inv_lvl_plant;
                            p_max_hp <= ("0" & inv_lvl_plant & '0') + 16;
                            p_hp <= ("0" & inv_lvl_plant & '0') + 16;
                        WHEN OTHERS =>
                            p_type <= ELEM_WATER;
                            p_level <= inv_lvl_water;
                            p_max_hp <= ("0" & inv_lvl_water & '0') + 16;
                            p_hp <= ("0" & inv_lvl_water & '0') + 16;
                    END CASE;

                    -- Confirm Selected Monster
                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_CAM_LIVE;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAM_LIVE (Opcode 2): ส่องกล้องดูภาพสด รอกดชัตเตอร์ (Enter)
                    ----------------------------------------------------------------
                WHEN ST_CAM_LIVE =>
                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_CAM_CAPTURE;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAM_CAPTURE (Opcode 3): แช่ภาพนิ่ง รอ FPGA 1 ประมวลผลเสร็จ
                    -- ปลดล็อกด้วย Timer 1.5 วินาทีอัตโนมัติ (ไม่เปิดให้กด Enter ข้าม
                    -- เพื่อการันตีว่า FPGA 1 มีเวลานับสีเสร็จและส่งข้อมูล SPI กลับมาครบ)
                    ----------------------------------------------------------------
                WHEN ST_CAM_CAPTURE =>
                    IF timer_done = '1' THEN
                        -- ชนิดศัตรู: รับตรงจาก FPGA 1 (2 บิต: 00=Fire, 01=Plant, 10=Water)
                        CASE enemy_type_in IS
                            WHEN ELEM_FIRE => e_type <= ELEM_FIRE;
                            WHEN ELEM_PLANT => e_type <= ELEM_PLANT;
                            WHEN ELEM_WATER => e_type <= ELEM_WATER;
                            WHEN OTHERS => e_type <= ELEM_FIRE;
                        END CASE;

                        -- เลเวลศัตรู: รับบิต LSB สีที่ 2 จาก FPGA 1 ('0' = เท่าเรา, '1' = เรา + 5)
                        IF enemy_lvl_lsb_in = '1' THEN
                            IF p_level > 58 THEN
                                spawn_lvl := to_unsigned(63, 6);
                            ELSE
                                spawn_lvl := p_level + 5;
                            END IF;
                        ELSE
                            spawn_lvl := p_level;
                        END IF;

                        e_level <= spawn_lvl;
                        e_max_hp <= ("0" & spawn_lvl & '0') + 16;
                        e_hp <= ("0" & spawn_lvl & '0') + 16;

                        current_state <= ST_BATTLE_INTRO;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_BATTLE_INTRO: เปิดตัวศัตรู (กด Enter เพื่อข้าม)
                    ----------------------------------------------------------------
                WHEN ST_BATTLE_INTRO =>
                    IF timer_done = '1' OR btn_enter_pulse = '1' THEN
                        current_state <= ST_ACTION_MENU;
                        menu_idx <= "00";
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_ACTION_MENU: เมนูคำสั่งหลัก (0: ATK, 1: CAPT, 2: RUN)
                    -- ปุ่ม บน/ล่าง เลื่อนเมนู, ปุ่ม Enter ยืนยัน
                    ----------------------------------------------------------------
                WHEN ST_ACTION_MENU =>
                    -- 2D Grid Menu Navigation:
                    -- Top Row   : [ATK ("00")]   [CAPT ("01")]
                    -- Bottom Row: [RUN ("10")]
                    CASE menu_idx IS
                        WHEN "00" => -- ATK (Top-Left)
                            IF btn_right_pulse = '1' THEN
                                menu_idx <= "01"; -- ขวา ไป CAPT
                            ELSIF btn_down_pulse = '1' THEN
                                menu_idx <= "10"; -- ล่าง ไป RUN (ใต้ ATK)
                            ELSIF btn_left_pulse = '1' THEN
                                menu_idx <= "01"; -- ซ้าย วนไป CAPT
                            ELSIF btn_up_pulse = '1' THEN
                                menu_idx <= "10"; -- บน วนไป RUN
                            END IF;

                        WHEN "01" => -- CAPT (Top-Right)
                            IF btn_left_pulse = '1' THEN
                                menu_idx <= "00"; -- ซ้าย ไป ATK
                            ELSIF btn_down_pulse = '1' THEN
                                menu_idx <= "10"; -- ล่าง ไป RUN
                            ELSIF btn_right_pulse = '1' THEN
                                menu_idx <= "00"; -- ขวา วนไป ATK
                            ELSIF btn_up_pulse = '1' THEN
                                menu_idx <= "10"; -- บน วนไป RUN
                            END IF;

                        WHEN OTHERS => -- RUN ("10", Bottom-Left)
                            IF btn_up_pulse = '1' THEN
                                menu_idx <= "00"; -- บน ไป ATK (บน RUN)
                            ELSIF btn_right_pulse = '1' THEN
                                menu_idx <= "01"; -- ขวา ไป CAPT
                            ELSIF btn_down_pulse = '1' THEN
                                menu_idx <= "00"; -- ล่าง วนไป ATK
                            ELSIF btn_left_pulse = '1' THEN
                                menu_idx <= "01"; -- ซ้าย วนไป CAPT
                            END IF;
                    END CASE;
                    cursor_out <= STD_LOGIC_VECTOR(menu_idx);

                    IF btn_enter_pulse = '1' THEN
                        CASE menu_idx IS
                            WHEN "00" => -- ATK
                                current_state <= ST_SKILL_MENU;
                                skill_idx <= '0';
                            WHEN "01" => -- CAPT
                                current_state <= ST_CAPTURE_TRY;
                            WHEN OTHERS => -- RUN
                                current_state <= ST_RUN_ESCAPE;
                        END CASE;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_SKILL_MENU: เลือกสกิล (0: Normal Tackle, 1: Elemental Strike)
                    -- ปุ่ม บน/ล่าง สลับสกิล, ปุ่ม Enter โจมตี
                    ----------------------------------------------------------------
                WHEN ST_SKILL_MENU =>
                    IF btn_up_pulse = '1' OR btn_down_pulse = '1' OR btn_left_pulse = '1' OR btn_right_pulse = '1' THEN
                        skill_idx <= NOT skill_idx;
                    END IF;
                    cursor_out <= "0" & skill_idx;

                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_PLAYER_ATK;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_PLAYER_ATK: ผู้เล่นโจมตี (8-bit Level Scaled Damage)
                    ----------------------------------------------------------------
                WHEN ST_PLAYER_ATK =>
                    calc_dmg := calc_damage(p_type, e_type, p_level, skill_idx);
                    cursor_out <= "0" & skill_idx;
                    IF timer_done = '1' OR btn_enter_pulse = '1' THEN
                        IF e_hp <= calc_dmg THEN
                            e_hp <= (OTHERS => '0');
                            current_state <= ST_VICTORYKO;
                        ELSE
                            e_hp <= e_hp - calc_dmg;
                            current_state <= ST_ENEMY_ATK;
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_ENEMY_ATK: ศัตรูโจมตีสวน (8-bit Level Scaled Elemental Strike)
                    ----------------------------------------------------------------
                WHEN ST_ENEMY_ATK =>
                    calc_dmg := calc_damage(e_type, p_type, e_level, '1');
                    cursor_out <= "0" & '1';
                    IF timer_done = '1' OR btn_enter_pulse = '1' THEN
                        IF p_hp <= calc_dmg THEN
                            p_hp <= (OTHERS => '0');

                            -- ลด Level ในคลังลง 1 เมื่อพ่ายแพ้ (ขั้นต่ำ Level 1)
                            CASE p_type IS
                                WHEN ELEM_FIRE =>
                                    IF inv_lvl_fire > 1 THEN
                                        inv_lvl_fire <= inv_lvl_fire - 1;
                                    END IF;
                                WHEN ELEM_PLANT =>
                                    IF inv_lvl_plant > 1 THEN
                                        inv_lvl_plant <= inv_lvl_plant - 1;
                                    END IF;
                                WHEN OTHERS => -- ELEM_WATER
                                    IF inv_lvl_water > 1 THEN
                                        inv_lvl_water <= inv_lvl_water - 1;
                                    END IF;
                            END CASE;

                            IF p_level > 1 THEN
                                p_level <= p_level - 1;
                            END IF;

                            current_state <= ST_DEFEAT;
                        ELSE
                            p_hp <= p_hp - calc_dmg;
                            current_state <= ST_ACTION_MENU;
                            menu_idx <= "00";
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAPTURE_TRY: ตรวจสอบจับศัตรู
                    -- เกณฑ์สำเร็จ: เลือดเหลือ <= 25% ของ Max HP (e_max_hp / 4) หรือ <= 4
                    ----------------------------------------------------------------
                WHEN ST_CAPTURE_TRY =>
                    capt_limit := "00" & e_max_hp(7 DOWNTO 2); -- Max HP / 4
                    IF capt_limit < 4 THEN
                        capt_limit := to_unsigned(4, 8);
                    END IF;

                    IF timer_done = '1' OR btn_enter_pulse = '1' THEN
                        IF e_hp <= capt_limit THEN
                            -- จับสำเร็จ: บันทึกเฉพาะเมื่อศัตรูมีเลเวลสูงกว่าเดิมในคลัง (ป้องกันเลเวลลดลง)
                            CASE e_type IS
                                WHEN ELEM_FIRE =>
                                    IF e_level > inv_lvl_fire THEN
                                        inv_lvl_fire <= e_level;
                                    ELSE
                                        inv_lvl_fire <= inv_lvl_fire + 1;
                                    END IF;

                                WHEN ELEM_PLANT =>
                                    IF e_level > inv_lvl_plant THEN
                                        inv_lvl_plant <= e_level;
                                    ELSE
                                        inv_lvl_plant <= inv_lvl_plant + 1;
                                    END IF;
                                WHEN OTHERS =>
                                    IF e_level > inv_lvl_water THEN
                                        inv_lvl_water <= e_level;
                                    ELSE
                                        inv_lvl_water <= inv_lvl_water + 1;
                                    END IF;
                            END CASE;
                            current_state <= ST_VICTORYCAP;
                        ELSE
                            -- จับไม่สำเร็จ: โดนศัตรูโจมตีสวนฟรี 1 ครั้ง
                            current_state <= ST_ENEMY_ATK;
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_RUN_ESCAPE: วิ่งหนีสำเร็จ -> กด Enter กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                WHEN ST_RUN_ESCAPE =>
                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_SELECT_MON;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_VICTORYKO / ST_DEFEAT / ST_VICTORYCAP: จบการต่อสู้ -> กด Enter กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                WHEN ST_VICTORYKO | ST_DEFEAT | ST_VICTORYCAP =>
                    IF btn_enter_pulse = '1' THEN
                        current_state <= ST_SELECT_MON;
                    END IF;

                WHEN OTHERS =>
                    cursor_out <= "00";
                    current_state <= ST_INIT;

            END CASE;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- 3. Output Assignment Process (Combinational Mapping for FPGA 1)
    ----------------------------------------------------------------------------

    -- Monster Status (HP mapped to full-scale 0..255 for FPGA 1 VGA bar)
    player_type_out <= p_type;
    player_lvl_out <= STD_LOGIC_VECTOR(p_level);
    player_hp_out <= map_hp_255(p_hp, p_max_hp);
    player_max_hp_o <= x"FF"; -- Always 255 for full-scale health bar

    enemy_type_out <= e_type;
    enemy_lvl_out <= STD_LOGIC_VECTOR(e_level);
    enemy_hp_out <= map_hp_255(e_hp, e_max_hp);
    enemy_max_hp_o <= x"FF"; -- Always 255 for full-scale health bar

    -- State Code for VGA Scene Compositor (Opcode 4-bit)
    PROCESS (current_state)
    BEGIN
        CASE current_state IS
            WHEN ST_TITLE => state_code_int <= "0000"; -- 0: Title
            WHEN ST_SELECT_MON => state_code_int <= "0001"; -- 1: select char
            WHEN ST_CAM_LIVE => state_code_int <= "0010"; -- 2: camera
            WHEN ST_CAM_CAPTURE => state_code_int <= "0011"; -- 3: capture
            WHEN ST_BATTLE_INTRO => state_code_int <= "0100"; -- 4: prepare
            WHEN ST_ACTION_MENU => state_code_int <= "0101"; -- 5: action
            WHEN ST_SKILL_MENU => state_code_int <= "0110"; -- 6: skill menu
            WHEN ST_PLAYER_ATK => state_code_int <= "0111"; -- 7: ATK
            WHEN ST_ENEMY_ATK => state_code_int <= "1000"; -- 8: E ATK
            WHEN ST_CAPTURE_TRY => state_code_int <= "1001"; -- 9: Capt
            WHEN ST_RUN_ESCAPE => state_code_int <= "1010"; -- 10: Evade
            WHEN ST_VICTORYKO => state_code_int <= "1011"; -- 11: Victory
            WHEN ST_DEFEAT => state_code_int <= "1100"; -- 12: Loss
            WHEN ST_VICTORYCAP => state_code_int <= "1101"; -- 13: VictoryCap
            WHEN OTHERS => state_code_int <= "0000";
        END CASE;
    END PROCESS;

    state_code_out <= state_code_int;

    ----------------------------------------------------------------------------
    -- 4. Diagnostic LED Outputs
    -- led(1:0) = enemy_type_in (00: Fire, 01: Plant, 10: Water)
    -- led(2)   = enemy_lvl_lsb_in (0: same lv, 1: lv+5)
    -- led(3)   = '1' during ST_CAM_CAPTURE (Snapshot active)
    -- led(7:4) = state_code_out (Current Opcode 0..13)
    ----------------------------------------------------------------------------
    led(1 DOWNTO 0) <= enemy_type_in;
    led(2) <= enemy_lvl_lsb_in;
    led(3) <= '1' WHEN current_state = ST_CAM_CAPTURE ELSE
    '0';
    led(7 DOWNTO 4) <= state_code_int;

END ARCHITECTURE Behavioral;