LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY frame_buffer IS
    PORT (
        data      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
        rdaddress : IN  STD_LOGIC_VECTOR(14 DOWNTO 0);
        rdclock   : IN  STD_LOGIC;
        wraddress : IN  STD_LOGIC_VECTOR(14 DOWNTO 0);
        wrclock   : IN  STD_LOGIC;
        wren      : IN  STD_LOGIC;
        q         : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END frame_buffer;

ARCHITECTURE Behavioral OF frame_buffer IS
    type ram_lower_t is array (0 to 16383) of std_logic_vector(11 downto 0);
    signal ram_lower : ram_lower_t;

    type ram_upper_t is array (0 to 4095) of std_logic_vector(11 downto 0);
    signal ram_upper : ram_upper_t;

    attribute ram_style : string;
    attribute ram_style of ram_lower : signal is "block";
    attribute ram_style of ram_upper : signal is "block";

    signal q_lower, q_upper : std_logic_vector(11 downto 0);
    signal sel_reg          : std_logic;
BEGIN
    process(wrclock)
    begin
        if rising_edge(wrclock) then
            if wren = '1' then
                if wraddress(14) = '0' then
                    ram_lower(to_integer(unsigned(wraddress(13 downto 0)))) <= data;
                else
                    ram_upper(to_integer(unsigned(wraddress(11 downto 0)))) <= data;
                end if;
            end if;
        end if;
    end process;

    process(rdclock)
    begin
        if rising_edge(rdclock) then
            q_lower <= ram_lower(to_integer(unsigned(rdaddress(13 downto 0))));
            q_upper <= ram_upper(to_integer(unsigned(rdaddress(11 downto 0))));
            sel_reg <= rdaddress(14);
        end if;
    end process;
    
    q <= q_lower when sel_reg = '0' else q_upper;
END Behavioral;