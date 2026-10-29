-- ============================================================================
-- link_test_master.vhd  -  FPGA2 : sends test frames, checks the reply
--
-- Every frame (default every 10.5 ms) = test row n, n = 0,1,..12,0,1,..
-- The slave answers (first byte) with status_byte(opcode of the PREVIOUS frame).
--
-- Start-up: the first 16 replies may contain errors (e.g. slave started later) before the
-- sticky error LED is armed; after 16 good replies any error lights it at once.
-- LEDs (D2..D9 = led[0..7]; jumper J4 on the LED side, LCD module removed):
--   led[0] heartbeat 1 Hz            led[1] toggles every frame sent
--   led[2] last reply was correct    led[3] STICKY error (reply wrong at least once)
--   led[7:4] = current opcode n (low 4 bits)
-- Needs: link5_pkg.vhd, spi_master.vhd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.link5_pkg.all;

entity link_test_master is
  port (
    clk50    : in  std_logic;
    spi_sclk : out std_logic;
    spi_mosi : out std_logic;
    spi_cs_n : out std_logic;
    spi_miso : in  std_logic;
    led      : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of link_test_master is
  constant CLK_DIV   : positive := 25;   -- SCLK = 50 MHz / (2*CLK_DIV): 25 -> 1 MHz, 10 -> 2.5 MHz, 5 -> 5 MHz
  constant TICK_BITS : natural  := 19;   -- 2^19 clocks = 10.5 ms per frame (use 25 for a slow 0.67 s test)
  constant LED_ACTIVE_HIGH : boolean := true;

  type state_t is (S_IDLE, S_SETUP, S_LOAD, S_START, S_WAIT, S_HOLD);
  signal st        : state_t := S_IDLE;
  signal tick_cnt  : unsigned(TICK_BITS - 1 downto 0) := (others => '0');
  signal dly       : natural range 0 to 63 := 0;
  signal idx       : natural range 0 to FRAME_LEN - 1 := 0;
  signal n         : natural range 0 to LAST_OPCODE := 0;
  signal prev_op   : std_logic_vector(3 downto 0) := (others => '0');
  signal have_prev : std_logic := '0';
  signal cur       : frame_t := (others => (others => '0'));
  signal tx_byte   : byte_t := (others => '0');
  signal rx_byte   : byte_t;
  signal rx_status : byte_t := (others => '0');
  signal start_i, busy_i, done_i : std_logic := '0';
  signal cs_r      : std_logic := '1';
  signal sclk_i, mosi_i : std_logic;
  signal toggle, reply_ok, err_sticky : std_logic := '0';
  signal good_rep  : natural range 0 to 16 := 0;       -- good replies seen (armed at 16)
  signal bad_pre   : natural range 0 to 15 := 0;       -- errors tolerated before armed
  signal hb_cnt    : unsigned(25 downto 0) := (others => '0');
  signal led_i     : std_logic_vector(7 downto 0);
begin
  u_spi : entity work.spi_master
    generic map (CLK_DIV => CLK_DIV)
    port map (clk => clk50, rst => '0', start => start_i, tx_data => tx_byte,
              rx_data => rx_byte, busy => busy_i, done => done_i,
              sclk => sclk_i, mosi => mosi_i, miso => spi_miso);

  process (clk50)
  begin
    if rising_edge(clk50) then
      hb_cnt   <= hb_cnt + 1;
      tick_cnt <= tick_cnt + 1;
      start_i  <= '0';

      case st is
        when S_IDLE =>
          if tick_cnt = to_unsigned(2 ** TICK_BITS - 1, TICK_BITS) then
            cur <= pack(test_fields(n));
            idx <= 0;
            dly <= 0;
            cs_r <= '0';
            st  <= S_SETUP;
          end if;

        when S_SETUP =>                       -- CS low, wait 63 clocks (1.26 us)
          if dly = 63 then
            dly <= 0;
            st  <= S_LOAD;
          else
            dly <= dly + 1;
          end if;

        when S_LOAD =>
          tx_byte <= cur(idx);
          st      <= S_START;

        when S_START =>
          start_i <= '1';                     -- 1-clk pulse (busy is 0 here)
          st      <= S_WAIT;

        when S_WAIT =>
          if done_i = '1' then
            if idx = 0 then
              rx_status <= rx_byte;           -- reply is in the first byte
            end if;
            if idx = FRAME_LEN - 1 then
              dly <= 0;
              st  <= S_HOLD;
            else
              idx <= idx + 1;
              st  <= S_LOAD;
            end if;
          end if;

        when S_HOLD =>                        -- wait 63 clocks, then release CS and judge
          if dly = 63 then
            cs_r <= '1';
            if have_prev = '1' then
              if rx_status = status_byte(prev_op) then
                reply_ok <= '1';
                if good_rep < 16 then
                  good_rep <= good_rep + 1;
                end if;
              else
                reply_ok <= '0';
                if good_rep = 16 or bad_pre = 15 then
                  err_sticky <= '1';
                else
                  bad_pre <= bad_pre + 1;              -- start-up tolerance
                end if;
              end if;
            end if;
            prev_op   <= std_logic_vector(to_unsigned(n, 4));
            have_prev <= '1';
            if n = LAST_OPCODE then
              n <= 0;
            else
              n <= n + 1;
            end if;
            toggle <= not toggle;
            st     <= S_IDLE;
          else
            dly <= dly + 1;
          end if;
      end case;
    end if;
  end process;

  spi_sclk <= sclk_i;
  spi_mosi <= mosi_i;
  spi_cs_n <= cs_r;

  led_i <= std_logic_vector(to_unsigned(n, 4)) & err_sticky & reply_ok & toggle & hb_cnt(25);
  led   <= led_i when LED_ACTIVE_HIGH else not led_i;
end architecture;
