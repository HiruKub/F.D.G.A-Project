set_property -dict { PACKAGE_PIN H11    IOSTANDARD LVCMOS33 } [get_ports { clk_in }];

set_property -dict { PACKAGE_PIN K11    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];#LSB
set_property -dict { PACKAGE_PIN M11    IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN N14    IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN P12    IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];
set_property -dict { PACKAGE_PIN N10    IOSTANDARD LVCMOS33 } [get_ports { sw[4] }];
set_property -dict { PACKAGE_PIN P10    IOSTANDARD LVCMOS33 } [get_ports { sw[5] }];
set_property -dict { PACKAGE_PIN M10    IOSTANDARD LVCMOS33 } [get_ports { sw[6] }];
set_property -dict { PACKAGE_PIN N4    IOSTANDARD LVCMOS33 } [get_ports { sw[7] }];
set_property -dict { PACKAGE_PIN L2    IOSTANDARD LVCMOS33 } [get_ports { sw[8] }];
set_property -dict { PACKAGE_PIN P3    IOSTANDARD LVCMOS33 } [get_ports { sw[9] }];
set_property -dict { PACKAGE_PIN N1    IOSTANDARD LVCMOS33 } [get_ports { sw[10] }];
set_property -dict { PACKAGE_PIN M2    IOSTANDARD LVCMOS33 } [get_ports { sw[11] }];
set_property -dict { PACKAGE_PIN L1    IOSTANDARD LVCMOS33 } [get_ports { sw[12] }];
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { sw[13] }];
set_property -dict { PACKAGE_PIN K3    IOSTANDARD LVCMOS33 } [get_ports { sw[14] }];
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports { sw[15] }];#MSB

set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btn[0]}]; #Button-top
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btn[1]}]; #Button-bottom
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btn[2]}]; #Button-left
set_property -dict {PACKAGE_PIN J11 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btn[3]}]; #Button-right
set_property -dict {PACKAGE_PIN J12 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btn[4]}]; #Button-center

set_property -dict { PACKAGE_PIN A12 IOSTANDARD LVCMOS33 } [get_ports {sck}];
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports {cs}];
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports {mosi}];
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports {miso}];

set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports {cam_sioc}];
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {cam_siod}]; 
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {cam_vsync}]; 
set_property -dict { PACKAGE_PIN H13 IOSTANDARD LVCMOS33} [get_ports {cam_href}]; 
set_property -dict { PACKAGE_PIN F11 IOSTANDARD LVCMOS33} [get_ports {cam_pclk}];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF];
set_property -dict { PACKAGE_PIN G11 IOSTANDARD LVCMOS33} [get_ports {cam_xclk}]; 
set_property -dict { PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports {cam_data[7]}];
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {cam_data[6]}];
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33} [get_ports {cam_data[5]}]; 
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {cam_data[4]}]; 
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports {cam_data[3]}]; 
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {cam_data[2]}];
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports {cam_data[1]}];  
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports {cam_data[0]}];
set_property -dict { PACKAGE_PIN E12 IOSTANDARD LVCMOS33} [get_ports {cam_reset}];
set_property -dict { PACKAGE_PIN F12 IOSTANDARD LVCMOS33} [get_ports {cam_pwdn}];

set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports {vga_hsync}]; 
set_property -dict { PACKAGE_PIN E4 IOSTANDARD LVCMOS33 } [get_ports {vga_vsync}]; 
set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports {vga_r[0]}]; 
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 } [get_ports {vga_r[1]}]; 
set_property -dict { PACKAGE_PIN C3 IOSTANDARD LVCMOS33 } [get_ports {vga_r[2]}]; 
set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports {vga_r[3]}]; 
set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports {vga_g[0]}]; 
set_property -dict { PACKAGE_PIN B3 IOSTANDARD LVCMOS33 } [get_ports {vga_g[1]}]; 
set_property -dict { PACKAGE_PIN A2 IOSTANDARD LVCMOS33 } [get_ports {vga_g[2]}]; 
set_property -dict { PACKAGE_PIN B5 IOSTANDARD LVCMOS33 } [get_ports {vga_g[3]}]; 
set_property -dict { PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports {vga_b[0]}]; 
set_property -dict { PACKAGE_PIN B2 IOSTANDARD LVCMOS33 } [get_ports {vga_b[1]}]; 
set_property -dict { PACKAGE_PIN B1 IOSTANDARD LVCMOS33 } [get_ports {vga_b[2]}]; 
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports {vga_b[3]}];