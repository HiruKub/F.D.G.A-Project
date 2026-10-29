library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity title_scene is
    Port (
        clk             : in  STD_LOGIC;
        h_pos           : in  integer range 0 to 639;
        v_pos           : in  integer range 0 to 479;
        text_pixel_in   : in  STD_LOGIC;
        ascii_code      : out STD_LOGIC_VECTOR(7 downto 0);
        char_x          : out UNSIGNED(2 downto 0);
        char_y          : out UNSIGNED(2 downto 0);
        title_pixel     : out STD_LOGIC_VECTOR(11 downto 0);
        fg_valid        : out STD_LOGIC
    );
end title_scene;

architecture Behavioral of title_scene is
    signal in_title_region  : std_logic := '0';
    signal in_sub_region    : std_logic := '0';
    signal in_start_region  : std_logic := '0';
    signal in_footer_region : std_logic := '0';
    signal blink_cnt        : unsigned(24 downto 0) := (others => '0');
    signal blink            : std_logic := '0';
begin
    text_blink: process(clk)
    begin
        if rising_edge(clk) then
            blink_cnt <= blink_cnt + 1;
        end if;
    end process;
    blink <= blink_cnt(24);

    process(h_pos, v_pos)
        variable char_idx : integer;
    begin
        in_title_region  <= '0';
        in_sub_region    <= '0';
        in_start_region  <= '0';
        in_footer_region <= '0';
        char_x     <= (others => '0');
        char_y     <= (others => '0');
        ascii_code <= x"20";

        if (v_pos >= 95 and v_pos < 127) and (h_pos >= 208 and h_pos < 432) then
            in_title_region <= '1';
            char_idx := (h_pos - 208) / 32;
            char_x   <= to_unsigned(((h_pos - 208) / 4) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 95) / 4, 3);
            case char_idx is
                when 0 => ascii_code <= x"46"; -- 'F'
                when 1 => ascii_code <= x"2E"; -- '.'
                when 2 => ascii_code <= x"44"; -- 'D'
                when 3 => ascii_code <= x"2E"; -- '.'
                when 4 => ascii_code <= x"47"; -- 'G'
                when 5 => ascii_code <= x"2E"; -- '.'
                when 6 => ascii_code <= x"41"; -- 'A'
                when others => ascii_code <= x"20";
            end case;
        elsif (v_pos >= 155 and v_pos < 171) and (h_pos >= 80 and h_pos < 560) then
            in_sub_region <= '1';
            char_idx := (h_pos - 80) / 16;
            char_x   <= to_unsigned(((h_pos - 80) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 155) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"46"; when 1 => ascii_code <= x"41"; when 2 => ascii_code <= x"4E";
                when 3 => ascii_code <= x"54"; when 4 => ascii_code <= x"41"; when 5 => ascii_code <= x"53";
                when 6 => ascii_code <= x"59"; when 7 => ascii_code <= x"20"; when 8 => ascii_code <= x"44";
                when 9 => ascii_code <= x"49"; when 10 => ascii_code <= x"47"; when 11 => ascii_code <= x"49";
                when 12 => ascii_code <= x"54"; when 13 => ascii_code <= x"4F"; when 14 => ascii_code <= x"4E";
                when 15 => ascii_code <= x"20"; when 16 => ascii_code <= x"47"; when 17 => ascii_code <= x"41";
                when 18 => ascii_code <= x"4D"; when 19 => ascii_code <= x"45"; when 20 => ascii_code <= x"20";
                when 21 => ascii_code <= x"41"; when 22 => ascii_code <= x"44"; when 23 => ascii_code <= x"56";
                when 24 => ascii_code <= x"45"; when 25 => ascii_code <= x"4E"; when 26 => ascii_code <= x"54";
                when 27 => ascii_code <= x"55"; when 28 => ascii_code <= x"52"; when 29 => ascii_code <= x"45";
                when others => ascii_code <= x"20";
            end case;
        elsif (v_pos >= 280 and v_pos < 296) and (h_pos >= 192 and h_pos < 448) then
            in_start_region <= '1';
            char_idx := (h_pos - 192) / 16;
            char_x   <= to_unsigned(((h_pos - 192) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 280) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"50"; when 1 => ascii_code <= x"52"; when 2 => ascii_code <= x"45";
                when 3 => ascii_code <= x"53"; when 4 => ascii_code <= x"53"; when 5 => ascii_code <= x"20";
                when 6 => ascii_code <= x"58"; when 7 => ascii_code <= x"20"; when 8 => ascii_code <= x"54";
                when 9 => ascii_code <= x"4F"; when 10 => ascii_code <= x"20"; when 11 => ascii_code <= x"53";
                when 12 => ascii_code <= x"54"; when 13 => ascii_code <= x"41"; when 14 => ascii_code <= x"52";
                when 15 => ascii_code <= x"54"; when others => ascii_code <= x"20";
            end case;
        elsif (v_pos >= 435 and v_pos < 443) and (h_pos >= 96 and h_pos < 544) then
            in_footer_region <= '1';
            char_idx := (h_pos - 96) / 8;
            char_x   <= to_unsigned((h_pos - 96) mod 8, 3);
            char_y   <= to_unsigned(v_pos - 435, 3);
            case char_idx is
                when 0 => ascii_code <= x"44"; when 1 => ascii_code <= x"49"; when 2 => ascii_code <= x"47";
                when 3 => ascii_code <= x"49"; when 4 => ascii_code <= x"54"; when 5 => ascii_code <= x"41";
                when 6 => ascii_code <= x"4C"; when 7 => ascii_code <= x"20"; when 8 => ascii_code <= x"53";
                when 9 => ascii_code <= x"59"; when 10 => ascii_code <= x"53"; when 11 => ascii_code <= x"54";
                when 12 => ascii_code <= x"45"; when 13 => ascii_code <= x"4D"; when 14 => ascii_code <= x"20";
                when 15 => ascii_code <= x"46"; when 16 => ascii_code <= x"55"; when 17 => ascii_code <= x"4E";
                when 18 => ascii_code <= x"44"; when 19 => ascii_code <= x"41"; when 20 => ascii_code <= x"4D";
                when 21 => ascii_code <= x"45"; when 22 => ascii_code <= x"4E"; when 23 => ascii_code <= x"54";
                when 24 => ascii_code <= x"41"; when 25 => ascii_code <= x"4C"; when 26 => ascii_code <= x"53";
                when others => ascii_code <= x"20";
            end case;
        end if;
    end process;

    process(h_pos, v_pos, in_title_region, in_sub_region, in_start_region, in_footer_region, text_pixel_in, blink)
    begin
        fg_valid <= '1';
        if in_title_region = '1' and text_pixel_in = '1' then
            title_pixel <= x"FF0";
        elsif in_sub_region = '1' and text_pixel_in = '1' then
            title_pixel <= x"0FF";
        elsif in_start_region = '1' and text_pixel_in = '1' and blink = '1' then
            title_pixel <= x"FFF";
        elsif in_footer_region = '1' and text_pixel_in = '1' then
            title_pixel <= x"8C8";
        elsif ((v_pos = 75 or v_pos = 77) or (v_pos = 185 or v_pos = 187)) and (h_pos >= 50 and h_pos <= 590) then
            title_pixel <= x"0FF";
        elsif (v_pos = 76 or v_pos = 186) and (h_pos >= 50 and h_pos <= 590) then
            title_pixel <= x"F0F";
        elsif ((h_pos >= 20 and h_pos <= 50) and (v_pos = 20 or v_pos = 460)) or
            ((v_pos >= 20 and v_pos <= 50) and (h_pos = 20 or h_pos = 620)) or
            ((h_pos >= 590 and h_pos <= 620) and (v_pos = 20 or v_pos = 460)) or
            ((v_pos >= 430 and v_pos <= 460) and (h_pos = 20 or h_pos = 620)) then
            title_pixel <= x"0FF";
        else
            title_pixel <= x"000";
            fg_valid    <= '0';  -- transparent: background shows through
        end if;
    end process;
end Behavioral;