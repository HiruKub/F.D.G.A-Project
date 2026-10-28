--------------------------------------------------------------------------------
-- Project    : FPGA Camera-Based Monster Battle System (EDGE Spartan-7 Dual Board)
-- Module     : GameLogic_FSM.vhd
-- Target     : Xilinx Spartan-7 (XC7S15) / Vivado
-- Description: Core Game Logic Engine & Finite State Machine for FPGA 2
--              - Title Screen (ST_TITLE)
--              - All-in-One VGA Interface (Outputs to FPGA 1 VGA Compositor)
--              - Monster Selection & Inventory Persistence
--              - Camera Enemy Spawn & Level calculation (ST_SPAWN_CALC)
--              - Battle System (Action Menu, Skills, Capture, Run)
--              - Level-Scaled Damage & HP System:
--                  * Max HP = (Level * 2) + 16
--                  * Base DMG = (Level / 2) + 2
--                  * Elemental: Advantage x2, Neutral x1, Disadvantage /2
--                  * Capture: HP <= 25% of Max HP (or <= 4)
--              - 3-Button Control with Hardware Debounce & Edge Detection
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY GameLogic_FSM IS
    GENERIC (
        CLK_FREQ_HZ : INTEGER := 50_000_000 -- 50 MHz Master Clock
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC; -- Active-High System Reset

        -- Physical Push Buttons (Raw Inputs with internal Debounce)
        btn1_raw : IN STD_LOGIC; -- BTN1: UP / PREVIOUS
        btn2_raw : IN STD_LOGIC; -- BTN2: DOWN / NEXT
        btn3_raw : IN STD_LOGIC; -- BTN3: CONFIRM / SELECT / EXECUTE

        -- Camera & Enemy Interface from FPGA 1
        cam_data_ready : IN STD_LOGIC; -- High pulse when camera finished scanning
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
        player_lvl_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current Level
        player_hp_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current HP
        player_max_hp_o : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Max HP

        -- Enemy Monster Status Outputs (Top-Right HUD)
        enemy_type_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- 00: Fire, 01: Plant, 10: Water
        enemy_lvl_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current Level
        enemy_hp_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0); -- Current HP
        enemy_max_hp_o : OUT STD_LOGIC_VECTOR(5 DOWNTO 0) -- Max HP

        -- -- Animation & Sprite Transform Controls
        -- anim_trigger : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); -- 000: Idle, 001: P_Atk, 010: E_Atk, 011: Capture, 100: Run_Flip

        -- -- Dialog / Message Box Text ID (Bottom HUD Text ROM)
        -- hud_msg_code : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY GameLogic_FSM;

ARCHITECTURE Behavioral OF GameLogic_FSM IS

    -- Monster Element Definitions (2-bit)
    CONSTANT ELEM_FIRE : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    CONSTANT ELEM_PLANT : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
    CONSTANT ELEM_WATER : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";

    -- HUD Message Box Text IDs (Mapped to VGA Font ROM Strings)
    -- CONSTANT MSG_TITLE : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
    -- CONSTANT MSG_SELECT_MON : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
    -- CONSTANT MSG_WAIT_CAM : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0010";
    -- CONSTANT MSG_INTRO : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
    -- CONSTANT MSG_ACTION_MENU : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0100";
    -- CONSTANT MSG_SKILL_MENU : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0101";
    -- CONSTANT MSG_P_ATTACK : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0110";
    -- CONSTANT MSG_E_ATTACK : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0111";
    -- CONSTANT MSG_CAPT_OK : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1000";
    -- CONSTANT MSG_CAPT_FAIL : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1001";
    -- CONSTANT MSG_RUN : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1010";
    -- CONSTANT MSG_VICTORY : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1011";
    -- CONSTANT MSG_DEFEAT : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1100";

    -- FSM State Definitions
    TYPE state_type IS (
        ST_INIT,
        ST_TITLE,        -- 0: หน้าแรก (Title Screen)
        ST_SELECT_MON,   -- 1: ฉากเลือกมอนสเตอร์ในคลัง (3 ตัวเริ่มต้น Lv 1)
        ST_CAM_LIVE,     -- 2: ส่องกล้องดูภาพสด (Live Camera Feed)
        ST_CAM_CAPTURE,  -- 3: แช่ภาพนิ่ง (Snapshot Freeze) และรอผลสแกนสี
        ST_BATTLE_INTRO, -- 4: ฉากเปิดตัวศัตรู (Prepare / Wild Monster Appeared)
        ST_ACTION_MENU,  -- 5: เมนูคำสั่งหลัก (0: ATK, 1: CAPT, 2: RUN)
        ST_SKILL_MENU,   -- 6: เมนูเลือกสกิล (0: Elemental, 1: Normal)
        ST_PLAYER_ATK,   -- 7: ผู้เล่นโจมตี (คิดดาเมจ ชนะ x2 / เสมอ x1 / แพ้ /2)
        ST_ENEMY_ATK,    -- 8: ศัตรูโจมตีสวน
        ST_CAPTURE_TRY,  -- 9: ตรวจสอบเงื่อนไขจับมอนสเตอร์ (HP <= 25% of Max HP)
        ST_RUN_ESCAPE,   -- 10: หลบหนีออกจากการต่อสู้ (Evade)
        ST_VICTORYKO,    -- 11: ได้รับชัยชนะเพราะตีตาย (Victory)
        ST_DEFEAT,       -- 12: พ่ายแพ้ (Loss)
        ST_VICTORYCAP    -- 13: ได้รับชัยชนะเพราะจับสำเร็จ (VictoryCap)
    );

    SIGNAL current_state : state_type := ST_INIT;

    -- Button Signals after Debouncing and Edge Detection
    SIGNAL btn1_pulse, btn2_pulse, btn3_pulse : STD_LOGIC := '0';

    -- Debounce Limit (20ms @ CLK_FREQ_HZ = CLK_FREQ_HZ / 50 cycles)
    CONSTANT DEBOUNCE_LIMIT : INTEGER := CLK_FREQ_HZ / 50;
    SIGNAL db_cnt1, db_cnt2, db_cnt3 : INTEGER RANGE 0 TO DEBOUNCE_LIMIT := 0;
    SIGNAL btn1_state, btn2_state, btn3_state : STD_LOGIC := '0';
    SIGNAL btn1_prev, btn2_prev, btn3_prev : STD_LOGIC := '0';

    -- Persistent Monster Inventory (Levels start at 1)
    SIGNAL inv_lvl_fire : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL inv_lvl_plant : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL inv_lvl_water : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);

    -- Active Battle Registers (Default Level 1 HP = (1*2) + 16 = 18)
    SIGNAL p_type : STD_LOGIC_VECTOR(1 DOWNTO 0) := ELEM_FIRE;
    SIGNAL p_level : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL p_hp : unsigned(5 DOWNTO 0) := to_unsigned(18, 6);
    SIGNAL p_max_hp : unsigned(5 DOWNTO 0) := to_unsigned(18, 6);

    SIGNAL e_type : STD_LOGIC_VECTOR(1 DOWNTO 0) := ELEM_PLANT;
    SIGNAL e_level : unsigned(5 DOWNTO 0) := to_unsigned(1, 6);
    SIGNAL e_hp : unsigned(5 DOWNTO 0) := to_unsigned(18, 6);
    SIGNAL e_max_hp : unsigned(5 DOWNTO 0) := to_unsigned(18, 6);
    -- Cursor Selection Registers
    SIGNAL mon_select_idx : unsigned(1 DOWNTO 0) := "00"; -- 0: Fire, 1: Plant, 2: Water
    SIGNAL menu_idx : unsigned(1 DOWNTO 0) := "00"; -- 0: ATK, 1: CAPT, 2: RUN
    SIGNAL skill_idx : STD_LOGIC := '0'; -- 0: Elemental Strike, 1: Normal Tackle

    -- Timer for Animations/Pauses (1.5 seconds @ CLK_FREQ_HZ)
    CONSTANT TIMER_1_5_SEC : INTEGER := (CLK_FREQ_HZ * 3) / 2;
    SIGNAL timer_cnt : INTEGER RANGE 0 TO TIMER_1_5_SEC := 0;
    SIGNAL timer_done : STD_LOGIC := '0';

    ----------------------------------------------------------------------------
    -- Level-Scaled Damage Calculator Function
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
        VARIABLE base_dmg : unsigned(5 DOWNTO 0);
        VARIABLE dmg : unsigned(5 DOWNTO 0);
    BEGIN
        -- Base DMG scales with level: (atk_level / 2) + 2
        base_dmg := ("0" & atk_level(5 DOWNTO 1)) + 2;

        IF is_elem_skill = '0' THEN
            -- Normal Tackle: Flat Base DMG (scaled with Level, neutral to element)
            dmg := base_dmg;
        ELSE
            -- Elemental Strike: Type Matching
            IF (atk_type = ELEM_FIRE AND def_type = ELEM_PLANT) OR
                (atk_type = ELEM_PLANT AND def_type = ELEM_WATER) OR
                (atk_type = ELEM_WATER AND def_type = ELEM_FIRE) THEN
                -- Advantage: Base * 2 (Shift left 1)
                dmg := base_dmg(4 DOWNTO 0) & '0';
            ELSIF (atk_type = def_type) THEN
                -- Neutral: Base * 1
                dmg := base_dmg;
            ELSE
                -- Disadvantage: Base / 2 (Shift right 1, minimum 1)
                dmg := "0" & base_dmg(5 DOWNTO 1);
                IF dmg = 0 THEN
                    dmg := to_unsigned(1, 6);
                END IF;
            END IF;
        END IF;
        RETURN dmg;
    END FUNCTION;

BEGIN

    ----------------------------------------------------------------------------
    -- 1. Button Debounce & Single-Pulse Edge Detector
    ----------------------------------------------------------------------------
    p_debounce : PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            db_cnt1 <= 0;
            db_cnt2 <= 0;
            db_cnt3 <= 0;
            btn1_state <= '0';
            btn2_state <= '0';
            btn3_state <= '0';
            btn1_prev <= '0';
            btn2_prev <= '0';
            btn3_prev <= '0';
            btn1_pulse <= '0';
            btn2_pulse <= '0';
            btn3_pulse <= '0';
        ELSIF rising_edge(clk) THEN
            -- BTN1
            IF btn1_raw = btn1_state THEN
                db_cnt1 <= 0;
            ELSE
                IF db_cnt1 = DEBOUNCE_LIMIT THEN
                    btn1_state <= btn1_raw;
                    db_cnt1 <= 0;
                ELSE
                    db_cnt1 <= db_cnt1 + 1;
                END IF;
            END IF;

            -- BTN2
            IF btn2_raw = btn2_state THEN
                db_cnt2 <= 0;
            ELSE
                IF db_cnt2 = DEBOUNCE_LIMIT THEN
                    btn2_state <= btn2_raw;
                    db_cnt2 <= 0;
                ELSE
                    db_cnt2 <= db_cnt2 + 1;
                END IF;
            END IF;

            -- BTN3
            IF btn3_raw = btn3_state THEN
                db_cnt3 <= 0;
            ELSE
                IF db_cnt3 = DEBOUNCE_LIMIT THEN
                    btn3_state <= btn3_raw;
                    db_cnt3 <= 0;
                ELSE
                    db_cnt3 <= db_cnt3 + 1;
                END IF;
            END IF;

            -- Edge Detection (1-clock pulse on rising edge)
            btn1_prev <= btn1_state;
            btn2_prev <= btn2_state;
            btn3_prev <= btn3_state;

            btn1_pulse <= btn1_state AND (NOT btn1_prev);
            btn2_pulse <= btn2_state AND (NOT btn2_prev);
            btn3_pulse <= btn3_state AND (NOT btn3_prev);
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- 2. State & Datapath Synchronous Process
    ----------------------------------------------------------------------------
    p_fsm_sync : PROCESS (clk, reset)
        VARIABLE calc_dmg : unsigned(5 DOWNTO 0);
        VARIABLE capt_limit : unsigned(5 DOWNTO 0);
        VARIABLE spawn_lvl : unsigned(5 DOWNTO 0);
    BEGIN
        IF reset = '1' THEN
            current_state <= ST_INIT;
            mon_select_idx <= "00";
            cursor_out <= "00";
            menu_idx <= "00";
            skill_idx <= '0';
            timer_cnt <= 0;
            timer_done <= '0';

            -- Reset Inventory Levels to 1
            inv_lvl_fire <= to_unsigned(1, 6);
            inv_lvl_plant <= to_unsigned(1, 6);
            inv_lvl_water <= to_unsigned(1, 6);

            -- Default Level 1 HP = (1*2) + 16 = 18
            p_type <= ELEM_FIRE;
            p_level <= to_unsigned(1, 6);
            p_hp <= to_unsigned(18, 6);
            p_max_hp <= to_unsigned(18, 6);

            e_type <= ELEM_PLANT;
            e_level <= to_unsigned(1, 6);
            e_hp <= to_unsigned(18, 6);
            e_max_hp <= to_unsigned(18, 6);

        ELSIF rising_edge(clk) THEN

            -- Animation & Pause Delay Timer
            IF current_state = ST_BATTLE_INTRO OR
                current_state = ST_PLAYER_ATK OR
                current_state = ST_ENEMY_ATK OR
                current_state = ST_CAPTURE_TRY THEN
                IF timer_cnt >= TIMER_1_5_SEC THEN
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

            -- State Transitions & Game Data Updates
            cursor_out <= "00";
            CASE current_state IS
                    ----------------------------------------------------------------
                    -- ST_INIT: Hardware initialization
                    ----------------------------------------------------------------
                WHEN ST_INIT =>
                    current_state <= ST_TITLE;

                    ----------------------------------------------------------------
                    -- ST_TITLE: หน้าแรก (Title Screen) - Press BTN3 to Start Game
                    ----------------------------------------------------------------
                WHEN ST_TITLE =>
                    IF btn3_pulse = '1' THEN
                        current_state <= ST_SELECT_MON;
                        mon_select_idx <= "00";
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_SELECT_MON: เลือกมอนสเตอร์ในคลัง (3 ตัวเริ่มต้น Lv 1)
                    -- Max HP = (Level * 2) + 16
                    ----------------------------------------------------------------
                WHEN ST_SELECT_MON =>
                    -- BTN1: Previous, BTN2: Next
                    IF btn1_pulse = '1' THEN
                        IF mon_select_idx = "00" THEN
                            mon_select_idx <= "10";
                        ELSE
                            mon_select_idx <= mon_select_idx - 1;
                        END IF;
                    ELSIF btn2_pulse = '1' THEN
                        IF mon_select_idx = "10" THEN
                            mon_select_idx <= "00";
                        ELSE
                            mon_select_idx <= mon_select_idx + 1;
                        END IF;
                    END IF;
                    cursor_out <= STD_LOGIC_VECTOR(mon_select_idx);

                    -- BTN3: Confirm Selected Monster
                    IF btn3_pulse = '1' THEN
                        CASE mon_select_idx IS
                            WHEN "00" =>
                                p_type <= ELEM_FIRE;
                                p_level <= inv_lvl_fire;
                                p_max_hp <= (inv_lvl_fire(4 DOWNTO 0) & '0') + 16;
                                p_hp <= (inv_lvl_fire(4 DOWNTO 0) & '0') + 16;
                            WHEN "01" =>
                                p_type <= ELEM_PLANT;
                                p_level <= inv_lvl_plant;
                                p_max_hp <= (inv_lvl_plant(4 DOWNTO 0) & '0') + 16;
                                p_hp <= (inv_lvl_plant(4 DOWNTO 0) & '0') + 16;
                            WHEN OTHERS =>
                                p_type <= ELEM_WATER;
                                p_level <= inv_lvl_water;
                                p_max_hp <= (inv_lvl_water(4 DOWNTO 0) & '0') + 16;
                                p_hp <= (inv_lvl_water(4 DOWNTO 0) & '0') + 16;
                        END CASE;
                        current_state <= ST_CAM_LIVE;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAM_LIVE (Opcode 2): ส่องกล้องดูภาพสด รอกดชัตเตอร์ (BTN3)
                    ----------------------------------------------------------------
                WHEN ST_CAM_LIVE =>
                    IF btn3_pulse = '1' THEN
                        current_state <= ST_CAM_CAPTURE;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAM_CAPTURE (Opcode 3): แช่ภาพนิ่ง รอ FPGA 1 ประมวลผลเสร็จ
                    ----------------------------------------------------------------
                WHEN ST_CAM_CAPTURE =>
                    IF cam_data_ready = '1' THEN
                        -- ชนิดศัตรู: รับตรงจาก FPGA 1 (2 บิต: 00=Fire, 01=Plant, 10=Water)
                        e_type <= enemy_type_in;

                        -- เลเวลศัตรู: รับบิต LSB สีที่ 2 จาก FPGA 1 ('0' = เท่าเรา, '1' = เรา + 5)
                        IF enemy_lvl_lsb_in = '1' THEN
                            spawn_lvl := p_level + 5;
                        ELSE
                            spawn_lvl := p_level;
                        END IF;

                        e_level <= spawn_lvl;
                        e_max_hp <= (spawn_lvl(4 DOWNTO 0) & '0') + 16;
                        e_hp <= (spawn_lvl(4 DOWNTO 0) & '0') + 16;

                        current_state <= ST_BATTLE_INTRO;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_BATTLE_INTRO: เปิดตัวศัตรู
                    ----------------------------------------------------------------
                WHEN ST_BATTLE_INTRO =>
                    IF timer_done = '1' OR btn3_pulse = '1' THEN
                        current_state <= ST_ACTION_MENU;
                        menu_idx <= "00";
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_ACTION_MENU: เมนูคำสั่งหลัก (0: ATK, 1: CAPT, 2: RUN)
                    ----------------------------------------------------------------
                WHEN ST_ACTION_MENU =>
                    IF btn1_pulse = '1' THEN
                        IF menu_idx = "00" THEN
                            menu_idx <= "10";
                        ELSE
                            menu_idx <= menu_idx - 1;
                        END IF;
                    ELSIF btn2_pulse = '1' THEN
                        IF menu_idx = "10" THEN
                            menu_idx <= "00";
                        ELSE
                            menu_idx <= menu_idx + 1;
                        END IF;
                    END IF;
                    cursor_out <= STD_LOGIC_VECTOR(menu_idx);

                    IF btn3_pulse = '1' THEN
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
                    -- ST_SKILL_MENU: เลือกสกิล (0: Elemental Strike, 1: Normal Tackle)
                    ----------------------------------------------------------------
                WHEN ST_SKILL_MENU =>
                    IF btn1_pulse = '1' OR btn2_pulse = '1' THEN
                        skill_idx <= NOT skill_idx;
                    END IF;
                    cursor_out <= "0" & skill_idx;

                    IF btn3_pulse = '1' THEN
                        current_state <= ST_PLAYER_ATK;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_PLAYER_ATK: ผู้เล่นโจมตี (Level Scaled Damage)
                    ----------------------------------------------------------------
                WHEN ST_PLAYER_ATK =>
                    calc_dmg := calc_damage(p_type, e_type, p_level, NOT skill_idx);

                    IF timer_done = '1' OR btn3_pulse = '1' THEN
                        IF e_hp <= calc_dmg THEN
                            e_hp <= (OTHERS => '0');
                            current_state <= ST_VICTORYKO;
                        ELSE
                            e_hp <= e_hp - calc_dmg;
                            current_state <= ST_ENEMY_ATK;
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_ENEMY_ATK: ศัตรูโจมตีสวน (Level Scaled Elemental Strike)
                    ----------------------------------------------------------------
                WHEN ST_ENEMY_ATK =>
                    calc_dmg := calc_damage(e_type, p_type, e_level, '1');

                    IF timer_done = '1' OR btn3_pulse = '1' THEN
                        IF p_hp <= calc_dmg THEN
                            p_hp <= (OTHERS => '0');
                            current_state <= ST_DEFEAT;
                        ELSE
                            p_hp <= p_hp - calc_dmg;
                            current_state <= ST_ACTION_MENU;
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_CAPTURE_TRY: ตรวจสอบจับศัตรู
                    -- เกณฑ์สำเร็จ: เลือดเหลือ <= 25% ของ Max HP (e_max_hp / 4) หรือ <= 4
                    ----------------------------------------------------------------
                WHEN ST_CAPTURE_TRY =>
                    capt_limit := "00" & e_max_hp(5 DOWNTO 2); -- Max HP / 4
                    IF capt_limit < 4 THEN
                        capt_limit := to_unsigned(4, 6);
                    END IF;

                    IF timer_done = '1' OR btn3_pulse = '1' THEN
                        IF e_hp <= capt_limit THEN
                            -- จับสำเร็จ: นำเลเวลศัตรูมาบันทึกในคลัง
                            CASE e_type IS
                                WHEN ELEM_FIRE => inv_lvl_fire <= e_level;
                                WHEN ELEM_PLANT => inv_lvl_plant <= e_level;
                                WHEN OTHERS => inv_lvl_water <= e_level;
                            END CASE;
                            current_state <= ST_VICTORYCAP;
                        ELSE
                            -- จับไม่สำเร็จ: โดนศัตรูโจมตีสวนฟรี 1 ครั้ง
                            current_state <= ST_ENEMY_ATK;
                        END IF;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_RUN_ESCAPE: วิ่งหนีสำเร็จ -> กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                WHEN ST_RUN_ESCAPE =>
                    IF btn3_pulse = '1' THEN
                        current_state <= ST_SELECT_MON;
                    END IF;

                    ----------------------------------------------------------------
                    -- ST_VICTORYKO / ST_DEFEAT: จบการต่อสู้ -> กลับหน้าเลือกตัว
                    ----------------------------------------------------------------
                WHEN ST_VICTORYKO | ST_DEFEAT | ST_VICTORYCAP =>
                    IF btn3_pulse = '1' THEN
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

    -- Monster Status
    player_type_out <= p_type;
    player_lvl_out <= STD_LOGIC_VECTOR(p_level);
    player_hp_out <= STD_LOGIC_VECTOR(p_hp);
    player_max_hp_o <= STD_LOGIC_VECTOR(p_max_hp);

    enemy_type_out <= e_type;
    enemy_lvl_out <= STD_LOGIC_VECTOR(e_level);
    enemy_hp_out <= STD_LOGIC_VECTOR(e_hp);
    enemy_max_hp_o <= STD_LOGIC_VECTOR(e_max_hp);

    -- State Code for VGA Scene Compositor
    PROCESS (current_state)
    BEGIN
        CASE current_state IS
            WHEN ST_TITLE => state_code_out <= "0000";       -- 0: Title
            WHEN ST_SELECT_MON => state_code_out <= "0001";  -- 1: select char
            WHEN ST_CAM_LIVE => state_code_out <= "0010";    -- 2: camera
            WHEN ST_CAM_CAPTURE => state_code_out <= "0011"; -- 3: capture
            WHEN ST_BATTLE_INTRO => state_code_out <= "0100";-- 4: prepare
            WHEN ST_ACTION_MENU => state_code_out <= "0101"; -- 5: action
            WHEN ST_SKILL_MENU => state_code_out <= "0110";  -- 6: skill menu
            WHEN ST_PLAYER_ATK => state_code_out <= "0111";  -- 7: ATK
            WHEN ST_ENEMY_ATK => state_code_out <= "1000";   -- 8: E ATK
            WHEN ST_CAPTURE_TRY => state_code_out <= "1001"; -- 9: Capt
            WHEN ST_RUN_ESCAPE => state_code_out <= "1010";  -- 10: Evade
            WHEN ST_VICTORYKO => state_code_out <= "1011";   -- 11: Victory
            WHEN ST_DEFEAT => state_code_out <= "1100";      -- 12: Loss
            WHEN ST_VICTORYCAP => state_code_out <= "1101";  -- 13: VictoryCap
            WHEN OTHERS => state_code_out <= "0000";
        END CASE;
    END PROCESS;

    -- -- Animation Trigger for Sprite Renderer
    -- PROCESS (current_state)
    -- BEGIN
    --     CASE current_state IS
    --         WHEN ST_PLAYER_ATK => anim_trigger <= "001"; -- Player Attack
    --         WHEN ST_ENEMY_ATK => anim_trigger <= "010"; -- Enemy Attack
    --         WHEN ST_CAPTURE_TRY => anim_trigger <= "011"; -- Capture Ball
    --         WHEN ST_RUN_ESCAPE => anim_trigger <= "100"; -- Run Away (Flip)
    --         WHEN OTHERS => anim_trigger <= "000"; -- Normal Idle
    --     END CASE;
    -- END PROCESS;

    -- -- Text Message Code for Bottom HUD Text Box
    -- PROCESS (current_state, capt_success)
    -- BEGIN
    --     CASE current_state IS
    --         WHEN ST_TITLE => hud_msg_code <= MSG_TITLE;
    --         WHEN ST_SELECT_MON => hud_msg_code <= MSG_SELECT_MON;
    --         WHEN ST_WAIT_CAM => hud_msg_code <= MSG_WAIT_CAM;
    --         WHEN ST_BATTLE_INTRO => hud_msg_code <= MSG_INTRO;
    --         WHEN ST_ACTION_MENU => hud_msg_code <= MSG_ACTION_MENU;
    --         WHEN ST_SKILL_MENU => hud_msg_code <= MSG_SKILL_MENU;
    --         WHEN ST_PLAYER_ATK => hud_msg_code <= MSG_P_ATTACK;
    --         WHEN ST_ENEMY_ATK => hud_msg_code <= MSG_E_ATTACK;
    --         WHEN ST_CAPTURE_TRY =>
    --             IF capt_success = '1' THEN
    --                 hud_msg_code <= MSG_CAPT_OK;
    --             ELSE
    --                 hud_msg_code <= MSG_CAPT_FAIL;
    --             END IF;
    --         WHEN ST_RUN_ESCAPE => hud_msg_code <= MSG_RUN;
    --         WHEN ST_VICTORYKO => hud_msg_code <= MSG_VICTORY;
    --         WHEN ST_DEFEAT => hud_msg_code <= MSG_DEFEAT;
    --         WHEN OTHERS => hud_msg_code <= MSG_TITLE;
    --     END CASE;
    -- END PROCESS;

END ARCHITECTURE Behavioral;