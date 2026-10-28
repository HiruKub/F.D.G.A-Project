--------------------------------------------------------------------------------
-- Project    : FPGA Monster Battle (EDGE Spartan-7)
-- Module     : button_7seg_test.vhd
-- Target     : EDGE Spartan-7 (XC7S15) / Vivado
-- Description: External Button & 7-Segment Hardware Verification Tool
--              - Tests 1 to 5 External Buttons (e.g. from Pmod / breadboard)
--              - Hardware Debounce Filter (20ms @ 50 MHz)
--              - Display on Common-Anode 7-Segment (Active-Low: '0'=ON, '1'=OFF):
--                  * No Button Pressed -> Displays '0'
--                  * Button 1 Pressed  -> Displays '1'
--                  * Button 2 Pressed  -> Displays '2'
--                  * Button 3 Pressed  -> Displays '3'
--                  * Button 4 Pressed  -> Displays '4'
--                  * Button 5 Pressed  -> Displays '5'
--              - Onboard LED Indicators:
--                  * led(4 downto 0) shows active button state
--                  * led(7) blinks at 1 Hz as Heartbeat (confirms clock is alive)
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY button_7seg_test IS
    GENERIC (
        CLK_FREQ_HZ       : INTEGER := 50_000_000; -- 50 MHz Onboard Clock
        BUTTON_ACTIVE_LOW : BOOLEAN := FALSE       -- FALSE: Active-High (1=pressed), TRUE: Active-Low (0=pressed)
    );
    PORT (
        clk50m : IN STD_LOGIC; -- Pin H11 (50 MHz Master Clock)

        -- External Buttons (Connect 1 or up to 5 buttons)
        -- If testing only 1 button: connect to btn_in(0)
        btn_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

        -- 7-Segment Individual Segment Outputs (Active-Low: '0'=Lit, '1'=Off)
        a : OUT STD_LOGIC;
        b : OUT STD_LOGIC;
        c : OUT STD_LOGIC;
        d : OUT STD_LOGIC;
        e : OUT STD_LOGIC;
        f : OUT STD_LOGIC;
        g : OUT STD_LOGIC;

        -- 7-Segment Digit Enable Outputs (Active-Low Common Anode: '0'=Digit Active)
        digit0 : OUT STD_LOGIC; -- Unit Digit (หลักหน่วย - Active)
        digit1 : OUT STD_LOGIC; -- Ten Digit  (หลักสิบ - Off)
        digit2 : OUT STD_LOGIC; -- Hundred    (หลักร้อย - Off)
        digit3 : OUT STD_LOGIC; -- Thousand   (หลักพัน - Off)

        -- Onboard LEDs for visual confirmation
        led : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ENTITY button_7seg_test;

ARCHITECTURE Behavioral OF button_7seg_test IS

    -- Normalized Active-High Button Signals
    SIGNAL btn_norm : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');

    -- Debounce Signals (20ms @ 50MHz = 1,000,000 clock cycles)
    CONSTANT DEBOUNCE_LIMIT : INTEGER := CLK_FREQ_HZ / 50;
    TYPE cnt_array IS ARRAY (0 TO 4) OF INTEGER RANGE 0 TO DEBOUNCE_LIMIT;
    SIGNAL db_cnt : cnt_array := (OTHERS => 0);
    SIGNAL btn_debounced : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');

    -- Value to be displayed on 7-Segment (0 to 5)
    SIGNAL disp_val : INTEGER RANGE 0 TO 5 := 0;

    -- 7-Segment Pattern (7-bit: a, b, c, d, e, f, g)
    SIGNAL seg_pat : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0000001";

    -- 1 Hz Heartbeat Counter (50M / 2 = 25M cycles per toggle)
    CONSTANT HB_LIMIT : INTEGER := CLK_FREQ_HZ / 2;
    SIGNAL hb_cnt     : INTEGER RANGE 0 TO HB_LIMIT := 0;
    SIGNAL hb_led     : STD_LOGIC := '0';

BEGIN

    ----------------------------------------------------------------------------
    -- 1. Input Polarity Normalization
    ----------------------------------------------------------------------------
    gen_norm : FOR i IN 0 TO 4 GENERATE
        btn_norm(i) <= NOT btn_in(i) WHEN BUTTON_ACTIVE_LOW ELSE btn_in(i);
    END GENERATE;

    ----------------------------------------------------------------------------
    -- 2. 20ms Hardware Debounce Filter
    ----------------------------------------------------------------------------
    p_debounce : PROCESS (clk50m)
    BEGIN
        IF rising_edge(clk50m) THEN
            FOR i IN 0 TO 4 LOOP
                IF btn_norm(i) = btn_debounced(i) THEN
                    db_cnt(i) <= 0;
                ELSE
                    IF db_cnt(i) = DEBOUNCE_LIMIT THEN
                        btn_debounced(i) <= btn_norm(i);
                        db_cnt(i) <= 0;
                    ELSE
                        db_cnt(i) <= db_cnt(i) + 1;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- 3. Determine Number to Display based on Pressed Button
    ----------------------------------------------------------------------------
    p_button_decode : PROCESS (btn_debounced)
    BEGIN
        IF btn_debounced(0) = '1' THEN
            disp_val <= 1; -- Button 1 -> Show '1'
        ELSIF btn_debounced(1) = '1' THEN
            disp_val <= 2; -- Button 2 -> Show '2'
        ELSIF btn_debounced(2) = '1' THEN
            disp_val <= 3; -- Button 3 -> Show '3'
        ELSIF btn_debounced(3) = '1' THEN
            disp_val <= 4; -- Button 4 -> Show '4'
        ELSIF btn_debounced(4) = '1' THEN
            disp_val <= 5; -- Button 5 -> Show '5'
        ELSE
            disp_val <= 0; -- No button -> Show '0'
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- 4. 7-Segment Decoder (Common Anode: Active-Low '0'=Lit, '1'=Dark)
    -- Pattern mapping: seg_pat(6 downto 0) = a & b & c & d & e & f & g
    ----------------------------------------------------------------------------
    p_7seg_decode : PROCESS (disp_val)
    BEGIN
        CASE disp_val IS
            WHEN 0 =>
                -- '0': a,b,c,d,e,f lit, g dark
                seg_pat <= "0000001";
            WHEN 1 =>
                -- '1': b,c lit, others dark
                seg_pat <= "1001111";
            WHEN 2 =>
                -- '2': a,b,d,e,g lit, c,f dark
                seg_pat <= "0010010";
            WHEN 3 =>
                -- '3': a,b,c,d,g lit, e,f dark
                seg_pat <= "0000110";
            WHEN 4 =>
                -- '4': b,c,f,g lit, a,d,e dark
                seg_pat <= "1001100";
            WHEN 5 =>
                -- '5': a,c,d,f,g lit, b,e dark
                seg_pat <= "0100100";
            WHEN OTHERS =>
                -- Dash '-'
                seg_pat <= "1111110";
        END CASE;
    END PROCESS;

    -- Output segments
    a <= seg_pat(6);
    b <= seg_pat(5);
    c <= seg_pat(4);
    d <= seg_pat(3);
    e <= seg_pat(2);
    f <= seg_pat(1);
    g <= seg_pat(0);

    -- Digit Select (Active-Low Common Anode): Enable digit 0, disable others
    digit0 <= '0'; -- ON
    digit1 <= '1'; -- OFF
    digit2 <= '1'; -- OFF
    digit3 <= '1'; -- OFF

    ----------------------------------------------------------------------------
    -- 5. 1 Hz Heartbeat Generator & LED Diagnostics
    ----------------------------------------------------------------------------
    p_heartbeat : PROCESS (clk50m)
    BEGIN
        IF rising_edge(clk50m) THEN
            IF hb_cnt = HB_LIMIT - 1 THEN
                hb_cnt <= 0;
                hb_led <= NOT hb_led;
            ELSE
                hb_cnt <= hb_cnt + 1;
            END IF;
        END IF;
    END PROCESS;

    -- LEDs:
    -- led(4 downto 0) lights up when corresponding button is pressed
    -- led(7) blinks at 1 Hz confirming 50MHz clock is active
    led(4 DOWNTO 0) <= btn_debounced;
    led(5)          <= '0';
    led(6)          <= '0';
    led(7)          <= hb_led;

END ARCHITECTURE Behavioral;
