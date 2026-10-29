library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity battle_scene is
    Port (
        clk                 : in  STD_LOGIC;
        control             : in  STD_LOGIC_VECTOR(37 downto 0);
        
        -- ?????????????? Frame Buffer (??????????????????????? Freeze ??)
        fb_pixel_in         : in  STD_LOGIC_VECTOR(11 downto 0); 
        
        h_pos               : in  integer range 0 to 639;
        v_pos               : in  integer range 0 to 479;
        
        -- ???????????????? Text
        text_pixel_in       : in  STD_LOGIC;
        ascii_code          : out STD_LOGIC_VECTOR(7 downto 0);
        char_x              : out UNSIGNED(2 downto 0);
        char_y              : out UNSIGNED(2 downto 0);
        
        -- ????????? ROM ???????
        char_irgb_in        : in  STD_LOGIC_VECTOR(3 downto 0);
        rom_char_id         : out STD_LOGIC_VECTOR(1 downto 0);
        rom_pose_id         : out STD_LOGIC_VECTOR(2 downto 0);
        rom_pixel_x         : out UNSIGNED(4 downto 0);
        rom_pixel_y         : out UNSIGNED(4 downto 0);
        
        -- ?????????????????????
        scene_pixel         : out STD_LOGIC_VECTOR(11 downto 0);
        fg_valid            : out STD_LOGIC
    );
end battle_scene;

architecture Behavioral of battle_scene is
    -- ???????????? Control
    signal opcode         : std_logic_vector(3 downto 0);
    signal p_char         : std_logic_vector(1 downto 0);
    signal e_char         : std_logic_vector(1 downto 0);
    signal p_lv, e_lv     : std_logic_vector(5 downto 0);
    signal p_hp, e_hp     : std_logic_vector(7 downto 0);
    signal cursor_pos     : std_logic_vector(1 downto 0);

    -- ?????????????????????
    signal p_lv_tens, p_lv_ones : std_logic_vector(7 downto 0);
    signal e_lv_tens, e_lv_ones : std_logic_vector(7 downto 0);
    signal p_hp_len, e_hp_len   : integer range 0 to 189;
    signal p_hp_color, e_hp_color : std_logic_vector(11 downto 0);
    
    signal in_e_sprite, in_p_sprite    : std_logic;
    signal char_color_12bit            : std_logic_vector(11 downto 0);

    -- ????????????????????? Opcode
    signal current_p_pose : std_logic_vector(2 downto 0);
    signal current_e_pose : std_logic_vector(2 downto 0);
    signal enable_cursor  : std_logic;

    -- [?????] ???????????????????????? Idle (000 <-> 001)
    signal anim_cnt  : unsigned(23 downto 0) := (others => '0');
    signal anim_pose : std_logic_vector(2 downto 0) := "000";

begin
    -- Mapping ?????? Control
    opcode     <= control(37 downto 34);
    p_char     <= control(33 downto 32);
    p_lv       <= control(31 downto 26);
    p_hp       <= control(25 downto 18);
    e_char     <= control(17 downto 16);
    e_lv       <= control(15 downto 10);
    e_hp       <= control(9 downto 2);
    cursor_pos <= control(1 downto 0);

    -- [?????] Process ??????????????????????????? clk
    process(clk)
    begin
        if rising_edge(clk) then
            anim_cnt <= anim_cnt + 1;
        end if;
    end process;

    -- ??????? anim_pose ??????? "000" (Idle 1) ??? "001" (Idle 2)
    anim_pose <= "000" when anim_cnt(23) = '0' else "001";

    -- =========================================================================
    -- [ CONFIG ??????? 1: ????????????? (Pose) ???????/??? Cursor ??? Opcode ]
    -- =========================================================================
    process(opcode, cursor_pos)
    begin
        -- ??? Default (??????????, ?????????????)
        current_p_pose <= "000"; 
        current_e_pose <= "000"; 
        enable_cursor  <= '0';   

        case opcode is
            when "0100" => -- ????????????
                current_p_pose <= anim_pose;
                current_e_pose <= anim_pose;
            when "0101" | "0110" => -- ????????????
                current_p_pose <= anim_pose;
                current_e_pose <= anim_pose;
                enable_cursor <= '1';
            when "0111" => -- ????????????
                if cursor_pos = "00" then
                    current_p_pose <= "010";
                else
                    current_p_pose <= "011";
                end if;
                current_e_pose <= "100";
                -- enable_cursor <= '1';
            when "1000" => -- ????????????
                current_p_pose <= "100";
                current_e_pose <= "010";
                -- enable_cursor <= '1';
            when "1001" => -- ????????????
                current_p_pose <= anim_pose;
                current_e_pose <= "100";
                -- enable_cursor <= '1';
            when "1010" => -- ????????????
                current_p_pose <= anim_pose;
                current_e_pose <= anim_pose;
                -- enable_cursor <= '1';
            when "1011" | "1101" => -- ????????????
                current_p_pose <= anim_pose;
                current_e_pose <= "101";
                -- enable_cursor <= '1';
            when "1100" => -- ????????????
                current_p_pose <= "101";
                current_e_pose <= anim_pose;
                -- enable_cursor <= '1';
            when others =>
                null;
        end case;
    end process;

    -- =========================================================================
    -- [ CONFIG ??????? 2: ?????????????? (Text) ??? Opcode ]
    -- =========================================================================
    -- =========================================================================
    -- [ CONFIG ??????? 2: ??????????????? (Text) ??? Opcode - ????? Offset ]
    -- =========================================================================
    process(h_pos, v_pos, opcode, p_char, e_char, p_lv_tens, p_lv_ones, e_lv_tens, e_lv_ones)
        variable char_idx : integer;
    begin
        ascii_code <= x"20"; -- Default: Space
        char_x     <= (others => '0');
        char_y     <= (others => '0');

        ------------------------------------------------------------------------
        -- 1. ????? STATUS ????? (Enemy Box: Y = 40 ??? 132, X = 168 ??? 412)
        ------------------------------------------------------------------------
        -- ?????? 1: ????????????? (Y: 50..66, X: 180..)
        if (v_pos >= 50 and v_pos < 66) and (h_pos >= 180 and h_pos < 340) then
            char_idx := (h_pos - 180) / 16;
            char_x   <= to_unsigned(((h_pos - 180) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 50) / 2, 3);
            case e_char is
                when "00" => -- FIRE FURY
                    case char_idx is
                        when 0 => ascii_code <= x"46"; when 1 => ascii_code <= x"49";
                        when 2 => ascii_code <= x"52"; when 3 => ascii_code <= x"45";
                        when 4 => ascii_code <= x"20"; when 5 => ascii_code <= x"46";
                        when 6 => ascii_code <= x"55"; when 7 => ascii_code <= x"52";
                        when 8 => ascii_code <= x"59"; when others => ascii_code <= x"20";
                    end case;
                when "01" => -- CABIBOOD
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

        -- ?????? 2: ?????????????? "LV xx" (Y: 66..82, X: 180..)
        elsif (v_pos >= 66 and v_pos < 82) and (h_pos >= 180 and h_pos < 260) then
            char_idx := (h_pos - 180) / 16;
            char_x   <= to_unsigned(((h_pos - 180) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 66) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"4C"; -- 'L'
                when 1 => ascii_code <= x"56"; -- 'V'
                when 2 => ascii_code <= x"20"; -- ' '
                when 3 => ascii_code <= e_lv_tens; -- ??????????
                when 4 => ascii_code <= e_lv_ones; -- ????????????
                when others => ascii_code <= x"20";
            end case;

        ------------------------------------------------------------------------
        -- 2. ????? STATUS ??????? (Player Box: Y = 190 ??? 282, X = 228 ??? 472)
        ------------------------------------------------------------------------
        -- ?????? 1: ??????????????? (Y: 200..216, X: 240..)
        elsif (v_pos >= 200 and v_pos < 216) and (h_pos >= 240 and h_pos < 400) then
            char_idx := (h_pos - 240) / 16;
            char_x   <= to_unsigned(((h_pos - 240) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 200) / 2, 3);
            case p_char is
                when "00" => -- FIRE FURY
                    case char_idx is
                        when 0 => ascii_code <= x"46"; when 1 => ascii_code <= x"49";
                        when 2 => ascii_code <= x"52"; when 3 => ascii_code <= x"45";
                        when 4 => ascii_code <= x"20"; when 5 => ascii_code <= x"46";
                        when 6 => ascii_code <= x"55"; when 7 => ascii_code <= x"52";
                        when 8 => ascii_code <= x"59"; when others => ascii_code <= x"20";
                    end case;
                when "01" => -- CABIBOOD
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

        -- ?????? 2: ???????????????? "LV xx" (Y: 216..232, X: 240..)
        elsif (v_pos >= 216 and v_pos < 232) and (h_pos >= 240 and h_pos < 320) then
            char_idx := (h_pos - 240) / 16;
            char_x   <= to_unsigned(((h_pos - 240) / 2) mod 8, 3);
            char_y   <= to_unsigned((v_pos - 216) / 2, 3);
            case char_idx is
                when 0 => ascii_code <= x"4C"; -- 'L'
                when 1 => ascii_code <= x"56"; -- 'V'
                when 2 => ascii_code <= x"20"; -- ' '
                when 3 => ascii_code <= p_lv_tens; -- ??????????
                when 4 => ascii_code <= p_lv_ones; -- ????????????
                when others => ascii_code <= x"20";
            end case;
        else

        case opcode is
            when "0100" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 340) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"46"; -- 'F'
                        when 1  => ascii_code <= x"49"; -- 'I'
                        when 2  => ascii_code <= x"47"; -- 'G'
                        when 3  => ascii_code <= x"48"; -- 'H'
                        when 4  => ascii_code <= x"54"; -- 'T'
                        when 5  => ascii_code <= x"49"; -- 'I'
                        when 6  => ascii_code <= x"4E"; -- 'N'
                        when 7  => ascii_code <= x"47"; -- 'G'
                        when 8  => ascii_code <= x"20"; -- ' '
                        when 9  => ascii_code <= x"42"; -- 'B'
                        when 10 => ascii_code <= x"45"; -- 'E'
                        when 11 => ascii_code <= x"47"; -- 'G'
                        when 12 => ascii_code <= x"49"; -- 'I'
                        when 13 => ascii_code <= x"4E"; -- 'N'
                        when 14 => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "0101" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 196) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"41"; -- 'A'
                        when 1  => ascii_code <= x"54"; -- 'T'
                        when 2  => ascii_code <= x"54"; -- 'T'
                        when 3  => ascii_code <= x"41"; -- 'A'
                        when 4  => ascii_code <= x"43"; -- 'C'
                        when 5  => ascii_code <= x"4B"; -- 'K'
                        when others => ascii_code <= x"20";
                    end case;
                elsif (v_pos >= 350 and v_pos < 366) and (h_pos >= 320 and h_pos < 432) then
                    char_idx := (h_pos - 320) / 16;
                    char_x   <= to_unsigned(((h_pos - 320) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"43"; -- 'C'
                        when 1  => ascii_code <= x"41"; -- 'A'
                        when 2  => ascii_code <= x"50"; -- 'P'
                        when 3  => ascii_code <= x"54"; -- 'T'
                        when 4  => ascii_code <= x"55"; -- 'U'
                        when 5  => ascii_code <= x"52"; -- 'R'
                        when 6  => ascii_code <= x"45"; -- 'E'
                        when others => ascii_code <= x"20";
                    end case;
                elsif (v_pos >= 370 and v_pos < 386) and (h_pos >= 100 and h_pos < 180) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 370) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"45"; -- 'E'
                        when 1  => ascii_code <= x"56"; -- 'V'
                        when 2  => ascii_code <= x"41"; -- 'A'
                        when 3  => ascii_code <= x"44"; -- 'D'
                        when 4  => ascii_code <= x"45"; -- 'E'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "0110" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 196) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"41"; -- 'A'
                        when 1  => ascii_code <= x"54"; -- 'T'
                        when 2  => ascii_code <= x"54"; -- 'T'
                        when 3  => ascii_code <= x"41"; -- 'A'
                        when 4  => ascii_code <= x"43"; -- 'C'
                        when 5  => ascii_code <= x"4B"; -- 'K'
                        when others => ascii_code <= x"20";
                    end case;
                elsif (v_pos >= 350 and v_pos < 366) and (h_pos >= 320 and h_pos < 416) then
                    char_idx := (h_pos - 320) / 16;
                    char_x   <= to_unsigned(((h_pos - 320) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"53"; -- 'S'
                        when 1  => ascii_code <= x"54"; -- 'T'
                        when 2  => ascii_code <= x"52"; -- 'R'
                        when 3  => ascii_code <= x"49"; -- 'I'
                        when 4  => ascii_code <= x"4B"; -- 'K'
                        when 5  => ascii_code <= x"45"; -- 'E'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "0111" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 484) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"59"; -- 'Y'
                        when 1  => ascii_code <= x"4F"; -- 'O'
                        when 2  => ascii_code <= x"55"; -- 'U'
                        when 3  => ascii_code <= x"52"; -- 'R'
                        when 4  => ascii_code <= x"20"; -- ' '
                        when 5  => ascii_code <= x"52"; -- 'R'
                        when 6  => ascii_code <= x"45"; -- 'E'
                        when 7  => ascii_code <= x"49"; -- 'I'
                        when 8  => ascii_code <= x"47"; -- 'G'
                        when 9  => ascii_code <= x"4E"; -- 'N'
                        when 10 => ascii_code <= x"20"; -- ' '
                        when 11 => ascii_code <= x"4F"; -- 'O'
                        when 12 => ascii_code <= x"46"; -- 'F'
                        when 13 => ascii_code <= x"20"; -- ' '
                        when 14 => ascii_code <= x"54"; -- 'T'
                        when 15 => ascii_code <= x"45"; -- 'E'
                        when 16 => ascii_code <= x"52"; -- 'R'
                        when 17 => ascii_code <= x"52"; -- 'R'
                        when 18 => ascii_code <= x"4F"; -- 'O'
                        when 19 => ascii_code <= x"52"; -- 'R'
                        when 20 => ascii_code <= x"20"; -- ' '
                        when 21 => ascii_code <= x"45"; -- 'E'
                        when 22 => ascii_code <= x"4E"; -- 'N'
                        when 23 => ascii_code <= x"44"; -- 'D'
                        when 24 => ascii_code <= x"53"; -- 'S'
                        when others => ascii_code <= x"20";
                    end case;
                elsif (v_pos >= 370 and v_pos < 386) and (h_pos >= 100 and h_pos < 180) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 370) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"48"; -- 'H'
                        when 1  => ascii_code <= x"45"; -- 'E'
                        when 2  => ascii_code <= x"52"; -- 'R'
                        when 3  => ascii_code <= x"45"; -- 'E'
                        when 4  => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1000" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 484) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"59"; -- 'Y'
                        when 1  => ascii_code <= x"4F"; -- 'O'
                        when 2  => ascii_code <= x"55"; -- 'U'
                        when 3  => ascii_code <= x"52"; -- 'R'
                        when 4  => ascii_code <= x"20"; -- ' '
                        when 5  => ascii_code <= x"50"; -- 'P'
                        when 6  => ascii_code <= x"52"; -- 'R'
                        when 7  => ascii_code <= x"49"; -- 'I'
                        when 8  => ascii_code <= x"44"; -- 'D'
                        when 9  => ascii_code <= x"45"; -- 'E'
                        when 10 => ascii_code <= x"20"; -- ' '
                        when 11 => ascii_code <= x"4D"; -- 'M'
                        when 12 => ascii_code <= x"45"; -- 'E'
                        when 13 => ascii_code <= x"41"; -- 'A'
                        when 14 => ascii_code <= x"4E"; -- 'N'
                        when 15 => ascii_code <= x"53"; -- 'S'
                        when 16 => ascii_code <= x"20"; -- ' '
                        when 17 => ascii_code <= x"4E"; -- 'N'
                        when 18 => ascii_code <= x"4F"; -- 'O'
                        when 19 => ascii_code <= x"54"; -- 'T'
                        when 20 => ascii_code <= x"48"; -- 'H'
                        when 21 => ascii_code <= x"49"; -- 'I'
                        when 22 => ascii_code <= x"4E"; -- 'N'
                        when 23 => ascii_code <= x"47"; -- 'G'
                        when others => ascii_code <= x"20";
                    end case;
                elsif (v_pos >= 370 and v_pos < 386) and (h_pos >= 100 and h_pos < 356) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 370) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"42"; -- 'B'
                        when 1  => ascii_code <= x"45"; -- 'E'
                        when 2  => ascii_code <= x"46"; -- 'F'
                        when 3  => ascii_code <= x"4F"; -- 'O'
                        when 4  => ascii_code <= x"52"; -- 'R'
                        when 5  => ascii_code <= x"45"; -- 'E'
                        when 6  => ascii_code <= x"20"; -- ' '
                        when 7  => ascii_code <= x"4D"; -- 'M'
                        when 8  => ascii_code <= x"59"; -- 'Y'
                        when 9  => ascii_code <= x"20"; -- ' '
                        when 10 => ascii_code <= x"4D"; -- 'M'
                        when 11 => ascii_code <= x"49"; -- 'I'
                        when 12 => ascii_code <= x"47"; -- 'G'
                        when 13 => ascii_code <= x"48"; -- 'H'
                        when 14 => ascii_code <= x"54"; -- 'T'
                        when 15 => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1001" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 436) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"42"; -- 'B'
                        when 1  => ascii_code <= x"45"; -- 'E'
                        when 2  => ascii_code <= x"20"; -- ' '
                        when 3  => ascii_code <= x"4D"; -- 'M'
                        when 4  => ascii_code <= x"49"; -- 'I'
                        when 5  => ascii_code <= x"4E"; -- 'N'
                        when 6  => ascii_code <= x"45"; -- 'E'
                        when 7  => ascii_code <= x"21"; -- '!'
                        when 8  => ascii_code <= x"20"; -- ' '
                        when 9  => ascii_code <= x"43"; -- 'C'
                        when 10 => ascii_code <= x"41"; -- 'A'
                        when 11 => ascii_code <= x"50"; -- 'P'
                        when 12 => ascii_code <= x"54"; -- 'T'
                        when 13 => ascii_code <= x"55"; -- 'U'
                        when 14 => ascii_code <= x"52"; -- 'R'
                        when 15 => ascii_code <= x"49"; -- 'I'
                        when 16 => ascii_code <= x"4E"; -- 'N'
                        when 17 => ascii_code <= x"47"; -- 'G'
                        when 18 => ascii_code <= x"2E"; -- '.'
                        when 19 => ascii_code <= x"2E"; -- '.'
                        when 20 => ascii_code <= x"2E"; -- '.'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1010" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 388) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"53"; -- 'S'
                        when 1  => ascii_code <= x"45"; -- 'E'
                        when 2  => ascii_code <= x"45"; -- 'E'
                        when 3  => ascii_code <= x"20"; -- ' '
                        when 4  => ascii_code <= x"55"; -- 'U'
                        when 5  => ascii_code <= x"20"; -- ' '
                        when 6  => ascii_code <= x"4E"; -- 'N'
                        when 7  => ascii_code <= x"45"; -- 'E'
                        when 8  => ascii_code <= x"58"; -- 'X'
                        when 9  => ascii_code <= x"54"; -- 'T'
                        when 10 => ascii_code <= x"20"; -- ' '
                        when 11 => ascii_code <= x"54"; -- 'T'
                        when 12 => ascii_code <= x"49"; -- 'I'
                        when 13 => ascii_code <= x"4D"; -- 'M'
                        when 14 => ascii_code <= x"45"; -- 'E'
                        when 15 => ascii_code <= x"20"; -- ' '
                        when 16 => ascii_code <= x"3E"; -- '>'
                        when 17 => ascii_code <= x"3C"; -- '<'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1011" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 356) then
                    char_idx := (h_pos - 100) / 16;
                    
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    
                    case char_idx is
                        when 0  => ascii_code <= x"56"; -- 'V'
                        when 1  => ascii_code <= x"49"; -- 'I'
                        when 2  => ascii_code <= x"43"; -- 'C'
                        when 3  => ascii_code <= x"54"; -- 'T'
                        when 4  => ascii_code <= x"4F"; -- 'O'
                        when 5  => ascii_code <= x"52"; -- 'R'
                        when 6  => ascii_code <= x"59"; -- 'Y'
                        when 7  => ascii_code <= x"20"; -- ' '
                        when 8  => ascii_code <= x"49"; -- 'I'
                        when 9  => ascii_code <= x"53"; -- 'S'
                        when 10 => ascii_code <= x"20"; -- ' '
                        when 11 => ascii_code <= x"4D"; -- 'M'
                        when 12 => ascii_code <= x"49"; -- 'I'
                        when 13 => ascii_code <= x"4E"; -- 'N'
                        when 14 => ascii_code <= x"45"; -- 'E'
                        when 15 => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1100" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 436) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"4E"; -- 'N'
                        when 1  => ascii_code <= x"45"; -- 'E'
                        when 2  => ascii_code <= x"58"; -- 'X'
                        when 3  => ascii_code <= x"54"; -- 'T'
                        when 4  => ascii_code <= x"20"; -- ' '
                        when 5  => ascii_code <= x"54"; -- 'T'
                        when 6  => ascii_code <= x"49"; -- 'I'
                        when 7  => ascii_code <= x"4D"; -- 'M'
                        when 8  => ascii_code <= x"45"; -- 'E'
                        when 9  => ascii_code <= x"20"; -- ' '
                        when 10 => ascii_code <= x"49"; -- 'I'
                        when 11 => ascii_code <= x"20"; -- ' '
                        when 12 => ascii_code <= x"57"; -- 'W'
                        when 13 => ascii_code <= x"49"; -- 'I'
                        when 14 => ascii_code <= x"4C"; -- 'L'
                        when 15 => ascii_code <= x"4C"; -- 'L'
                        when 16 => ascii_code <= x"20"; -- ' '
                        when 17 => ascii_code <= x"57"; -- 'W'
                        when 18 => ascii_code <= x"49"; -- 'I'
                        when 19 => ascii_code <= x"4E"; -- 'N'
                        when 20 => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;

            when "1101" =>
                if (v_pos >= 350 and v_pos < 366) and (h_pos >= 100 and h_pos < 436) then
                    char_idx := (h_pos - 100) / 16;
                    char_x   <= to_unsigned(((h_pos - 100) / 2) mod 8, 3);
                    char_y   <= to_unsigned((v_pos - 350) / 2, 3);
                    case char_idx is
                        when 0  => ascii_code <= x"47"; -- 'G'
                        when 1  => ascii_code <= x"4F"; -- 'O'
                        when 2  => ascii_code <= x"54"; -- 'T'
                        when 3  => ascii_code <= x"43"; -- 'C'
                        when 4  => ascii_code <= x"48"; -- 'H'
                        when 5  => ascii_code <= x"41"; -- 'A'
                        when 6  => ascii_code <= x"21"; -- '!'
                        when 7  => ascii_code <= x"20"; -- ' '
                        when 8  => ascii_code <= x"4E"; -- 'N'
                        when 9  => ascii_code <= x"4F"; -- 'O'
                        when 10 => ascii_code <= x"57"; -- 'W'
                        when 11 => ascii_code <= x"20"; -- ' '
                        when 12 => ascii_code <= x"4C"; -- 'L'
                        when 13 => ascii_code <= x"45"; -- 'E'
                        when 14 => ascii_code <= x"56"; -- 'V'
                        when 15 => ascii_code <= x"45"; -- 'E'
                        when 16 => ascii_code <= x"4C"; -- 'L'
                        when 17 => ascii_code <= x"20"; -- ' '
                        when 18 => ascii_code <= x"55"; -- 'U'
                        when 19 => ascii_code <= x"50"; -- 'P'
                        when 20 => ascii_code <= x"21"; -- '!'
                        when others => ascii_code <= x"20";
                    end case;
                end if;
            
            when others => null;
        end case;
    end if;
    end process;


    -- =========================================================================
    -- [ ??????????????????? - ??????, ????????? ????? Sprite ]
    -- =========================================================================
    process(p_lv, e_lv)
        variable p_val, e_val : integer;
    begin
        p_val := to_integer(unsigned(p_lv)); e_val := to_integer(unsigned(e_lv));
        p_lv_tens <= std_logic_vector(to_unsigned(48 + p_val / 10, 8));
        p_lv_ones <= std_logic_vector(to_unsigned(48 + p_val mod 10, 8));
        e_lv_tens <= std_logic_vector(to_unsigned(48 + e_val / 10, 8));
        e_lv_ones <= std_logic_vector(to_unsigned(48 + e_val mod 10, 8));
    end process;

    process(p_hp, e_hp)
        variable p_val, e_val : integer;
    begin
        p_val := to_integer(unsigned(p_hp));
        e_val := to_integer(unsigned(e_hp));

        -- ???????????????????? 255 -> 189 ??????
        p_hp_len <= (p_val * 189) / 255;
        e_hp_len <= (e_val * 189) / 255;

        -- ????????????????? 8 ???
        if p_val > 128 then p_hp_color <= x"0F0";
        elsif p_val > 50 then p_hp_color <= x"FF0";
        else p_hp_color <= x"F00";
        end if;

        if e_val > 128 then e_hp_color <= x"0F0";
        elsif e_val > 50 then e_hp_color <= x"FF0";
        else e_hp_color <= x"F00";
        end if;
    end process;

    process(char_irgb_in)
        variable I, R_bit, G_bit, B_bit : std_logic;
    begin
        I := char_irgb_in(3); R_bit := char_irgb_in(2); G_bit := char_irgb_in(1); B_bit := char_irgb_in(0);
        if char_irgb_in = "0101" then char_color_12bit <= x"000"; 
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

    -- ???? Pose ??????????????? ROM ??????????????
    process(h_pos, v_pos, p_char, e_char, current_p_pose, current_e_pose, opcode)
    begin
        in_p_sprite <= '0';
        in_e_sprite <= '0';
        rom_char_id <= "00";
        rom_pose_id <= "000"; 
        rom_pixel_x <= (others => '0');
        rom_pixel_y <= (others => '0');

        -- Enemy
        if (h_pos >= 426 and h_pos < 554) and (v_pos >= 40 and v_pos < 168) and e_char /= "11" then
            in_e_sprite <= '1';
            rom_char_id <= e_char;
            rom_pose_id <= current_e_pose; 
            rom_pixel_x <= to_unsigned((h_pos - 426) / 4, 5);
            rom_pixel_y <= to_unsigned((v_pos - 40) / 4, 5);
        
        -- Player
        elsif (h_pos >= 90 and h_pos < 218) and (v_pos >= 170 and v_pos < 298) and p_char /= "11" then
            in_p_sprite <= '1';
            rom_char_id <= p_char;
            rom_pose_id <= current_p_pose; 
            if opcode = "1100" then
                rom_pixel_x <= to_unsigned((h_pos - 90) / 4, 5);
            else
                rom_pixel_x <= to_unsigned(31 - ((h_pos - 90) / 4), 5);
            end if;
            rom_pixel_y <= to_unsigned((v_pos - 170) / 4, 5);
        end if;
    end process;


    -- =========================================================================
    -- [ ???? Render ?????????? ]
    -- =========================================================================
    process(h_pos, v_pos, text_pixel_in, in_e_sprite, in_p_sprite, char_irgb_in, char_color_12bit, 
            p_hp_len, e_hp_len, p_hp_color, e_hp_color, enable_cursor, cursor_pos, fb_pixel_in)
    begin
        fg_valid <= '1';
        scene_pixel <= x"000";

        -- 1. ?????????
        if (h_pos >= 168 and h_pos <= 412) and (v_pos >= 40 and v_pos <= 132) then
            if (h_pos = 168 or h_pos = 412 or v_pos = 40 or v_pos = 132) then scene_pixel <= x"F44"; 
            else
                if (h_pos >= 214 and h_pos < 403) and (v_pos >= 85 and v_pos < 95) then
                    if (h_pos - 214) < e_hp_len then scene_pixel <= e_hp_color; else scene_pixel <= x"444"; end if;
                else
                    scene_pixel <= x"111"; 
                    if text_pixel_in = '1' then scene_pixel <= x"FFF"; end if;
                end if;
            end if;

        -- 2. ???????????
        elsif (h_pos >= 228 and h_pos <= 472) and (v_pos >= 190 and v_pos <= 282) then
            if (h_pos = 228 or h_pos = 472 or v_pos = 190 or v_pos = 282) then scene_pixel <= x"0FF"; 
            else
                if (h_pos >= 274 and h_pos < 463) and (v_pos >= 235 and v_pos < 245) then
                    if (h_pos - 274) < p_hp_len then scene_pixel <= p_hp_color; else scene_pixel <= x"444"; end if;
                else
                    scene_pixel <= x"111";
                    if text_pixel_in = '1' then scene_pixel <= x"FFF"; end if;
                end if;
            end if;

        -- 3. ???????????????? (????????????? Frame Buffer)
        elsif (h_pos >= 46 and h_pos <= 594) and (v_pos >= 330 and v_pos <= 434) then
            -- ??????????
            if (h_pos = 46 or h_pos = 594 or v_pos = 330 or v_pos = 434) then scene_pixel <= x"FFF"; 
            else
                -- [????????????????]: ????????? Frame Buffer ????????????????? 64x64 ??????
                if (h_pos >= 520 and h_pos < 584) and (v_pos >= 360 and v_pos < 424) then
                    scene_pixel <= fb_pixel_in;
                
                -- ????????? ?????? ??????????????????????????????
                else
                    scene_pixel <= x"001"; -- ?????????????????????
                    
                    if text_pixel_in = '1' then 
                        scene_pixel <= x"FFF"; -- ???????
                        
                        -- ??? Cursor
                        if enable_cursor = '1' then
                            if cursor_pos = "00" and h_pos < 320 and v_pos < 368 then scene_pixel <= x"FF0";
                            elsif cursor_pos = "01" and h_pos >= 320 and v_pos < 368 then scene_pixel <= x"FF0";
                            elsif cursor_pos = "10" and h_pos < 320 and v_pos >= 368 then scene_pixel <= x"FF0";
                            elsif cursor_pos = "11" and h_pos >= 320 and v_pos >= 368 then scene_pixel <= x"FF0";
                            end if;
                        end if;
                    end if;
                end if;
            end if;

        -- 4. ??? Sprite ??????? (????????? 0101 ???????????)
        elsif (in_e_sprite = '1' or in_p_sprite = '1') and char_irgb_in /= "0101" then
            scene_pixel <= char_color_12bit;
            
        -- ??????????????? ??????????????????? (Background)
        else
            fg_valid <= '0'; 
        end if;
    end process;

end Behavioral;