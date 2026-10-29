-- library IEEE;
-- use IEEE.STD_LOGIC_1164.ALL;

-- entity spi_module is
--     Port (
--         clk             : in  STD_LOGIC;
--         sck             : in  STD_LOGIC;
--         cs              : in  STD_LOGIC;
--         mosi            : in  STD_LOGIC;
--         miso            : out STD_LOGIC;
--         sw              : in  STD_LOGIC_VECTOR(15 downto 0);
--         btn             : in  STD_LOGIC_VECTOR(4 downto 0);
--         analysis_result : in  STD_LOGIC_VECTOR(2 downto 0);
--         control         : out STD_LOGIC_VECTOR(37 downto 0)
--     );
-- end spi_module;

-- architecture Testbench_Board of spi_module is
-- begin
--     miso <= '0';

--     process(sw, btn)
--     begin
--         -- Opcode [33..30] : SW3..SW0 ????? 13 ???
--         control(37 downto 34) <= sw(3 downto 0);

--         -- Player Character [29..28] : SW5..SW4
--         control(33 downto 32) <= sw(5 downto 4);

--         -- Player Level [27..22] & HP [21..16] : ?????????????
--         control(31 downto 26) <= "001111"; -- Level 15
--         control(25 downto 18) <= "01111111"; -- HP 63 Full

--         -- Enemy Character [15..14] : SW7..SW6
--         control(17 downto 16) <= sw(7 downto 6);

--         -- Enemy Level [13..8] & HP [7..2] : ?????????????
--         control(15 downto 10)  <= "111111"; -- Level 5
--         control(9 downto 2)   <= "00000111"; -- HP 63 Full

--         -- Cursor [1..0] : SW9..SW8
--         control(1 downto 0)   <= sw(9 downto 8);
--     end process;

-- end Testbench_Board;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_module is
    Port (
        clk             : in  STD_LOGIC;
        sck             : in  STD_LOGIC;
        cs              : in  STD_LOGIC;
        mosi            : in  STD_LOGIC;
        miso            : out STD_LOGIC;
        sw              : in  STD_LOGIC_VECTOR(15 downto 0);   -- not used
        btn             : in  STD_LOGIC_VECTOR(4 downto 0);    -- not used
        analysis_result : in  STD_LOGIC_VECTOR(2 downto 0);
        control         : out STD_LOGIC_VECTOR(37 downto 0)
    );
end spi_module;

architecture rtl of spi_module is
    signal opcode : std_logic_vector(3 downto 0); -- 37 36 35 34
    signal mon_p  : std_logic_vector(1 downto 0); -- 33 32
    signal lvl_p  : std_logic_vector(5 downto 0); -- 31 30 29 28 27 26
    signal hp_p   : std_logic_vector(7 downto 0); -- 25 24 23 22 21 20 19 18
    signal mon_e  : std_logic_vector(1 downto 0); -- 17 16
    signal lvl_e  : std_logic_vector(5 downto 0); -- 15 14 13 12 11 10
    signal hp_e   : std_logic_vector(7 downto 0); -- 9 8 7 6 5 4 3 2
    signal cursor : std_logic_vector(1 downto 0); -- 1 0
begin
    u_link : entity work.link_slave
        port map (
            clk        => clk,
            tx_colour1 => analysis_result(2 downto 1),
            tx_lv      => analysis_result(0),
            rx_opcode  => opcode,
            rx_mon_p   => mon_p,
            rx_lvl_p   => lvl_p,
            rx_hp_p    => hp_p,
            rx_mon_e   => mon_e,
            rx_lvl_e   => lvl_e,
            rx_hp_e    => hp_e,
            rx_cursor  => cursor,
            rx_new     => open,
            bad_frame  => open,
            link_up    => open,
            spi_sclk   => sck,
            spi_mosi   => mosi,
            spi_cs_n   => cs,
            spi_miso   => miso);

    control <= opcode & mon_p & lvl_p & hp_p & mon_e & lvl_e & hp_e & cursor;
end rtl;
