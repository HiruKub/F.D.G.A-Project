library IEEE; use IEEE.STD_LOGIC_1164.ALL; use IEEE.NUMERIC_STD.ALL;
entity tb is end tb;
architecture sim of tb is
  signal control : std_logic_vector(33 downto 0) := (others=>'0');
  signal h : integer range 0 to 639 := 0;
  signal v : integer range 0 to 479 := 0;
  signal irgb : std_logic_vector(3 downto 0) := "0000";
  signal ascii : std_logic_vector(7 downto 0);
  signal cx, cy : unsigned(2 downto 0);
  signal cid : std_logic_vector(1 downto 0);
  signal pid : std_logic_vector(2 downto 0);
  signal px, py : unsigned(4 downto 0);
  signal pix : std_logic_vector(11 downto 0);
  signal fails : integer := 0;
begin
  dut: entity work.scene_controller port map(
    clk_vga=>'0', control=>control, h_pos=>h, v_pos=>v, in_cam_region=>'0',
    cam_pixel=>x"000", text_pixel_in=>'0', text_ascii=>ascii, text_char_x=>cx,
    text_char_y=>cy, char_irgb_in=>irgb, rom_char_id=>cid, rom_pose_id=>pid,
    rom_pixel_x=>px, rom_pixel_y=>py, scene_pixel_out=>pix);
  process
    procedure chk(name: string; op, hh, vv: integer; ir: std_logic_vector(3 downto 0); exp: std_logic_vector(11 downto 0)) is
    begin
      control(33 downto 30) <= std_logic_vector(to_unsigned(op,4));
      h <= hh; v <= vv; irgb <= ir; wait for 10 ns;
      if pix = exp then report "PASS  " & name & " = 0x" & to_hstring(pix);
      else report "FAIL  " & name & " = 0x" & to_hstring(pix) & " expected 0x" & to_hstring(exp); end if;
    end;
  begin
    -- พื้นหลังต้องเหมือนกันทุกฉาก
    for op in 0 to 3 loop
      chk("bg  op" & integer'image(op) & " (33,33)   plain", op, 33, 33, "0000", x"002");
      chk("bg  op" & integer'image(op) & " (32,33)   grid ", op, 32, 33, "0000", x"114");
      chk("bg  op" & integer'image(op) & " (33,64)   grid ", op, 33, 64, "0000", x"114");
    end loop;
    chk("bg  op15 fallback (33,33)", 15, 33, 33, "0000", x"002");
    -- ชั้นหน้าต้องยังอยู่
    chk("fg  title cyan line v=75      ", 0, 100, 75,  "0000", x"0FF");
    chk("fg  title magenta line v=76   ", 0, 100, 76,  "0000", x"F0F");
    chk("fg  title corner bracket      ", 0, 30, 20,   "0000", x"0FF");
    chk("fg  select sprite pixel (black)", 1, 300, 200, "0000", x"000");
    chk("fg  select sprite pixel (red)  ", 1, 300, 200, "0100", x"F00");
    chk("fg  camera white frame h=158  ", 2, 158, 200, "0000", x"FFF");
    -- ช่องโปร่งใสของสไปรต์ (magenta 0101) ต้องเห็นพื้นหลัง
    chk("bg  select transparent sprite px", 1, 300, 200, "0101", x"002");
    chk("bg  select transparent on grid  ", 1, 320, 200, "0101", x"114");
    wait;
  end process;
end sim;
