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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity btn_debounce is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000; -- Master Clock Frequency
        BUTTON_ACTIVE_LOW : boolean := TRUE -- TRUE: Pull-Up (0=pressed), FALSE: Pull-Down (1=pressed)
    );
    port (
        clk : in std_logic;
        reset : in std_logic; -- Active-High Reset

        -- Raw Push Button Inputs from FPGA Pins
        btn_up_raw : in std_logic;
        btn_down_raw : in std_logic;
        btn_left_raw : in std_logic;
        btn_right_raw : in std_logic;
        btn_enter_raw : in std_logic;

        -- Debounced Single-Clock Rising-Edge Pulses to FSM
        btn_up_pulse : out std_logic;
        btn_down_pulse : out std_logic;
        btn_left_pulse : out std_logic;
        btn_right_pulse : out std_logic;
        btn_enter_pulse : out std_logic
    );
end entity btn_debounce;

architecture Behavioral of btn_debounce is

    -- Normalized Button Signals (Active-High: '1'=Pressed)
    signal btn_up_in, btn_down_in, btn_left_in, btn_right_in, btn_enter_in : std_logic := '0';

    -- Debounce Limit (20ms @ CLK_FREQ_HZ = CLK_FREQ_HZ / 50 cycles)
    constant DEBOUNCE_LIMIT : integer := CLK_FREQ_HZ / 50;
    signal db_cnt_up, db_cnt_down, db_cnt_left, db_cnt_right, db_cnt_enter : integer range 0 to DEBOUNCE_LIMIT := 0;

    signal btn_up_state, btn_down_state, btn_left_state, btn_right_state, btn_enter_state : std_logic := '0';
    signal btn_up_prev, btn_down_prev, btn_left_prev, btn_right_prev, btn_enter_prev : std_logic := '0';

begin

    -- Button Polarity Normalization:
    -- If BUTTON_ACTIVE_LOW is TRUE (Pull-Up), inverts '0' (pressed) to '1'.
    -- If BUTTON_ACTIVE_LOW is FALSE (Pull-Down), passes '1' (pressed) directly.
    btn_up_in <= (not btn_up_raw) when BUTTON_ACTIVE_LOW else
        btn_up_raw;
    btn_down_in <= (not btn_down_raw) when BUTTON_ACTIVE_LOW else
        btn_down_raw;
    btn_left_in <= (not btn_left_raw) when BUTTON_ACTIVE_LOW else
        btn_left_raw;
    btn_right_in <= (not btn_right_raw) when BUTTON_ACTIVE_LOW else
        btn_right_raw;
    btn_enter_in <= (not btn_enter_raw) when BUTTON_ACTIVE_LOW else
        btn_enter_raw;

    ----------------------------------------------------------------------------
    -- 5-Button Debounce & Single-Pulse Edge Detector Process
    ----------------------------------------------------------------------------
    p_debounce : process (clk, reset)
    begin
        if reset = '1' then
            db_cnt_up <= 0;
            db_cnt_down <= 0;
            db_cnt_left <= 0;
            db_cnt_right <= 0;
            db_cnt_enter <= 0;

            btn_up_state <= '0';
            btn_down_state <= '0';
            btn_left_state <= '0';
            btn_right_state <= '0';
            btn_enter_state <= '0';

            btn_up_prev <= '0';
            btn_down_prev <= '0';
            btn_left_prev <= '0';
            btn_right_prev <= '0';
            btn_enter_prev <= '0';

            btn_up_pulse <= '0';
            btn_down_pulse <= '0';
            btn_left_pulse <= '0';
            btn_right_pulse <= '0';
            btn_enter_pulse <= '0';

        elsif rising_edge(clk) then

            -- BTN UP
            if btn_up_in = btn_up_state then
                db_cnt_up <= 0;
            else
                if db_cnt_up = DEBOUNCE_LIMIT then
                    btn_up_state <= btn_up_in;
                    db_cnt_up <= 0;
                else
                    db_cnt_up <= db_cnt_up + 1;
                end if;
            end if;

            -- BTN DOWN
            if btn_down_in = btn_down_state then
                db_cnt_down <= 0;
            else
                if db_cnt_down = DEBOUNCE_LIMIT then
                    btn_down_state <= btn_down_in;
                    db_cnt_down <= 0;
                else
                    db_cnt_down <= db_cnt_down + 1;
                end if;
            end if;

            -- BTN LEFT
            if btn_left_in = btn_left_state then
                db_cnt_left <= 0;
            else
                if db_cnt_left = DEBOUNCE_LIMIT then
                    btn_left_state <= btn_left_in;
                    db_cnt_left <= 0;
                else
                    db_cnt_left <= db_cnt_left + 1;
                end if;
            end if;

            -- BTN RIGHT
            if btn_right_in = btn_right_state then
                db_cnt_right <= 0;
            else
                if db_cnt_right = DEBOUNCE_LIMIT then
                    btn_right_state <= btn_right_in;
                    db_cnt_right <= 0;
                else
                    db_cnt_right <= db_cnt_right + 1;
                end if;
            end if;

            -- BTN ENTER
            if btn_enter_in = btn_enter_state then
                db_cnt_enter <= 0;
            else
                if db_cnt_enter = DEBOUNCE_LIMIT then
                    btn_enter_state <= btn_enter_in;
                    db_cnt_enter <= 0;
                else
                    db_cnt_enter <= db_cnt_enter + 1;
                end if;
            end if;

            -- Edge Detection (1-clock pulse on rising edge)
            btn_up_prev <= btn_up_state;
            btn_down_prev <= btn_down_state;
            btn_left_prev <= btn_left_state;
            btn_right_prev <= btn_right_state;
            btn_enter_prev <= btn_enter_state;

            btn_up_pulse <= btn_up_state and (not btn_up_prev);
            btn_down_pulse <= btn_down_state and (not btn_down_prev);
            btn_left_pulse <= btn_left_state and (not btn_left_prev);
            btn_right_pulse <= btn_right_state and (not btn_right_prev);
            btn_enter_pulse <= btn_enter_state and (not btn_enter_prev);

        end if;
    end process;

end architecture Behavioral;