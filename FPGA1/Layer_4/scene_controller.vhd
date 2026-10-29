library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Scene controller:
--   0000      : Title
--   0001      : Character Select
--   0010-0011 : Camera (live / frozen)
--   0100-1111 : Battle Scene
entity scene_controller is
    Port (
        clk_vga          : in  STD_LOGIC;
        control          : in  STD_LOGIC_VECTOR(37 downto 0);
        h_pos            : in  integer range 0 to 639;
        v_pos            : in  integer range 0 to 479;
        in_cam_region    : in  STD_LOGIC;
        cam_pixel        : in  STD_LOGIC_VECTOR(11 downto 0);

        text_pixel_in    : in  STD_LOGIC;
        text_ascii       : out STD_LOGIC_VECTOR(7 downto 0);
        text_char_x      : out UNSIGNED(2 downto 0);
        text_char_y      : out UNSIGNED(2 downto 0);

        char_irgb_in     : in  STD_LOGIC_VECTOR(3 downto 0);
        rom_char_id      : out STD_LOGIC_VECTOR(1 downto 0);
        rom_pose_id      : out STD_LOGIC_VECTOR(2 downto 0);
        rom_pixel_x      : out UNSIGNED(4 downto 0);
        rom_pixel_y      : out UNSIGNED(4 downto 0);

        scene_pixel_out  : out STD_LOGIC_VECTOR(11 downto 0)
    );
end scene_controller;

architecture Behavioral of scene_controller is

    signal opcode   : std_logic_vector(3 downto 0);
    signal bg_pixel : std_logic_vector(11 downto 0);
    signal fg_pixel : std_logic_vector(11 downto 0);
    signal fg_valid : std_logic;

    -- Title scene (0000)
    signal s_title_pixel : std_logic_vector(11 downto 0);
    signal s_title_valid : std_logic;
    signal s_title_ascii : std_logic_vector(7 downto 0);
    signal s_title_cx    : unsigned(2 downto 0);
    signal s_title_cy    : unsigned(2 downto 0);

    -- Character select scene (0001)
    signal s_select_pixel  : std_logic_vector(11 downto 0);
    signal s_select_valid  : std_logic;
    signal s_select_ascii  : std_logic_vector(7 downto 0);
    signal s_select_cx     : unsigned(2 downto 0);
    signal s_select_cy     : unsigned(2 downto 0);
    signal s_select_r_char : std_logic_vector(1 downto 0);
    signal s_select_r_pose : std_logic_vector(2 downto 0);
    signal s_select_r_px   : unsigned(4 downto 0);
    signal s_select_r_py   : unsigned(4 downto 0);

    -- Camera scene (0010, 0011)
    signal s_cam_pixel : std_logic_vector(11 downto 0);
    signal s_cam_valid : std_logic;
    signal s_cam_ascii : std_logic_vector(7 downto 0);
    signal s_cam_cx    : unsigned(2 downto 0);
    signal s_cam_cy    : unsigned(2 downto 0);

    -- Battle scene (0100-1111)
    signal s_battle_pixel  : std_logic_vector(11 downto 0);
    signal s_battle_valid  : std_logic;
    signal s_battle_ascii  : std_logic_vector(7 downto 0);
    signal s_battle_cx     : unsigned(2 downto 0);
    signal s_battle_cy     : unsigned(2 downto 0);
    signal s_battle_r_char : std_logic_vector(1 downto 0);
    signal s_battle_r_pose : std_logic_vector(2 downto 0);
    signal s_battle_r_px   : unsigned(4 downto 0);
    signal s_battle_r_py   : unsigned(4 downto 0);

begin

    opcode <= control(37 downto 34);

    u_title_scene : entity work.title_scene
        port map (
            clk           => clk_vga,
            h_pos         => h_pos,
            v_pos         => v_pos,
            text_pixel_in => text_pixel_in,
            ascii_code    => s_title_ascii,
            char_x        => s_title_cx,
            char_y        => s_title_cy,
            title_pixel   => s_title_pixel,
            fg_valid      => s_title_valid
        );

    u_character_select_scene : entity work.character_select_scene
        port map (
            clk                => clk_vga,
            control            => control,
            h_pos              => h_pos,
            v_pos              => v_pos,
            text_pixel_in      => text_pixel_in,
            ascii_code         => s_select_ascii,
            char_x             => s_select_cx,
            char_y             => s_select_cy,
            char_irgb_in       => char_irgb_in,
            rom_char_id        => s_select_r_char,
            rom_pose_id        => s_select_r_pose,
            rom_pixel_x        => s_select_r_px,
            rom_pixel_y        => s_select_r_py,
            select_scene_pixel => s_select_pixel,
            fg_valid           => s_select_valid
        );

    u_camera_scene : entity work.camera_scene
        port map (
            cam_pixel       => cam_pixel,
            in_cam_region   => in_cam_region,
            h_pos           => h_pos,
            v_pos           => v_pos,
            text_pixel_in   => text_pixel_in,
            ascii_code      => s_cam_ascii,
            char_x          => s_cam_cx,
            char_y          => s_cam_cy,
            cam_scene_pixel => s_cam_pixel,
            fg_valid        => s_cam_valid
        );

    -- ????????? Battle Scene Module (??? cam_pixel ???? fb_pixel_in ??????)
    u_battle_scene : entity work.battle_scene
        port map (
            clk           => clk_vga,
            control       => control,
            fb_pixel_in   => cam_pixel,
            h_pos         => h_pos,
            v_pos         => v_pos,
            text_pixel_in => text_pixel_in,
            ascii_code    => s_battle_ascii,
            char_x        => s_battle_cx,
            char_y        => s_battle_cy,
            char_irgb_in  => char_irgb_in,
            rom_char_id   => s_battle_r_char,
            rom_pose_id   => s_battle_r_pose,
            rom_pixel_x   => s_battle_r_px,
            rom_pixel_y   => s_battle_r_py,
            scene_pixel   => s_battle_pixel,
            fg_valid      => s_battle_valid
        );

    u_background : entity work.background
        port map (
            h_pos    => h_pos,
            v_pos    => v_pos,
            bg_pixel => bg_pixel
        );

    -- Foreground wins where the scene is opaque, otherwise the shared background
    scene_pixel_out <= fg_pixel when fg_valid = '1' else bg_pixel;

    ------------------------------------------------------------------------
    -- Scene multiplexer (??? s_battle_pixel ????? opcode ???? 0100 ??????)
    ------------------------------------------------------------------------
    with opcode select
        fg_pixel    <= s_select_pixel when "0001",
                    s_cam_pixel    when "0010" | "0011",
                    s_title_pixel  when "0000",
                    s_battle_pixel when others;

    with opcode select
        fg_valid    <= s_select_valid when "0001",
                    s_cam_valid    when "0010" | "0011",
                    s_title_valid  when "0000",
                    s_battle_valid when others;

    with opcode select
        text_ascii  <= s_select_ascii when "0001",
                    s_cam_ascii    when "0010" | "0011",
                    s_title_ascii  when "0000",
                    s_battle_ascii when others;

    with opcode select
        text_char_x <= s_select_cx    when "0001",
                    s_cam_cx       when "0010" | "0011",
                    s_title_cx     when "0000",
                    s_battle_cx    when others;

    with opcode select
        text_char_y <= s_select_cy    when "0001",
                    s_cam_cy       when "0010" | "0011",
                    s_title_cy     when "0000",
                    s_battle_cy    when others;

    ------------------------------------------------------------------------
    -- Character ROM Multiplexer
    ------------------------------------------------------------------------
    rom_char_id <= s_select_r_char when opcode = "0001" else
                s_battle_r_char when unsigned(opcode) >= 4 else "00";

    rom_pose_id <= s_select_r_pose when opcode = "0001" else
                s_battle_r_pose when unsigned(opcode) >= 4 else "000";

    rom_pixel_x <= s_select_r_px   when opcode = "0001" else
                s_battle_r_px   when unsigned(opcode) >= 4 else (others => '0');

    rom_pixel_y <= s_select_r_py   when opcode = "0001" else
                s_battle_r_py   when unsigned(opcode) >= 4 else (others => '0');

end Behavioral;