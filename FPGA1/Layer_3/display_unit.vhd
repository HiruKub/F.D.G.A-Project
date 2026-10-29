library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_unit is
    Port (
        clk_vga         : in  STD_LOGIC;
        control         : in  STD_LOGIC_VECTOR(37 downto 0);
        cam_pixel       : in  STD_LOGIC_VECTOR(11 downto 0);
        
        rdaddress       : out STD_LOGIC_VECTOR(14 downto 0);
        analysis_result : out STD_LOGIC_VECTOR(2 downto 0);
        
        vga_hsync       : out STD_LOGIC;
        vga_vsync       : out STD_LOGIC;
        vga_r           : out STD_LOGIC_VECTOR(3 downto 0);
        vga_g           : out STD_LOGIC_VECTOR(3 downto 0);
        vga_b           : out STD_LOGIC_VECTOR(3 downto 0)
    );
end display_unit;

architecture Structural of display_unit is

    signal vsync_sig       : STD_LOGIC;
    signal activeArea_sig  : STD_LOGIC;
    signal blank_sig       : STD_LOGIC;
    signal in_cam_region   : STD_LOGIC;
    signal h_pos           : integer range 0 to 639;
    signal v_pos           : integer range 0 to 479;

    signal text_ascii      : STD_LOGIC_VECTOR(7 downto 0);
    signal text_cx, text_cy: UNSIGNED(2 downto 0);
    signal text_pixel_out  : STD_LOGIC;

    signal rom_char_id     : STD_LOGIC_VECTOR(1 downto 0);
    signal rom_pose_id     : STD_LOGIC_VECTOR(2 downto 0);
    signal rom_px, rom_py  : UNSIGNED(4 downto 0);
    signal char_irgb_out   : STD_LOGIC_VECTOR(3 downto 0);

    signal scene_pixel_out : STD_LOGIC_VECTOR(11 downto 0);
    signal red, green, blue: STD_LOGIC_VECTOR(7 downto 0);

begin

    vga_vsync <= vsync_sig;

    Inst_text_rom: entity work.text_rom PORT MAP (
        clk        => clk_vga,
        ascii_code => text_ascii,
        char_x     => text_cx,
        char_y     => text_cy,
        pixel_out  => text_pixel_out
    );

    Inst_character_rom: entity work.character_rom PORT MAP (
        clk       => clk_vga,
        char_id   => rom_char_id,
        pose_id   => rom_pose_id,
        pixel_x   => rom_px,
        pixel_y   => rom_py,
        pixel_out => char_irgb_out
    );

    Inst_VGA: entity work.VGA PORT MAP (
        CLK25      => clk_vga,
        Hsync      => vga_hsync,
        Vsync      => vsync_sig,
        Nblank     => blank_sig,
        activeArea => activeArea_sig
    );

    -- [????????] ????????? control ????????????? Inst_address_gen
    Inst_address_gen: entity work.address_gen PORT MAP (
        CLK25         => clk_vga,
        control       => control,             -- <== ???????????
        enable        => activeArea_sig,
        vsync         => vsync_sig,
        addr          => rdaddress,
        in_cam_region => in_cam_region,
        h_cnt_out     => h_pos,
        v_cnt_out     => v_pos
    );

    Inst_color_analyzer: entity work.color_analyzer PORT MAP (
        clk             => clk_vga,
        control          => control,
        h_pos           => h_pos,
        v_pos           => v_pos,
        in_cam_region   => in_cam_region,
        cam_pixel       => cam_pixel,
        analysis_result => analysis_result
    );

    Inst_scene_controller: entity work.scene_controller PORT MAP (
        clk_vga         => clk_vga,
        control         => control,
        h_pos           => h_pos,
        v_pos           => v_pos,
        in_cam_region   => in_cam_region,
        cam_pixel       => cam_pixel,
        text_pixel_in   => text_pixel_out,
        text_ascii      => text_ascii,
        text_char_x     => text_cx,
        text_char_y     => text_cy,
        char_irgb_in    => char_irgb_out,
        rom_char_id     => rom_char_id,
        rom_pose_id     => rom_pose_id,
        rom_pixel_x     => rom_px,
        rom_pixel_y     => rom_py,
        scene_pixel_out => scene_pixel_out
    );

    Inst_RGB: entity work.RGB PORT MAP (
        Din    => scene_pixel_out,
        Nblank => blank_sig,
        R      => red,
        G      => green,
        B      => blue
    );

    vga_r <= red(7 downto 4);
    vga_g <= green(7 downto 4);
    vga_b <= blue(7 downto 4);

end Structural;