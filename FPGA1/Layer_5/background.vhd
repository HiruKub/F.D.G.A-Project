library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Shared background for every scene: dark navy with a 32-pixel grid.
-- Purely combinational function of the pixel position.
entity background is
    Port (
        h_pos    : in  integer range 0 to 639;
        v_pos    : in  integer range 0 to 479;
        bg_pixel : out STD_LOGIC_VECTOR(11 downto 0)
    );
end background;

architecture Behavioral of background is
begin
    bg_pixel <= x"114" when (h_pos mod 32 = 0) or (v_pos mod 32 = 0) else x"002";
end Behavioral;
