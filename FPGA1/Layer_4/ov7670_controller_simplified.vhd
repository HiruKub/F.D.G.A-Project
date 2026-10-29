library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_controller_simplified is
    Port (
        clk   : in    STD_LOGIC;
        sioc  : out   STD_LOGIC;
        siod  : inout STD_LOGIC;
        reset : out   STD_LOGIC;
        pwdn  : out   STD_LOGIC;
        xclk  : out   STD_LOGIC
    );
end ov7670_controller_simplified;

architecture Behavioral of ov7670_controller_simplified is
    signal data    : std_logic_vector(15 downto 0);
    signal address : integer range 0 to 54;
begin

    Inst_i2c: entity work.i2c_simplified
    PORT MAP(
        clk                 => clk,
        instruction_address => address,
        instruction_data    => data,
        i2c_scl             => sioc,
        i2c_sda             => siod
    );

    reset <= '1';
    pwdn  <= '0';
    xclk  <= clk;

    process(clk)
    begin
        if rising_edge(clk) then
            case address is
                when 0  => data <= x"1280";
                when 1  => data <= x"1204";
                when 2  => data <= x"1100";
                when 3  => data <= x"0C00";
                when 4  => data <= x"3E00";
                when 5  => data <= x"8C00";
                when 6  => data <= x"0400";
                when 7  => data <= x"40D0";
                when 8  => data <= x"3A04";
                when 9  => data <= x"1438";
                when 10 => data <= x"4F40";
                when 11 => data <= x"5034";
                when 12 => data <= x"510C";
                when 13 => data <= x"5217";
                when 14 => data <= x"5329";
                when 15 => data <= x"5440";
                when 16 => data <= x"581E";
                when 17 => data <= x"3DC0";
                when 18 => data <= x"1100";
                when 19 => data <= x"1711";
                when 20 => data <= x"1861";
                when 21 => data <= x"32A4";
                when 22 => data <= x"1903";
                when 23 => data <= x"1A7B";
                when 24 => data <= x"030A";
                when 25 => data <= x"0E61";
                when 26 => data <= x"0F4B";
                when 27 => data <= x"1602";
                when 28 => data <= x"1E37";
                when 29 => data <= x"2102";
                when 30 => data <= x"2291";
                when 31 => data <= x"2907";
                when 32 => data <= x"330B";
                when 33 => data <= x"350B";
                when 34 => data <= x"371D";
                when 35 => data <= x"3871";
                when 36 => data <= x"392A";
                when 37 => data <= x"3C78";
                when 38 => data <= x"4D40";
                when 39 => data <= x"4E20";
                when 40 => data <= x"6900";
                when 41 => data <= x"6B4A";
                when 42 => data <= x"7410";
                when 43 => data <= x"8D4F";
                when 44 => data <= x"8E00";
                when 45 => data <= x"8F00";
                when 46 => data <= x"9000";
                when 47 => data <= x"9100";
                when 48 => data <= x"9600";
                when 49 => data <= x"9A00";
                when 50 => data <= x"B084";
                when 51 => data <= x"B10C";
                when 52 => data <= x"B20E";
                when 53 => data <= x"B382";
                when 54 => data <= x"B80A";
            end case;
        end if;
    end process;

end Behavioral;