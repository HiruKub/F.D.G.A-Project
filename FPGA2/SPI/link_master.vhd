-- ============================================================================
-- link_master.vhd  -  FPGA2 side of the board-to-board link (reusable core)
--
-- Sends the whole game state to FPGA1 over and over, one 5-byte frame every
-- 2^TICK_BITS clocks (19 -> 10.5 ms), and returns what FPGA1 answered.
--
--   FPGA2 -> FPGA1 : opcode(4) mon_p(2) lvl_p(6) hp_p(8) mon_e(2) lvl_e(6)
--                    hp_e(8) cursor(2)               = 38 bits (+2 pad, see link5_pkg)
--   FPGA1 -> FPGA2 : byte 0 of the same frame = REPLY_TAG(5) & colour1(2) & lv(1)
--
-- How to use it
--   * Drive tx_* from the game logic at any time. They are sampled ONCE at the
--     start of each frame, so a frame always holds one consistent snapshot.
--   * The state is re-sent every frame, so nothing is lost if one frame is bad.
--   * rx_colour1 / rx_lv keep the last good reply. rx_new pulses 1 clk each time
--     they were refreshed. The reply is whatever FPGA1 shows when the frame
--     starts, so a change on FPGA1 reaches here within about one frame.
--   * reply_ok = 1 when the 5 tag bits of the reply were as expected.
--     With the default tag "00000" an unplugged slave (MISO pulled low) looks
--     like a valid reply 00/0. Set REPLY_TAG to e.g. "10101" on BOTH boards if
--     you want an unplugged or dead FPGA1 to show up as reply_ok = 0.
--
-- Needs: link5_pkg.vhd, spi_master.vhd   (both unchanged)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.link5_pkg.all;

entity link_master is
  generic (
    CLK_DIV   : positive := 25;                     -- SCLK = 50 MHz / (2*CLK_DIV): 25 -> 1 MHz, 5 -> 5 MHz
    TICK_BITS : natural  := 19;                     -- one frame every 2^TICK_BITS clocks
    REPLY_TAG : std_logic_vector(4 downto 0) := "10101"
  );
  port (
    clk        : in  std_logic;
    -- game state to send (FPGA2 -> FPGA1)
    tx_opcode  : in  std_logic_vector(3 downto 0);
    tx_mon_p   : in  std_logic_vector(1 downto 0);
    tx_lvl_p   : in  std_logic_vector(5 downto 0);
    tx_hp_p    : in  std_logic_vector(7 downto 0);
    tx_mon_e   : in  std_logic_vector(1 downto 0);
    tx_lvl_e   : in  std_logic_vector(5 downto 0);
    tx_hp_e    : in  std_logic_vector(7 downto 0);
    tx_cursor  : in  std_logic_vector(1 downto 0);
    -- reply from FPGA1
    rx_colour1 : out std_logic_vector(1 downto 0);
    rx_lv      : out std_logic;
    rx_new     : out std_logic;                     -- 1-clk pulse: rx_colour1 / rx_lv refreshed
    reply_ok   : out std_logic;                     -- level: tag of the last reply matched REPLY_TAG
    frame_sent : out std_logic;                     -- 1-clk pulse: a frame just finished
    -- SPI pins
    spi_sclk   : out std_logic;
    spi_mosi   : out std_logic;
    spi_cs_n   : out std_logic;
    spi_miso   : in  std_logic
  );
end entity;

architecture rtl of link_master is
  type state_t is (S_IDLE, S_SETUP, S_LOAD, S_START, S_WAIT, S_HOLD);
  signal st        : state_t := S_IDLE;
  signal tick_cnt  : unsigned(TICK_BITS - 1 downto 0) := (others => '0');
  signal dly       : natural range 0 to 63 := 0;
  signal idx       : natural range 0 to FRAME_LEN - 1 := 0;
  signal cur       : frame_t := (others => (others => '0'));
  signal tx_byte   : byte_t := (others => '0');
  signal rx_byte   : byte_t;
  signal rx_status : byte_t := (others => '0');
  signal start_i, busy_i, done_i : std_logic := '0';
  signal cs_r      : std_logic := '1';
  signal sclk_i, mosi_i : std_logic;
  signal f_now     : fields_t;
  signal colour_r  : std_logic_vector(1 downto 0) := "00";
  signal lv_r, new_r, ok_r, sent_r : std_logic := '0';
begin
  f_now <= (opcode => tx_opcode, mon_p => tx_mon_p, lvl_p => tx_lvl_p, hp_p => tx_hp_p,
            mon_e  => tx_mon_e,  lvl_e => tx_lvl_e, hp_e  => tx_hp_e,  cursor => tx_cursor,
            pad    => (others => '0'));

  u_spi : entity work.spi_master
    generic map (CLK_DIV => CLK_DIV)
    port map (clk => clk, rst => '0', start => start_i, tx_data => tx_byte,
              rx_data => rx_byte, busy => busy_i, done => done_i,
              sclk => sclk_i, mosi => mosi_i, miso => spi_miso);

  process (clk)
  begin
    if rising_edge(clk) then
      tick_cnt <= tick_cnt + 1;
      start_i  <= '0';
      new_r    <= '0';
      sent_r   <= '0';

      case st is
        when S_IDLE =>
          if tick_cnt = to_unsigned(2 ** TICK_BITS - 1, TICK_BITS) then
            cur  <= pack(f_now);                  -- snapshot of the game state
            idx  <= 0;
            dly  <= 0;
            cs_r <= '0';
            st   <= S_SETUP;
          end if;

        when S_SETUP =>                           -- CS low, wait 63 clocks
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
          start_i <= '1';                         -- 1-clk pulse (busy is 0 here)
          st      <= S_WAIT;

        when S_WAIT =>
          if done_i = '1' then
            if idx = 0 then
              rx_status <= rx_byte;               -- the reply is in the first byte
            end if;
            if idx = FRAME_LEN - 1 then
              dly <= 0;
              st  <= S_HOLD;
            else
              idx <= idx + 1;
              st  <= S_LOAD;
            end if;
          end if;

        when S_HOLD =>                            -- wait 63 clocks, release CS, take the reply
          if dly = 63 then
            cs_r <= '1';
            if rx_status(7 downto 3) = REPLY_TAG then
              colour_r <= rx_status(2 downto 1);
              lv_r     <= rx_status(0);
              ok_r     <= '1';
              new_r    <= '1';
            else
              ok_r     <= '0';                    -- keep the previous colour / lv
            end if;
            sent_r <= '1';
            st     <= S_IDLE;
          else
            dly <= dly + 1;
          end if;
      end case;
    end if;
  end process;

  spi_sclk   <= sclk_i;
  spi_mosi   <= mosi_i;
  spi_cs_n   <= cs_r;
  rx_colour1 <= colour_r;
  rx_lv      <= lv_r;
  rx_new     <= new_r;
  reply_ok   <= ok_r;
  frame_sent <= sent_r;
end architecture;
