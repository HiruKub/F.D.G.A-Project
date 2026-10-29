library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_slave is
port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    -- SPI pins
    sclk        : in  std_logic;
    mosi        : in  std_logic;
    cs_n        : in  std_logic;
    miso        : out std_logic;
    -- data to send
    tx_data     : in  std_logic_vector(7 downto 0);
    tx_idx      : out unsigned(9 downto 0);
    -- data received
    rx_byte     : out std_logic_vector(7 downto 0);
    rx_valid    : out std_logic;
    rx_idx      : out unsigned(9 downto 0);
    -- frame events
    frame_start : out std_logic;
    frame_end   : out std_logic;
    frame_len   : out unsigned(9 downto 0)
);
end entity;

architecture rtl of spi_slave is
signal sclk_s1, sclk_s2, sclk_p : std_logic := '0';
signal mosi_s1, mosi_s2         : std_logic := '0';
signal cs_s1, cs_s2, cs_p       : std_logic := '1';   -- idle = high

signal sh_rx   : std_logic_vector(7 downto 0) := (others => '0');
signal sh_tx   : std_logic_vector(7 downto 0) := (others => '0');
signal bitcnt  : unsigned(2 downto 0) := (others => '0');
signal idx     : unsigned(9 downto 0) := (others => '0');
signal reload  : std_logic := '0';
signal miso_r  : std_logic := '0';
begin
process (clk)
begin
    if rising_edge(clk) then
    -- input synchronisers
    sclk_s1 <= sclk;   sclk_s2 <= sclk_s1;   sclk_p <= sclk_s2;
    mosi_s1 <= mosi;   mosi_s2 <= mosi_s1;
    cs_s1   <= cs_n;   cs_s2   <= cs_s1;     cs_p   <= cs_s2;

    -- default pulse outputs
    rx_valid    <= '0';
    frame_start <= '0';
    frame_end   <= '0';
    reload      <= '0';

    if rst = '1' then
        bitcnt <= (others => '0');
        idx    <= (others => '0');

    elsif cs_s2 = '1' then
        ---------------------------------------------------------------- idle
        if cs_p = '0' then                -- CS just rose: frame finished
        frame_end <= '1';
        frame_len <= idx;
        end if;
        bitcnt <= (others => '0');
        idx    <= (others => '0');
        sh_tx  <= tx_data;                -- preload byte 0 (sync)
        miso_r <= tx_data(7);

    else
        ------------------------------------------------------------- selected
        if cs_p = '1' then                -- CS just fell
        frame_start <= '1';
        end if;

        if sclk_s2 = '1' and sclk_p = '0' then
        -- rising edge: sample MOSI, advance TX shift register
        sh_rx <= sh_rx(6 downto 0) & mosi_s2;
        sh_tx <= sh_tx(6 downto 0) & '0';
        if bitcnt = 7 then
            bitcnt   <= (others => '0');
            rx_byte  <= sh_rx(6 downto 0) & mosi_s2;
            rx_valid <= '1';
            rx_idx   <= idx;
            if idx /= 1023 then
            idx <= idx + 1;
            end if;
            reload <= '1';                -- next clk: load the next TX byte
        else
            bitcnt <= bitcnt + 1;
        end if;

        elsif sclk_s2 = '0' and sclk_p = '1' then
        -- falling edge: present next bit
        miso_r <= sh_tx(7);
        end if;

        if reload = '1' then              -- idx has been updated by now
        sh_tx  <= tx_data;
        miso_r <= tx_data(7);
        end if;
    end if;
    end if;
end process;

tx_idx <= idx;
miso   <= miso_r;
end architecture;
