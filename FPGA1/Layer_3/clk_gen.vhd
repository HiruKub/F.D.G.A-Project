library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_gen is
    Port (
        clk_in : in  STD_LOGIC;
        clk_25 : out STD_LOGIC
    );
end clk_gen;

architecture Behavioral of clk_gen is
    signal clk_toggle : STD_LOGIC := '0';
begin
    process(clk_in)
    begin
        if rising_edge(clk_in) then
            clk_toggle <= not clk_toggle;
        end if;
    end process;

    clk_25 <= clk_toggle;
end Behavioral;