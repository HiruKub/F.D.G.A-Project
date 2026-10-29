library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_level is
    Port (
        clk_in       : in  STD_LOGIC;

        -- Physical Switches & Buttons for Standalone Testing
        sw           : in  STD_LOGIC_VECTOR(15 downto 0);
        btn          : in  STD_LOGIC_VECTOR(4 downto 0);
        led          : out std_logic_vector(2 downto 0);
        -- SPI Physical Pins
        sck          : in  STD_LOGIC;
        cs           : in  STD_LOGIC;
        mosi         : in  STD_LOGIC;
        miso         : out STD_LOGIC;

        -- OV7670 Camera Physical Pins
        cam_pclk     : in  STD_LOGIC;
        cam_vsync    : in  STD_LOGIC;
        cam_href     : in  STD_LOGIC;
        cam_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        cam_xclk     : out STD_LOGIC;
        cam_pwdn     : out STD_LOGIC;
        cam_reset    : out STD_LOGIC;
        cam_sioc     : out STD_LOGIC;
        cam_siod     : inout STD_LOGIC;

        -- VGA Physical Pins
        vga_hsync    : out STD_LOGIC;
        vga_vsync    : out STD_LOGIC;
        vga_r        : out STD_LOGIC_VECTOR(3 downto 0);
        vga_g        : out STD_LOGIC_VECTOR(3 downto 0);
        vga_b        : out STD_LOGIC_VECTOR(3 downto 0)
    );
end top_level;

architecture Structural of top_level is

    component spi_module
        Port (
            clk             : in  STD_LOGIC;
            sck             : in  STD_LOGIC;
            cs              : in  STD_LOGIC;
            mosi            : in  STD_LOGIC;
            miso            : out STD_LOGIC;
            sw              : in  STD_LOGIC_VECTOR(15 downto 0);
            btn             : in  STD_LOGIC_VECTOR(4 downto 0);
            analysis_result : in  STD_LOGIC_VECTOR(2 downto 0);
            control         : out STD_LOGIC_VECTOR(37 downto 0)
        );
    end component;

    component main
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
    end component;

    signal control_sig      : STD_LOGIC_VECTOR(37 downto 0);
    signal analysis_res_sig : STD_LOGIC_VECTOR(2 downto 0);

begin

    Inst_spi_module: spi_module PORT MAP (
        clk             => clk_in,
        sck             => sck,
        cs              => cs,
        mosi            => mosi,
        miso            => miso,
        sw              => sw,
        btn             => btn,
        analysis_result => analysis_res_sig,
        control         => control_sig
    );

    Inst_main: main PORT MAP (
        clk_in          => clk_in,
        control         => control_sig,
        analysis_result => analysis_res_sig,
        cam_pclk        => cam_pclk,
        cam_vsync       => cam_vsync,
        cam_href        => cam_href,
        cam_data        => cam_data,
        cam_xclk        => cam_xclk,
        cam_pwdn        => cam_pwdn,
        cam_reset       => cam_reset,
        cam_sioc        => cam_sioc,
        cam_siod        => cam_siod,
        vga_hsync       => vga_hsync,
        vga_vsync       => vga_vsync,
        vga_r           => vga_r,
        vga_g           => vga_g,
        vga_b           => vga_b
    );

    led <= analysis_res_sig;

end Structural;