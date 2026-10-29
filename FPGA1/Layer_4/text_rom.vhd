library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity text_rom is
    Port (
        clk        : in  std_logic;
        ascii_code : in  std_logic_vector(7 downto 0);
        char_y     : in  unsigned(2 downto 0);
        char_x     : in  unsigned(2 downto 0);
        pixel_out  : out std_logic
    );
end text_rom;

architecture Behavioral of text_rom is
    signal row_data : std_logic_vector(7 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            case ascii_code is
                when x"30" => -- '0'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"46";
                        when "010" => row_data <= x"4A";
                        when "011" => row_data <= x"52";
                        when "100" => row_data <= x"62";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"31" => -- '1'
                    case char_y is
                        when "000" => row_data <= x"18";
                        when "001" => row_data <= x"28";
                        when "010" => row_data <= x"08";
                        when "011" => row_data <= x"08";
                        when "100" => row_data <= x"08";
                        when "101" => row_data <= x"3E";
                        when others=> row_data <= x"00";
                    end case;
                when x"32" => -- '2'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"04";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"20";
                        when "101" => row_data <= x"7E";
                        when others=> row_data <= x"00";
                    end case;
                when x"33" => -- '3'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"1C";
                        when "011" => row_data <= x"02";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"34" => -- '4'
                    case char_y is
                        when "000" => row_data <= x"08";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"28";
                        when "011" => row_data <= x"48";
                        when "100" => row_data <= x"7E";
                        when "101" => row_data <= x"08";
                        when others=> row_data <= x"00";
                    end case;
                when x"35" => -- '5'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"02";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"36" => -- '6'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"37" => -- '7'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"02";
                        when "010" => row_data <= x"04";
                        when "011" => row_data <= x"08";
                        when "100" => row_data <= x"10";
                        when "101" => row_data <= x"10";
                        when others=> row_data <= x"00";
                    end case;
                when x"38" => -- '8'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"3C";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"39" => -- '9'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"3E";
                        when "011" => row_data <= x"02";
                        when "100" => row_data <= x"04";
                        when "101" => row_data <= x"38";
                        when others=> row_data <= x"00";
                    end case;
                                when x"3C" => -- '<'
                    case char_y is
                        when "000" => row_data <= x"0C";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"30";
                        when "011" => row_data <= x"30";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"0C";
                        when others=> row_data <= x"00";
                    end case;
                when x"3E" => -- '>'
                    case char_y is
                        when "000" => row_data <= x"30";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"0C";
                        when "011" => row_data <= x"0C";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"30";
                        when others=> row_data <= x"00";
                    end case;

                when x"41" => -- 'A'
                    case char_y is
                        when "000" => row_data <= x"18";
                        when "001" => row_data <= x"24";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"7E";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"42" => -- 'B'
                    case char_y is
                        when "000" => row_data <= x"7C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"7C";
                        when others=> row_data <= x"00";
                    end case;
                when x"43" => -- 'C'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"40";
                        when "011" => row_data <= x"40";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"44" => -- 'D'
                    case char_y is
                        when "000" => row_data <= x"78";
                        when "001" => row_data <= x"44";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"44";
                        when "101" => row_data <= x"78";
                        when others=> row_data <= x"00";
                    end case;
                when x"45" => -- 'E'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"40";
                        when "100" => row_data <= x"40";
                        when "101" => row_data <= x"7E";
                        when others=> row_data <= x"00";
                    end case;
                when x"46" => -- 'F'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"40";
                        when "100" => row_data <= x"40";
                        when "101" => row_data <= x"40";
                        when others=> row_data <= x"00";
                    end case;
                when x"47" => -- 'G'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"4E";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"48" => -- 'H'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"7E";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"49" => -- 'I'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"18";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"4A" => -- 'J'
                    case char_y is
                        when "000" => row_data <= x"1E";
                        when "001" => row_data <= x"08";
                        when "010" => row_data <= x"08";
                        when "011" => row_data <= x"08";
                        when "100" => row_data <= x"48";
                        when "101" => row_data <= x"30";
                        when others=> row_data <= x"00";
                    end case;
                when x"4B" => -- 'K'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"44";
                        when "010" => row_data <= x"78";
                        when "011" => row_data <= x"44";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"4C" => -- 'L'
                    case char_y is
                        when "000" => row_data <= x"40";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"40";
                        when "011" => row_data <= x"40";
                        when "100" => row_data <= x"40";
                        when "101" => row_data <= x"7E";
                        when others=> row_data <= x"00";
                    end case;
                when x"4D" => -- 'M'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"66";
                        when "010" => row_data <= x"5A";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"4E" => -- 'N'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"62";
                        when "010" => row_data <= x"52";
                        when "011" => row_data <= x"4A";
                        when "100" => row_data <= x"46";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"4F" => -- 'O'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"50" => -- 'P'
                    case char_y is
                        when "000" => row_data <= x"7C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"40";
                        when "100" => row_data <= x"40";
                        when "101" => row_data <= x"40";
                        when others=> row_data <= x"00";
                    end case;
                when x"51" => -- 'Q'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"4A";
                        when "100" => row_data <= x"44";
                        when "101" => row_data <= x"3A";
                        when others=> row_data <= x"00";
                    end case;
                when x"52" => -- 'R'
                    case char_y is
                        when "000" => row_data <= x"7C";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"7C";
                        when "011" => row_data <= x"48";
                        when "100" => row_data <= x"44";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"53" => -- 'S'
                    case char_y is
                        when "000" => row_data <= x"3C";
                        when "001" => row_data <= x"40";
                        when "010" => row_data <= x"3C";
                        when "011" => row_data <= x"02";
                        when "100" => row_data <= x"02";
                        when "101" => row_data <= x"7C";
                        when others=> row_data <= x"00";
                    end case;
                when x"54" => -- 'T'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"18";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;
                when x"55" => -- 'U'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"42";
                        when "100" => row_data <= x"42";
                        when "101" => row_data <= x"3C";
                        when others=> row_data <= x"00";
                    end case;
                when x"56" => -- 'V'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"24";
                        when "100" => row_data <= x"24";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;
                when x"57" => -- 'W'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"42";
                        when "010" => row_data <= x"42";
                        when "011" => row_data <= x"5A";
                        when "100" => row_data <= x"66";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"58" => -- 'X'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"24";
                        when "010" => row_data <= x"18";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"24";
                        when "101" => row_data <= x"42";
                        when others=> row_data <= x"00";
                    end case;
                when x"59" => -- 'Y'
                    case char_y is
                        when "000" => row_data <= x"42";
                        when "001" => row_data <= x"24";
                        when "010" => row_data <= x"18";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;
                when x"5A" => -- 'Z'
                    case char_y is
                        when "000" => row_data <= x"7E";
                        when "001" => row_data <= x"04";
                        when "010" => row_data <= x"08";
                        when "011" => row_data <= x"10";
                        when "100" => row_data <= x"20";
                        when "101" => row_data <= x"7E";
                        when others=> row_data <= x"00";
                    end case;

                when x"5B" => -- '['
                    case char_y is
                        when "000" => row_data <= x"3E";
                        when "001" => row_data <= x"20";
                        when "010" => row_data <= x"20";
                        when "011" => row_data <= x"20";
                        when "100" => row_data <= x"20";
                        when "101" => row_data <= x"3E";
                        when others=> row_data <= x"00";
                    end case;
                when x"5D" => -- ']'
                    case char_y is
                        when "000" => row_data <= x"7C";
                        when "001" => row_data <= x"04";
                        when "010" => row_data <= x"04";
                        when "011" => row_data <= x"04";
                        when "100" => row_data <= x"04";
                        when "101" => row_data <= x"7C";
                        when others=> row_data <= x"00";
                    end case;
                when x"2E" => -- '.'
                    case char_y is
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;
                when x"3A" => -- ':'
                    case char_y is
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"18";
                        when "100" => row_data <= x"18";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;
                when x"2F" => -- '/'
                    case char_y is
                        when "000" => row_data <= x"02";
                        when "001" => row_data <= x"04";
                        when "010" => row_data <= x"08";
                        when "011" => row_data <= x"10";
                        when "100" => row_data <= x"20";
                        when "101" => row_data <= x"40";
                        when others=> row_data <= x"00";
                    end case;
                when x"21" => -- '!'
                    case char_y is
                        when "000" => row_data <= x"18";
                        when "001" => row_data <= x"18";
                        when "010" => row_data <= x"18";
                        when "011" => row_data <= x"18";
                        when "100" => row_data <= x"00";
                        when "101" => row_data <= x"18";
                        when others=> row_data <= x"00";
                    end case;

                when others =>
                    row_data <= x"00";
            end case;
        end if;
    end process;
    
    pixel_out <= row_data(to_integer(7 - char_x));

end Behavioral;