library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity character_select_scene is
    Port (
        clk                 : in  STD_LOGIC;
        control             : in  STD_LOGIC_VECTOR(37 downto 0);
        h_pos               : in  integer range 0 to 639;
        v_pos               : in  integer range 0 to 479;
        text_pixel_in       : in  STD_LOGIC;
        ascii_code          : out STD_LOGIC_VECTOR(7 downto 0);
        char_x              : out UNSIGNED(2 downto 0);
        char_y              : out UNSIGNED(2 downto 0);
        char_irgb_in        : in  STD_LOGIC_VECTOR(3 downto 0);
        rom_char_id         : out STD_LOGIC_VECTOR(1 downto 0);
        rom_pose_id         : out STD_LOGIC_VECTOR(2 downto 0);
        rom_pixel_x         : out UNSIGNED(4 downto 0);
        rom_pixel_y         : out UNSIGNED(4 downto 0);
        select_scene_pixel  : out STD_LOGIC_VECTOR(11 downto 0);
        fg_valid            : out STD_LOGIC
    );
end character_select_scene;

architecture Behavioral of character_select_scene is
    signal sw_player        : std_logic_vector(1 downto 0);
    signal anim_cnt         : unsigned(23 downto 0) := (others => '0');
    signal anim_pose        : std_logic_vector(2 downto 0) := "000";
    signal in_text_region   : std_logic := '0';
    signal in_name_region   : std_logic := '0';
    signal in_arrow_region  : std_logic := '0';
    signal in_preview_zone  : std_logic := '0';
    signal char_color_12bit : std_logic_vector(11 downto 0);
    signal sw_player_lvl    : std_logic_vector(5 downto 0);
    signal lvl_tens, lvl_ones : std_logic_vector(7 downto 0);
begin
    sw_player <= control(1 downto 0);
    sw_player_lvl <= control(31 downto 26);

    process(sw_player_lvl)
        variable val : integer;
    begin
        val := to_integer(unsigned(sw_player_lvl));
        lvl_tens <= std_logic_vector(to_unsigned(48 + val / 10, 8));
        lvl_ones <= std_logic_vector(to_unsigned(48 + val mod 10, 8));
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            anim_cnt <= anim_cnt + 1;
        end if;
    end process;
    anim_pose <= "000" when anim_cnt(23) = '0' else "001";

    process(h_pos, v_pos, lvl_tens, lvl_ones, sw_player)
        variable char_idx : integer;
        variable name_x0, name_len : integer;
    begin
        in_text_region  <= '0';
        in_name_region  <= '0';
        in_arrow_region <= '0';
        if sw_player = "00" then          -- FIRE FURY
            name_x0 := 248; name_len := 9;
        else                              -- CABIBOOD / KEROKERO
            name_x0 := 256; name_len := 8;
        end if;

        -- 1. ???????????????? "SELECT CHARACTER"
        if (v_pos >= 40 and v_pos < 56) and (h_pos >= 192 and h_pos < 448) then
            in_text_region <= '1';
            char_idx := (h_pos - 192) / 16;
            char_x   <= to_unsigned(((h_pos - 192) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 40) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"53"; -- 'S'
                when 1 => ascii_code <= x"45"; -- 'E'
                when 2 => ascii_code <= x"4C"; -- 'L'
                when 3 => ascii_code <= x"45"; -- 'E'
                when 4 => ascii_code <= x"43"; -- 'C'
                when 5 => ascii_code <= x"54"; -- 'T'
                when 6 => ascii_code <= x"20";
                when 7 => ascii_code <= x"43"; -- 'C'
                when 8 => ascii_code <= x"48"; -- 'H'
                when 9 => ascii_code <= x"41"; -- 'A'
                when 10 => ascii_code <= x"52"; -- 'R'
                when 11 => ascii_code <= x"41"; -- 'A'
                when 12 => ascii_code <= x"43"; -- 'C'
                when 13 => ascii_code <= x"54"; -- 'T'
                when 14 => ascii_code <= x"45"; -- 'E'
                when 15 => ascii_code <= x"52"; -- 'R'
                when others => ascii_code <= x"20";
            end case;

        -- 2. ??????? "LEVEL xx"
        elsif (v_pos >= 384 and v_pos < 400) and (h_pos >= 256 and h_pos < 384) then
            in_text_region <= '1';
            char_idx := (h_pos - 256) / 16;
            char_x   <= to_unsigned(((h_pos - 256) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 384) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"4C"; -- 'L'
                when 1 => ascii_code <= x"45"; -- 'E'
                when 2 => ascii_code <= x"56"; -- 'V'
                when 3 => ascii_code <= x"45"; -- 'E'
                when 4 => ascii_code <= x"4C"; -- 'L'
                when 5 => ascii_code <= x"20";
                when 6 => ascii_code <= lvl_tens;
                when 7 => ascii_code <= lvl_ones;
                when others => ascii_code <= x"20";
            end case;

        -- 3. [?????????] ??????? "PRESS X TO SELECT" ??????????
        elsif (v_pos >= 432 and v_pos < 448) and (h_pos >= 352 and h_pos < 624) then
            in_text_region <= '1';
            char_idx := (h_pos - 352) / 16;
            char_x   <= to_unsigned(((h_pos - 352) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 432) / 2, 3);
            case char_idx is
                when 0  => ascii_code <= x"50"; -- 'P'
                when 1  => ascii_code <= x"52"; -- 'R'
                when 2  => ascii_code <= x"45"; -- 'E'
                when 3  => ascii_code <= x"53"; -- 'S'
                when 4  => ascii_code <= x"53"; -- 'S'
                when 5  => ascii_code <= x"20"; -- ' '
                when 6  => ascii_code <= x"58"; -- 'X'
                when 7  => ascii_code <= x"20"; -- ' '
                when 8  => ascii_code <= x"54"; -- 'T'
                when 9  => ascii_code <= x"4F"; -- 'O'
                when 10 => ascii_code <= x"20"; -- ' '
                when 11 => ascii_code <= x"53"; -- 'S'
                when 12 => ascii_code <= x"45"; -- 'E'
                when 13 => ascii_code <= x"4C"; -- 'L'
                when 14 => ascii_code <= x"45"; -- 'E'
                when 15 => ascii_code <= x"43"; -- 'C'
                when 16 => ascii_code <= x"54"; -- 'T'
                when others => ascii_code <= x"20";
            end case;

        -- 4. ???????????????
        elsif (v_pos >= 80 and v_pos < 96) and sw_player /= "11"
            and (h_pos >= name_x0 and h_pos < name_x0 + 16 * name_len) then
            in_name_region <= '1';
            char_idx := (h_pos - name_x0) / 16;
            char_x   <= to_unsigned(((h_pos - name_x0) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 80) / 2, 3);
            case sw_player is
                when "00" =>   -- FIRE FURY
                    case char_idx is
                        when 0 => ascii_code <= x"46"; when 1 => ascii_code <= x"49";
                        when 2 => ascii_code <= x"52"; when 3 => ascii_code <= x"45";
                        when 4 => ascii_code <= x"20"; when 5 => ascii_code <= x"46";
                        when 6 => ascii_code <= x"55"; when 7 => ascii_code <= x"52";
                        when 8 => ascii_code <= x"59"; when others => ascii_code <= x"20";
                    end case;
                when "01" =>   -- CABIBOOD
                    case char_idx is
                        when 0 => ascii_code <= x"43"; when 1 => ascii_code <= x"41";
                        when 2 => ascii_code <= x"42"; when 3 => ascii_code <= x"49";
                        when 4 => ascii_code <= x"42"; when 5 => ascii_code <= x"4F";
                        when 6 => ascii_code <= x"4F"; when 7 => ascii_code <= x"44";
                        when others => ascii_code <= x"20";
                    end case;
                when others => -- KEROKERO
                    case char_idx is
                        when 0 => ascii_code <= x"4B"; when 1 => ascii_code <= x"45";
                        when 2 => ascii_code <= x"52"; when 3 => ascii_code <= x"4F";
                        when 4 => ascii_code <= x"4B"; when 5 => ascii_code <= x"45";
                        when 6 => ascii_code <= x"52"; when 7 => ascii_code <= x"4F";
                        when others => ascii_code <= x"20";
                    end case;
            end case;

        -- 5. ?????????/???
        elsif (v_pos >= 224 and v_pos < 256) and (h_pos >= 144 and h_pos < 176)
            and (sw_player = "01" or sw_player = "10") then
            in_arrow_region <= '1';
            ascii_code <= x"3C";
            char_x     <= to_unsigned((h_pos - 144) / 4, 3);
            char_y     <= to_unsigned((v_pos - 224) / 4, 3);
        elsif (v_pos >= 224 and v_pos < 256) and (h_pos >= 464 and h_pos < 496)
            and (sw_player = "00" or sw_player = "01") then
            in_arrow_region <= '1';
            ascii_code <= x"3E";
            char_x     <= to_unsigned((h_pos - 464) / 4, 3);
            char_y     <= to_unsigned((v_pos - 224) / 4, 3);
        else
            char_x         <= (others => '0');
            char_y         <= (others => '0');
            ascii_code     <= x"20";
        end if;
    end process;

    process(h_pos, v_pos, sw_player, anim_pose)
    begin
        rom_pose_id <= anim_pose;
        if (h_pos >= 192 and h_pos < 448) and (v_pos >= 112 and v_pos < 368) then
            in_preview_zone <= '1';
            rom_char_id     <= sw_player;
            rom_pixel_x     <= to_unsigned((h_pos - 192) / 8, 5);
            rom_pixel_y     <= to_unsigned((v_pos - 112) / 8, 5);
        else
            in_preview_zone <= '0';
            rom_char_id     <= "00";
            rom_pixel_x     <= (others => '0');
            rom_pixel_y     <= (others => '0');
        end if;
    end process;

    process(char_irgb_in)
        variable I, R_bit, G_bit, B_bit : std_logic;
    begin
        I     := char_irgb_in(3); R_bit := char_irgb_in(2);
        G_bit := char_irgb_in(1); B_bit := char_irgb_in(0);
        if char_irgb_in = "0101" then
            char_color_12bit <= x"000";
        elsif I = '0' then
            if R_bit = '1' then char_color_12bit(11 downto 8) <= x"F"; else char_color_12bit(11 downto 8) <= x"0"; end if;
            if G_bit = '1' then char_color_12bit(7 downto 4)  <= x"F"; else char_color_12bit(7 downto 4)  <= x"0"; end if;
            if B_bit = '1' then char_color_12bit(3 downto 0)  <= x"F"; else char_color_12bit(3 downto 0)  <= x"0"; end if;
        else
            if R_bit = '1' then char_color_12bit(11 downto 8) <= x"C"; else char_color_12bit(11 downto 8) <= x"4"; end if;
            if G_bit = '1' then char_color_12bit(7 downto 4)  <= x"C"; else char_color_12bit(7 downto 4)  <= x"4"; end if;
            if B_bit = '1' then char_color_12bit(3 downto 0)  <= x"C"; else char_color_12bit(3 downto 0)  <= x"4"; end if;
        end if;
    end process;

    process(h_pos, v_pos, in_text_region, in_name_region, in_arrow_region,
            text_pixel_in, in_preview_zone, char_irgb_in, char_color_12bit)
    begin
        fg_valid <= '1';
        if in_text_region = '1' and text_pixel_in = '1' and v_pos < 432 then
            select_scene_pixel <= x"0FF";
        elsif in_text_region = '1' and text_pixel_in = '1' and v_pos >= 432 then
            select_scene_pixel <= x"FFF";
        elsif in_name_region = '1' and text_pixel_in = '1' then
            select_scene_pixel <= x"FFF";
        elsif in_arrow_region = '1' and text_pixel_in = '1' then
            select_scene_pixel <= x"FF0";
        elsif in_preview_zone = '1' and char_irgb_in /= "0101" then
            select_scene_pixel <= char_color_12bit;
        else
            select_scene_pixel <= x"000";
            fg_valid           <= '0';
        end if;
    end process;
end Behavioral;