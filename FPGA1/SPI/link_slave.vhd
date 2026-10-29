library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.link5_pkg.all;

entity link_slave is
generic (
    WATCHDOG_BITS : natural := 22;
    REPLY_TAG     : std_logic_vector(4 downto 0) := "10101"   -- must match link_master
);
port (
    clk        : in  std_logic;
    -- reply to FPGA2 (FPGA1 -> FPGA2)
    tx_colour1 : in  std_logic_vector(1 downto 0);
    tx_lv      : in  std_logic;
    -- game state received from FPGA2
    rx_opcode  : out std_logic_vector(3 downto 0);
    rx_mon_p   : out std_logic_vector(1 downto 0);
    rx_lvl_p   : out std_logic_vector(5 downto 0);
    rx_hp_p    : out std_logic_vector(7 downto 0);
    rx_mon_e   : out std_logic_vector(1 downto 0);
    rx_lvl_e   : out std_logic_vector(5 downto 0);
    rx_hp_e    : out std_logic_vector(7 downto 0);
    rx_cursor  : out std_logic_vector(1 downto 0);
    rx_new     : out std_logic;                     -- 1-clk pulse: a good frame was just committed
    bad_frame  : out std_logic;                     -- 1-clk pulse: a frame was rejected
    link_up    : out std_logic;
    -- SPI pins
    spi_sclk   : in  std_logic;
    spi_mosi   : in  std_logic;
    spi_cs_n   : in  std_logic;
    spi_miso   : out std_logic
);
end entity;

architecture rtl of link_slave is
signal tx_data     : byte_t;
signal tx_idx      : unsigned(9 downto 0);
signal rx_byte     : byte_t;
signal rx_valid    : std_logic;
signal rx_idx      : unsigned(9 downto 0);
signal frame_start : std_logic;
signal frame_end   : std_logic;
signal frame_len   : unsigned(9 downto 0);

signal reply_r : byte_t := (others => '0');
signal buf     : frame_t := (others => (others => '0'));
signal cur_f   : fields_t := (opcode => "0000", mon_p => "00", lvl_p => "000000",
                                hp_p   => "00000000", mon_e => "00", lvl_e => "000000",
                                hp_e   => "00000000", cursor => "00", pad => "00");
signal wd      : unsigned(WATCHDOG_BITS - 1 downto 0) := (others => '0');
signal up_r, new_r, bad_r : std_logic := '0';
begin
u_spi : entity work.spi_slave
    port map (clk => clk, rst => '0',
            sclk => spi_sclk, mosi => spi_mosi, cs_n => spi_cs_n, miso => spi_miso,
            tx_data => tx_data, tx_idx => tx_idx,
            rx_byte => rx_byte, rx_valid => rx_valid, rx_idx => rx_idx,
            frame_start => frame_start, frame_end => frame_end, frame_len => frame_len);

-- byte 0 of every frame is the reply; all later bytes are don't-care zeros
tx_data <= reply_r when tx_idx = 0 else x"00";

process (clk)
    variable f    : fields_t;
    variable op   : natural;
    variable good : boolean;
begin
    if rising_edge(clk) then
    new_r <= '0';
    bad_r <= '0';
    reply_r <= REPLY_TAG & tx_colour1 & tx_lv;   -- registered, so it changes in one step

    if rx_valid = '1' then
        if rx_idx < FRAME_LEN then
        buf(to_integer(rx_idx)) <= rx_byte;
        end if;
    end if;

    good := false;
    if frame_end = '1' then
        f  := unpack(buf);
        op := to_integer(unsigned(f.opcode));
        if frame_len = FRAME_LEN and op <= LAST_OPCODE and f.pad = "00" then
        good  := true;
        cur_f <= f;                              -- commit the whole frame at once
        new_r <= '1';
        else
        bad_r <= '1';
        end if;
    end if;

    -- link watchdog
    if good then
        wd   <= (others => '0');
        up_r <= '1';
    elsif wd = to_unsigned(2 ** WATCHDOG_BITS - 1, WATCHDOG_BITS) then
        up_r <= '0';
    else
        wd <= wd + 1;
    end if;
    end if;
end process;

rx_opcode <= cur_f.opcode;
rx_mon_p  <= cur_f.mon_p;
rx_lvl_p  <= cur_f.lvl_p;
rx_hp_p   <= cur_f.hp_p;
rx_mon_e  <= cur_f.mon_e;
rx_lvl_e  <= cur_f.lvl_e;
rx_hp_e   <= cur_f.hp_e;
rx_cursor <= cur_f.cursor;
rx_new    <= new_r;
bad_frame <= bad_r;
link_up   <= up_r;
end architecture;
