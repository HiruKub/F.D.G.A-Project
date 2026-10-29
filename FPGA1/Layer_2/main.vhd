library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity main is
    Port (
        clk_in          : in  STD_LOGIC;
        control         : in  STD_LOGIC_VECTOR(37 downto 0);
        analysis_result : out STD_LOGIC_VECTOR(2 downto 0);

        cam_pclk        : in  STD_LOGIC;
        cam_vsync       : in  STD_LOGIC;
        cam_href        : in  STD_LOGIC;
        cam_data        : in  STD_LOGIC_VECTOR(7 downto 0);
        cam_xclk        : out STD_LOGIC;
        cam_pwdn        : out STD_LOGIC;
        cam_reset       : out STD_LOGIC;
        cam_sioc        : out STD_LOGIC;
        cam_siod        : inout STD_LOGIC;

        vga_hsync       : out STD_LOGIC;
        vga_vsync       : out STD_LOGIC;
        vga_r           : out STD_LOGIC_VECTOR(3 downto 0);
        vga_g           : out STD_LOGIC_VECTOR(3 downto 0);
        vga_b           : out STD_LOGIC_VECTOR(3 downto 0)
    );
end main;

architecture Structural of main is

    component clk_gen
        Port (
            clk_in : in  STD_LOGIC;
            clk_25 : out STD_LOGIC
        );
    end component;

    component camera_unit
        Port (
            clk_25       : in    STD_LOGIC;
            control      : in    STD_LOGIC_VECTOR(37 downto 0);
            ov7670_pclk  : in    STD_LOGIC;
            ov7670_xclk  : out   STD_LOGIC;
            ov7670_vsync : in    STD_LOGIC;
            ov7670_href  : in    STD_LOGIC;
            ov7670_data  : in    STD_LOGIC_VECTOR(7 downto 0);
            ov7670_sioc  : out   STD_LOGIC;
            ov7670_siod  : inout STD_LOGIC;
            ov7670_pwdn  : out   STD_LOGIC;
            ov7670_reset : out   STD_LOGIC;
            rdaddress    : in    STD_LOGIC_VECTOR(14 downto 0);
            rddata       : out   STD_LOGIC_VECTOR(11 downto 0)
        );
    end component;

    component display_unit
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
    end component;

    signal clk_25_sig     : STD_LOGIC;
    signal cam_pixel_sig  : STD_LOGIC_VECTOR(11 downto 0);
    signal rdaddr_sig     : STD_LOGIC_VECTOR(14 downto 0);

begin

    Inst_clk_gen: clk_gen PORT MAP (
        clk_in => clk_in,
        clk_25 => clk_25_sig
    );

    Inst_camera_unit: camera_unit PORT MAP (
        clk_25       => clk_25_sig,
        control      => control,
        ov7670_pclk  => cam_pclk,
        ov7670_xclk  => cam_xclk,
        ov7670_vsync => cam_vsync,
        ov7670_href  => cam_href,
        ov7670_data  => cam_data,
        ov7670_sioc  => cam_sioc,
        ov7670_siod  => cam_siod,
        ov7670_pwdn  => cam_pwdn,
        ov7670_reset => cam_reset,
        rdaddress    => rdaddr_sig,
        rddata       => cam_pixel_sig
    );

    Inst_display_unit: display_unit PORT MAP (
        clk_vga         => clk_25_sig,
        control         => control,
        cam_pixel       => cam_pixel_sig,
        rdaddress       => rdaddr_sig,
        analysis_result => analysis_result,
        vga_hsync       => vga_hsync,
        vga_vsync       => vga_vsync,
        vga_r           => vga_r,
        vga_g           => vga_g,
        vga_b           => vga_b
    );

end Structural;