--------------------------------------------------------------------------------
-- Project    : FPGA Monster Battle System (EDGE Spartan-7 Dual Board)
-- Module     : btn_debounce.vhd
-- Target     : Xilinx Spartan-7 (XC7S15) / Vivado
-- Description: 5-Button Hardware Debounce Filter & Rising-Edge Pulse Generator
--              - Configurable Clock Frequency (CLK_FREQ_HZ)
--              - Polarity Inverter for Pull-Up (BUTTON_ACTIVE_LOW = TRUE)
--              - 20ms Debounce Filter (CLK_FREQ_HZ / 50 cycles)
--              - 1-Clock Rising-Edge Pulse Generator per button press
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY btn_debounce IS
    GENERIC (
        CLK_FREQ_HZ       : INTEGER := 50_000_000; -- Master Clock Frequency
        BUTTON_ACTIVE_LOW : BOOLEAN := TRUE        -- TRUE: Pull-Up (0=pressed), FALSE: Pull-Down (1=pressed)
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC; -- Active-High Reset

        -- Raw Push Button Inputs from FPGA Pins
        btn_up_raw    : IN STD_LOGIC;
        btn_down_raw  : IN STD_LOGIC;
        btn_left_raw  : IN STD_LOGIC;
        btn_right_raw : IN STD_LOGIC;
        btn_enter_raw : IN STD_LOGIC;

        -- Debounced Single-Clock Rising-Edge Pulses to FSM
        btn_up_pulse    : OUT STD_LOGIC;
        btn_down_pulse  : OUT STD_LOGIC;
        btn_left_pulse  : OUT STD_LOGIC;
        btn_right_pulse : OUT STD_LOGIC;
        btn_enter_pulse : OUT STD_LOGIC
    );
END ENTITY btn_debounce;

ARCHITECTURE Behavioral OF btn_debounce IS

    -- Normalized Button Signals (Active-High: '1'=Pressed)
    SIGNAL btn_up_in, btn_down_in, btn_left_in, btn_right_in, btn_enter_in : STD_LOGIC := '0';

    -- Debounce Limit (20ms @ CLK_FREQ_HZ = CLK_FREQ_HZ / 50 cycles)
    CONSTANT DEBOUNCE_LIMIT : INTEGER := CLK_FREQ_HZ / 50;
    SIGNAL db_cnt_up, db_cnt_down, db_cnt_left, db_cnt_right, db_cnt_enter : INTEGER RANGE 0 TO DEBOUNCE_LIMIT := 0;

    SIGNAL btn_up_state, btn_down_state, btn_left_state, btn_right_state, btn_enter_state : STD_LOGIC := '0';
    SIGNAL btn_up_prev, btn_down_prev, btn_left_prev, btn_right_prev, btn_enter_prev       : STD_LOGIC := '0';

BEGIN

    -- Button Polarity Normalization:
    -- If BUTTON_ACTIVE_LOW is TRUE (Pull-Up), inverts '0' (pressed) to '1'.
    -- If BUTTON_ACTIVE_LOW is FALSE (Pull-Down), passes '1' (pressed) directly.
    btn_up_in    <= (NOT btn_up_raw)    WHEN BUTTON_ACTIVE_LOW ELSE btn_up_raw;
    btn_down_in  <= (NOT btn_down_raw)  WHEN BUTTON_ACTIVE_LOW ELSE btn_down_raw;
    btn_left_in  <= (NOT btn_left_raw)  WHEN BUTTON_ACTIVE_LOW ELSE btn_left_raw;
    btn_right_in <= (NOT btn_right_raw) WHEN BUTTON_ACTIVE_LOW ELSE btn_right_raw;
    btn_enter_in <= (NOT btn_enter_raw) WHEN BUTTON_ACTIVE_LOW ELSE btn_enter_raw;

    ----------------------------------------------------------------------------
    -- 5-Button Debounce & Single-Pulse Edge Detector Process
    ----------------------------------------------------------------------------
    p_debounce : PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            db_cnt_up    <= 0;
            db_cnt_down  <= 0;
            db_cnt_left  <= 0;
            db_cnt_right <= 0;
            db_cnt_enter <= 0;

            btn_up_state    <= '0';
            btn_down_state  <= '0';
            btn_left_state  <= '0';
            btn_right_state <= '0';
            btn_enter_state <= '0';

            btn_up_prev    <= '0';
            btn_down_prev  <= '0';
            btn_left_prev  <= '0';
            btn_right_prev <= '0';
            btn_enter_prev <= '0';

            btn_up_pulse    <= '0';
            btn_down_pulse  <= '0';
            btn_left_pulse  <= '0';
            btn_right_pulse <= '0';
            btn_enter_pulse <= '0';

        ELSIF rising_edge(clk) THEN

            -- BTN UP
            IF btn_up_in = btn_up_state THEN
                db_cnt_up <= 0;
            ELSE
                IF db_cnt_up = DEBOUNCE_LIMIT THEN
                    btn_up_state <= btn_up_in;
                    db_cnt_up    <= 0;
                ELSE
                    db_cnt_up <= db_cnt_up + 1;
                END IF;
            END IF;

            -- BTN DOWN
            IF btn_down_in = btn_down_state THEN
                db_cnt_down <= 0;
            ELSE
                IF db_cnt_down = DEBOUNCE_LIMIT THEN
                    btn_down_state <= btn_down_in;
                    db_cnt_down    <= 0;
                ELSE
                    db_cnt_down <= db_cnt_down + 1;
                END IF;
            END IF;

            -- BTN LEFT
            IF btn_left_in = btn_left_state THEN
                db_cnt_left <= 0;
            ELSE
                IF db_cnt_left = DEBOUNCE_LIMIT THEN
                    btn_left_state <= btn_left_in;
                    db_cnt_left    <= 0;
                ELSE
                    db_cnt_left <= db_cnt_left + 1;
                END IF;
            END IF;

            -- BTN RIGHT
            IF btn_right_in = btn_right_state THEN
                db_cnt_right <= 0;
            ELSE
                IF db_cnt_right = DEBOUNCE_LIMIT THEN
                    btn_right_state <= btn_right_in;
                    db_cnt_right    <= 0;
                ELSE
                    db_cnt_right <= db_cnt_right + 1;
                END IF;
            END IF;

            -- BTN ENTER
            IF btn_enter_in = btn_enter_state THEN
                db_cnt_enter <= 0;
            ELSE
                IF db_cnt_enter = DEBOUNCE_LIMIT THEN
                    btn_enter_state <= btn_enter_in;
                    db_cnt_enter    <= 0;
                ELSE
                    db_cnt_enter <= db_cnt_enter + 1;
                END IF;
            END IF;

            -- Edge Detection (1-clock pulse on rising edge)
            btn_up_prev    <= btn_up_state;
            btn_down_prev  <= btn_down_state;
            btn_left_prev  <= btn_left_state;
            btn_right_prev <= btn_right_state;
            btn_enter_prev <= btn_enter_state;

            btn_up_pulse    <= btn_up_state AND (NOT btn_up_prev);
            btn_down_pulse  <= btn_down_state AND (NOT btn_down_prev);
            btn_left_pulse  <= btn_left_state AND (NOT btn_left_prev);
            btn_right_pulse <= btn_right_state AND (NOT btn_right_prev);
            btn_enter_pulse <= btn_enter_state AND (NOT btn_enter_prev);

        END IF;
    END PROCESS;

END ARCHITECTURE Behavioral;
