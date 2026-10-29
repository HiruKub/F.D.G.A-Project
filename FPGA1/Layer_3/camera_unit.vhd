library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity camera_unit is
    Port (
        clk_25       : in  STD_LOGIC;
        control      : in  STD_LOGIC_VECTOR(37 downto 0);
        
        ov7670_pclk  : in  STD_LOGIC;
        ov7670_xclk  : out STD_LOGIC;
        ov7670_vsync : in  STD_LOGIC;
        ov7670_href  : in  STD_LOGIC;
        ov7670_data  : in  STD_LOGIC_VECTOR(7 downto 0);
        ov7670_sioc  : out STD_LOGIC;
        ov7670_siod  : inout STD_LOGIC;
        ov7670_pwdn  : out STD_LOGIC;
        ov7670_reset : out STD_LOGIC;
        
        rdaddress    : in  STD_LOGIC_VECTOR(14 downto 0);
        rddata       : out STD_LOGIC_VECTOR(11 downto 0)
    );
end camera_unit;

architecture Behavioral of camera_unit is

    COMPONENT ov7670_controller_simplified
    PORT(
        clk   : in  STD_LOGIC;
        sioc  : out STD_LOGIC;
        siod  : inout STD_LOGIC;
        reset : out STD_LOGIC;
        pwdn  : out STD_LOGIC;
        xclk  : out STD_LOGIC
    );
    END COMPONENT;

    COMPONENT ov7670_capture
    PORT(
        pclk  : in  STD_LOGIC;
        vsync : in  STD_LOGIC;
        href  : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(7 downto 0);
        addr  : out STD_LOGIC_VECTOR(18 downto 0);
        dout  : out STD_LOGIC_VECTOR(11 downto 0);
        we    : out STD_LOGIC
    );
    END COMPONENT;

    COMPONENT frame_buffer
    PORT(
        data      : in  STD_LOGIC_VECTOR(11 downto 0);
        rdaddress : in  STD_LOGIC_VECTOR(14 downto 0);
        rdclock   : in  STD_LOGIC;
        wraddress : in  STD_LOGIC_VECTOR(14 downto 0);
        wrclock   : in  STD_LOGIC;
        wren      : in  STD_LOGIC;
        q         : out STD_LOGIC_VECTOR(11 downto 0)
    );
    END COMPONENT;

    signal capture_addr : std_logic_vector(18 downto 0);
    signal capture_data : std_logic_vector(11 downto 0);
    signal capture_we   : std_logic;
    signal ram_wren     : std_logic;
    signal opcode       : std_logic_vector(3 downto 0);

begin

    opcode <= control(37 downto 34);

    -- Freeze logic: ??????????????????????? (Opcode 0010) ??????????????????????
    ram_wren <= capture_we when (opcode = "0010") else '0';

    Inst_ov7670_controller: ov7670_controller_simplified PORT MAP(
        clk   => clk_25,
        sioc  => ov7670_sioc,
        siod  => ov7670_siod,
        reset => ov7670_reset,
        pwdn  => ov7670_pwdn,
        xclk  => ov7670_xclk
    );

    Inst_ov7670_capture: ov7670_capture PORT MAP(
        pclk  => ov7670_pclk,
        vsync => ov7670_vsync,
        href  => ov7670_href,
        d     => ov7670_data,
        addr  => capture_addr,
        dout  => capture_data,
        we    => capture_we
    );

    Inst_frame_buffer: frame_buffer PORT MAP(
        data      => capture_data,
        rdaddress => rdaddress,
        rdclock   => clk_25,
        wraddress => capture_addr(14 downto 0),
        wrclock   => ov7670_pclk,
        wren      => ram_wren,
        q         => rddata
    );

end Behavioral;