library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity camera_scene is
    Port (
        cam_pixel        : in  STD_LOGIC_VECTOR(11 downto 0);
        in_cam_region    : in  STD_LOGIC;
        h_pos            : in  integer range 0 to 639;
        v_pos            : in  integer range 0 to 479;
        text_pixel_in    : in  STD_LOGIC;
        ascii_code       : out STD_LOGIC_VECTOR(7 downto 0);
        char_x           : out UNSIGNED(2 downto 0);
        char_y           : out UNSIGNED(2 downto 0);
        cam_scene_pixel  : out STD_LOGIC_VECTOR(11 downto 0);
        fg_valid         : out STD_LOGIC
    );
end camera_scene;

architecture Behavioral of camera_scene is
    signal in_text_region : std_logic := '0';
    signal is_crosshair   : std_logic := '0';
begin
    process(h_pos, v_pos)
        variable char_idx : integer;
    begin
        if (v_pos >= 380 and v_pos < 396) and (h_pos >= 176 and h_pos < 464) then
            in_text_region <= '1';
            char_idx := (h_pos - 176) / 16;
            char_x   <= to_unsigned(((h_pos - 176) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 380) / 2, 3);
            case char_idx is
                when 0  => ascii_code <= x"50"; when 1  => ascii_code <= x"52"; when 2  => ascii_code <= x"45";
                when 3  => ascii_code <= x"53"; when 4  => ascii_code <= x"53"; when 5  => ascii_code <= x"20";
                when 6  => ascii_code <= x"58"; when 7  => ascii_code <= x"20"; when 8  => ascii_code <= x"54";
                when 9  => ascii_code <= x"4F"; when 10 => ascii_code <= x"20"; when 11 => ascii_code <= x"43";
                when 12 => ascii_code <= x"41"; when 13 => ascii_code <= x"50"; when 14 => ascii_code <= x"54";
                when 15 => ascii_code <= x"55"; when 16 => ascii_code <= x"52"; when 17 => ascii_code <= x"45";
                when others => ascii_code <= x"20";
            end case;
        else
            in_text_region <= '0';
            char_x         <= (others => '0');
            char_y         <= (others => '0');
            ascii_code     <= x"20";
        end if;
    end process;

    process(h_pos, v_pos)
    begin
        if ((h_pos >= 310 and h_pos <= 330) and (v_pos >= 239 and v_pos <= 240)) or
        ((v_pos >= 230 and v_pos <= 250) and (h_pos >= 319 and h_pos <= 320)) then
            is_crosshair <= '1';
        else
            is_crosshair <= '0';
        end if;
    end process;

    process(h_pos, v_pos, in_cam_region, cam_pixel, is_crosshair, in_text_region, text_pixel_in)
    begin
        fg_valid <= '1';
        if in_text_region = '1' and text_pixel_in = '1' then
            cam_scene_pixel <= x"FFF";
        elsif in_cam_region = '1' and is_crosshair = '1' then
            cam_scene_pixel <= x"0FF";
        elsif in_cam_region = '1' then
            cam_scene_pixel <= cam_pixel;
        elsif (h_pos >= 158 and h_pos < 482) and (v_pos >= 118 and v_pos < 362) then
            cam_scene_pixel <= x"FFF";
        else
            cam_scene_pixel <= x"000";
            fg_valid        <= '0';  -- transparent: background shows through
        end if;
    end process;
end Behavioral;