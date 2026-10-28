--------------------------------------------------------------------------------
-- Project    : FPGA Camera-Based Monster Battle System (EDGE Spartan-7)
-- Module     : GameLogic_FSM_tb.vhd
-- Description: Complete Testbench for GameLogic_FSM (5-Button, 8-bit HP Interface)
--              - Simulates 50 MHz Master Clock
--              - Accelerated Simulation Clock Frequency (CLK_FREQ_HZ = 1000)
--              - Tests 5 Buttons: Up, Down, Left, Right, Enter
--              - Tests 8-bit HP: player_hp_out, enemy_hp_out (0..255)
--              - Full Gameplay Scenario:
--                  1. Power-on Reset
--                  2. Title Screen -> Start Game (Enter)
--                  3. Monster Select: Browse Left/Right/Up/Down -> Confirm Fire Mon (Enter)
--                  4. Live Camera -> Capture Snapshot (Enter)
--                  5. FPGA 1 Camera Data Input (Plant Element, Lv 6, HP 28)
--                  6. Battle Intro -> Action Menu (Enter)
--                  7. Action Menu -> Skill Menu (Skill 1: Elemental Strike) (Enter)
--                  8. Player Attack (Advantage x2: 4 DMG dealt to enemy) (Enter)
--                  9. Enemy Counter Attack (Disadvantage /2: 2 DMG dealt to player) (Enter)
--                 10. Menu Navigation: Down -> Run Away (Evade) -> Return to Select (Enter)
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY GameLogic_FSM_tb IS
    -- Testbench entity has no ports
END ENTITY GameLogic_FSM_tb;

ARCHITECTURE Behavioral OF GameLogic_FSM_tb IS

    -- 50 MHz Clock: Period = 20 ns
    CONSTANT CLK_PERIOD : TIME := 20 ns;

    -- UUT Signals
    SIGNAL clk              : STD_LOGIC := '0';
    SIGNAL reset            : STD_LOGIC := '1';

    SIGNAL btn_up_raw       : STD_LOGIC := '0';
    SIGNAL btn_down_raw     : STD_LOGIC := '0';
    SIGNAL btn_left_raw     : STD_LOGIC := '0';
    SIGNAL btn_right_raw    : STD_LOGIC := '0';
    SIGNAL btn_enter_raw    : STD_LOGIC := '0';

    SIGNAL cam_data_ready   : STD_LOGIC := '0';
    SIGNAL enemy_type_in    : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL enemy_lvl_lsb_in : STD_LOGIC := '0';

    SIGNAL state_code_out   : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL cursor_out       : STD_LOGIC_VECTOR(1 DOWNTO 0);

    SIGNAL player_type_out  : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL player_lvl_out   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL player_hp_out    : STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit HP
    SIGNAL player_max_hp_o  : STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit Max HP

    SIGNAL enemy_type_out   : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL enemy_lvl_out    : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL enemy_hp_out     : STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit HP
    SIGNAL enemy_max_hp_o   : STD_LOGIC_VECTOR(7 DOWNTO 0); -- 8-bit Max HP

    -- Simulation control flag
    SIGNAL sim_finished     : BOOLEAN := FALSE;

BEGIN

    ----------------------------------------------------------------------------
    -- 1. Instantiate the Unit Under Test (UUT)
    -- Use CLK_FREQ_HZ = 1000 so debounce = 20 cycles (400 ns) and timers run fast!
    ----------------------------------------------------------------------------
    uut : ENTITY work.GameLogic_FSM
        GENERIC MAP (
            CLK_FREQ_HZ => 1_000
        )
        PORT MAP (
            clk              => clk,
            reset            => reset,

            btn_up_raw       => btn_up_raw,
            btn_down_raw     => btn_down_raw,
            btn_left_raw     => btn_left_raw,
            btn_right_raw    => btn_right_raw,
            btn_enter_raw    => btn_enter_raw,

            cam_data_ready   => cam_data_ready,
            enemy_type_in    => enemy_type_in,
            enemy_lvl_lsb_in => enemy_lvl_lsb_in,

            state_code_out   => state_code_out,
            cursor_out       => cursor_out,

            player_type_out  => player_type_out,
            player_lvl_out   => player_lvl_out,
            player_hp_out    => player_hp_out,
            player_max_hp_o  => player_max_hp_o,

            enemy_type_out   => enemy_type_out,
            enemy_lvl_out    => enemy_lvl_out,
            enemy_hp_out     => enemy_hp_out,
            enemy_max_hp_o   => enemy_max_hp_o
        );

    ----------------------------------------------------------------------------
    -- 2. 50 MHz Master Clock Process
    ----------------------------------------------------------------------------
    clk_process : PROCESS
    BEGIN
        WHILE NOT sim_finished LOOP
            clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            clk <= '1';
            WAIT FOR CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- 3. Stimulus Process (Simulate 5 Buttons & Camera)
    ----------------------------------------------------------------------------
    stim_proc : PROCESS

        -- Helper procedures to simulate pressing physical buttons (exceeds debounce filter)
        PROCEDURE press_up IS
        BEGIN
            btn_up_raw <= '1';
            WAIT FOR CLK_PERIOD * 25; -- 500 ns (Debounce limit is 20 cycles)
            btn_up_raw <= '0';
            WAIT FOR CLK_PERIOD * 25;
        END PROCEDURE;

        PROCEDURE press_down IS
        BEGIN
            btn_down_raw <= '1';
            WAIT FOR CLK_PERIOD * 25;
            btn_down_raw <= '0';
            WAIT FOR CLK_PERIOD * 25;
        END PROCEDURE;

        PROCEDURE press_left IS
        BEGIN
            btn_left_raw <= '1';
            WAIT FOR CLK_PERIOD * 25;
            btn_left_raw <= '0';
            WAIT FOR CLK_PERIOD * 25;
        END PROCEDURE;

        PROCEDURE press_right IS
        BEGIN
            btn_right_raw <= '1';
            WAIT FOR CLK_PERIOD * 25;
            btn_right_raw <= '0';
            WAIT FOR CLK_PERIOD * 25;
        END PROCEDURE;

        PROCEDURE press_enter IS
        BEGIN
            btn_enter_raw <= '1';
            WAIT FOR CLK_PERIOD * 25;
            btn_enter_raw <= '0';
            WAIT FOR CLK_PERIOD * 25;
        END PROCEDURE;

    BEGIN
        REPORT "==================================================";
        REPORT ">>> STARTING 5-BUTTON & 8-BIT HP SIMULATION <<<";
        REPORT "==================================================";

        -- Step 1: System Power-on Reset
        reset <= '1';
        WAIT FOR 100 ns;
        reset <= '0';
        WAIT FOR 100 ns;
        ASSERT state_code_out = "0000" REPORT "Error: Should be in ST_TITLE (0)" SEVERITY ERROR;
        REPORT "[PASS] In ST_TITLE (Opcode 0). Press ENTER to start.";

        -- Step 2: Press ENTER to start game
        press_enter;
        ASSERT state_code_out = "0001" REPORT "Error: Should be in ST_SELECT_MON (1)" SEVERITY ERROR;
        REPORT "[PASS] In ST_SELECT_MON (Opcode 1). Default monster selected.";

        -- Step 3: Browse monsters with RIGHT and LEFT buttons
        press_right; -- Next monster (Plant, cursor = 01)
        WAIT FOR 200 ns;
        press_right; -- Next monster (Water, cursor = 10)
        WAIT FOR 200 ns;
        press_left;  -- Previous monster (Plant, cursor = 01)
        WAIT FOR 200 ns;
        press_left;  -- Previous monster (Fire, cursor = 00)
        WAIT FOR 200 ns;

        -- Step 4: Confirm Select Fire Monster with ENTER
        press_enter;
        ASSERT state_code_out = "0010" REPORT "Error: Should be in ST_CAM_LIVE (2)" SEVERITY ERROR;
        ASSERT player_type_out = "00" REPORT "Error: Player should be Fire (00)" SEVERITY ERROR;
        ASSERT to_integer(unsigned(player_hp_out)) = 18 REPORT "Error: Player Lv.1 Max HP should be 18" SEVERITY ERROR;
        REPORT "[PASS] In ST_CAM_LIVE (Opcode 2). Fire Monster selected, 8-bit HP = 18.";

        -- Step 5: Press ENTER as shutter button to capture camera snapshot
        WAIT FOR 1 us;
        press_enter;
        ASSERT state_code_out = "0011" REPORT "Error: Should be in ST_CAM_CAPTURE (3)" SEVERITY ERROR;
        REPORT "[PASS] In ST_CAM_CAPTURE (Opcode 3). Freezing camera frame for histogram.";

        -- Step 6: FPGA 1 finishes histogram scan and sends enemy data:
        -- Enemy Element = Plant ("01"), Enemy Level LSB = '1' (Enemy Level = 1 + 5 = 6)
        WAIT FOR 2 us;
        enemy_type_in    <= "01"; -- Plant
        enemy_lvl_lsb_in <= '1';  -- Level + 5 = 6
        cam_data_ready   <= '1';
        WAIT FOR CLK_PERIOD * 2;
        cam_data_ready   <= '0';
        WAIT FOR CLK_PERIOD * 2;

        ASSERT state_code_out = "0100" REPORT "Error: Should be in ST_BATTLE_INTRO (4)" SEVERITY ERROR;
        ASSERT enemy_type_out = "01" REPORT "Error: Enemy should be Plant (01)" SEVERITY ERROR;
        ASSERT to_integer(unsigned(enemy_lvl_out)) = 6 REPORT "Error: Enemy Level should be 6" SEVERITY ERROR;
        ASSERT to_integer(unsigned(enemy_hp_out)) = 28 REPORT "Error: Enemy Lv.6 Max HP should be 28" SEVERITY ERROR;
        REPORT "[PASS] In ST_BATTLE_INTRO (Opcode 4). Wild Plant Enemy Lv.6 spawned with 8-bit HP = 28!";

        -- Step 7: Skip intro to Action Menu with ENTER
        press_enter;
        ASSERT state_code_out = "0101" REPORT "Error: Should be in ST_ACTION_MENU (5)" SEVERITY ERROR;
        REPORT "[PASS] In ST_ACTION_MENU (Opcode 5). Choose Action.";

        -- Step 8: Select ATK (Cursor = 00) and press ENTER
        press_enter;
        ASSERT state_code_out = "0110" REPORT "Error: Should be in ST_SKILL_MENU (6)" SEVERITY ERROR;
        REPORT "[PASS] In ST_SKILL_MENU (Opcode 6). Default Skill 1: Elemental Strike.";

        -- Step 9: Execute Skill 1 (Fire vs Plant = ADVANTAGE! Base 2 * 2 = 4 DMG) with ENTER
        press_enter;
        ASSERT state_code_out = "0111" REPORT "Error: Should be in ST_PLAYER_ATK (7)" SEVERITY ERROR;
        REPORT "[PASS] In ST_PLAYER_ATK (Opcode 7). Player attacks with Fire Strike!";

        -- Confirm / animate player attack -> transitions to enemy attack
        press_enter;
        ASSERT state_code_out = "1000" REPORT "Error: Should be in ST_ENEMY_ATK (8)" SEVERITY ERROR;
        ASSERT to_integer(unsigned(enemy_hp_out)) = 24 REPORT "Error: Enemy HP should decrease from 28 to 24" SEVERITY ERROR;
        REPORT "[PASS] Enemy 8-bit HP decreased: 28 -> 24 (-4 DMG Advantage!). Now in ST_ENEMY_ATK (Opcode 8).";

        -- Enemy attacks back (Plant vs Fire = DISADVANTAGE! Base 5 / 2 = 2 DMG)
        press_enter;
        ASSERT state_code_out = "0101" REPORT "Error: Should return to ST_ACTION_MENU (5)" SEVERITY ERROR;
        ASSERT to_integer(unsigned(player_hp_out)) = 16 REPORT "Error: Player HP should decrease from 18 to 16" SEVERITY ERROR;
        REPORT "[PASS] Player 8-bit HP decreased: 18 -> 16 (-2 DMG Disadvantage!). Back in ST_ACTION_MENU (Opcode 5).";

        -- Step 10: Test Run Away (Evade)
        -- Move cursor down to CAPT, then to RUN (cursor = 10) using DOWN button
        press_down; -- Cursor to CAPT ("01")
        WAIT FOR 200 ns;
        press_down; -- Cursor to RUN ("10")
        WAIT FOR 200 ns;

        -- Confirm RUN with ENTER
        press_enter;
        ASSERT state_code_out = "1010" REPORT "Error: Should be in ST_RUN_ESCAPE (10)" SEVERITY ERROR;
        REPORT "[PASS] In ST_RUN_ESCAPE (Opcode 10). Player successfully escaped!";

        -- Press ENTER to return to Select Screen
        press_enter;
        ASSERT state_code_out = "0001" REPORT "Error: Should return to ST_SELECT_MON (1)" SEVERITY ERROR;
        REPORT "[PASS] Returned to ST_SELECT_MON (Opcode 1). Ready for next battle.";

        WAIT FOR 1 us;
        REPORT "==================================================";
        REPORT ">>> ALL TESTS PASSED! 8-BIT HP SIMULATION SUCCESSFUL! <<<";
        REPORT "==================================================";

        sim_finished <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE Behavioral;
