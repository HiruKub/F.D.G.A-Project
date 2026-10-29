-- ============================================================================
-- spi_master.vhd  -  byte-level SPI master, mode 0 (CPOL=0, CPHA=0), MSB first
--
--   SCLK frequency = clk / (2 * CLK_DIV)      (50 MHz, CLK_DIV=25  ->  1 MHz)
--
--   The core only shifts ONE byte at a time and does NOT drive CS_N.
--   The upper layer (frame logic) must:
--     1. pull spi_cs_n low and wait >= 1 us
--     2. for every byte:  put tx_data, pulse start for 1 clk, wait for done,
--                         read rx_data (valid while done = '1')
--     3. wait >= 1 us, then release spi_cs_n high
--   Do not pulse start while busy = '1'.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_master is
  generic (
    CLK_DIV : positive := 25
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    start   : in  std_logic;                      -- 1-clk pulse
    tx_data : in  std_logic_vector(7 downto 0);
    rx_data : out std_logic_vector(7 downto 0);
    busy    : out std_logic;
    done    : out std_logic;                      -- 1-clk pulse, byte finished
    sclk    : out std_logic;
    mosi    : out std_logic;
    miso    : in  std_logic
  );
end entity;

architecture rtl of spi_master is
  type state_t is (S_IDLE, S_RUN);
  signal state   : state_t := S_IDLE;
  signal cnt     : natural range 0 to CLK_DIV - 1 := 0;
  signal bitcnt  : natural range 0 to 7 := 0;
  signal sh_tx   : std_logic_vector(7 downto 0) := (others => '0');
  signal sh_rx   : std_logic_vector(7 downto 0) := (others => '0');
  signal sclk_r  : std_logic := '0';
  signal mosi_r  : std_logic := '0';
  signal miso_s1 : std_logic := '0';
  signal miso_s2 : std_logic := '0';
begin
  process (clk)
  begin
    if rising_edge(clk) then
      done    <= '0';
      miso_s1 <= miso;
      miso_s2 <= miso_s1;

      if rst = '1' then
        state  <= S_IDLE;
        sclk_r <= '0';
        cnt    <= 0;
        bitcnt <= 0;
      else
        case state is
          when S_IDLE =>
            sclk_r <= '0';
            if start = '1' then
              sh_tx  <= tx_data;
              mosi_r <= tx_data(7);   -- first bit ready before first rising edge
              cnt    <= 0;
              bitcnt <= 0;
              state  <= S_RUN;
            end if;

          when S_RUN =>
            if cnt = CLK_DIV - 1 then
              cnt <= 0;
              if sclk_r = '0' then
                -- rising edge: slave samples MOSI, we sample MISO
                sclk_r <= '1';
                sh_rx  <= sh_rx(6 downto 0) & miso_s2;
              else
                -- falling edge: change MOSI (or finish)
                sclk_r <= '0';
                if bitcnt = 7 then
                  rx_data <= sh_rx;
                  done    <= '1';
                  state   <= S_IDLE;
                else
                  bitcnt <= bitcnt + 1;
                  sh_tx  <= sh_tx(6 downto 0) & '0';
                  mosi_r <= sh_tx(6);
                end if;
              end if;
            else
              cnt <= cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

  sclk <= sclk_r;
  mosi <= mosi_r;
  busy <= '1' when state = S_RUN else '0';
end architecture;
