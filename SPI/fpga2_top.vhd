-- ============================================================================
-- fpga2_top.vhd : top for the FPGA2 board (master)
--   GameLogic_FSM + link_master + button sync + power-on reset + cam_data_ready
--
-- Files needed: link5_pkg.vhd, spi_master.vhd, link_master.vhd,
--               GameLogic_FSM.vhd, fpga2_top.vhd     (top entity = fpga2_top)
--
-- NOT compiled / simulated (no VHDL tool available when written).
-- Pin names below are placeholders: map them in your .xdc / pin tab.
--
-- cam_data_ready: the link has no "scan done" bit, so the pulse is generated
-- here: after the game enters ST_CAM_CAPTURE (opcode 3) it waits for
-- CAPTURE_FRAMES good replies (10 -> ~105 ms) and then pulses 1 clk. rx_colour1
-- / rx_lv are held by link_master, so the game reads the last good reply.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fpga2_top is
  generic (
    BTN_ACTIVE_LOW : boolean  := false;   -- true if a pressed button reads '0'
    CAPTURE_FRAMES : positive := 10       -- good replies to wait in ST_CAM_CAPTURE
  );
  port (
    clk50     : in  std_logic;
    rst_btn   : in  std_logic;            -- same polarity as the buttons
    btn_up    : in  std_logic;
    btn_down  : in  std_logic;
    btn_left  : in  std_logic;
    btn_right : in  std_logic;
    btn_enter : in  std_logic;
    spi_sclk  : out std_logic;
    spi_mosi  : out std_logic;
    spi_cs_n  : out std_logic;
    spi_miso  : in  std_logic;
    led       : out std_logic_vector(7 downto 0)
    -- (no HP ports yet: every top-level port needs a pin in FPGA_Builder.
    --  Add hp_player / hp_player_max here when the 7-segment module exists.)
  );
end entity;

architecture rtl of fpga2_top is
  signal b_in, b_s1, b_s2 : std_logic_vector(5 downto 0) := (others => '0');
  signal por_cnt : unsigned(15 downto 0) := (others => '0');
  signal rst     : std_logic := '1';
  signal hb      : unsigned(25 downto 0) := (others => '0');

  signal state_code : std_logic_vector(3 downto 0);
  signal cursor     : std_logic_vector(1 downto 0);
  signal p_type, e_type : std_logic_vector(1 downto 0);
  signal p_lvl, e_lvl   : std_logic_vector(5 downto 0);
  signal p_hp, e_hp : std_logic_vector(7 downto 0);

  signal rx_colour1 : std_logic_vector(1 downto 0);
  signal rx_lv, rx_new, reply_ok : std_logic;
  signal enemy_type_g : std_logic_vector(1 downto 0);

  signal cam_ready : std_logic := '0';
  signal cap_cnt   : natural range 0 to CAPTURE_FRAMES := 0;
begin
  -- raw inputs, polarity fixed so that '1' = pressed
  b_in <= (rst_btn & btn_up & btn_down & btn_left & btn_right & btn_enter)
          when not BTN_ACTIVE_LOW else
          not (rst_btn & btn_up & btn_down & btn_left & btn_right & btn_enter);

  process (clk50)
  begin
    if rising_edge(clk50) then
      b_s1 <= b_in;
      b_s2 <= b_s1;                         -- 2-FF synchroniser

      if por_cnt /= x"FFFF" then
        por_cnt <= por_cnt + 1;
      end if;
      if por_cnt /= x"FFFF" or b_s2(5) = '1' then
        rst <= '1';
      else
        rst <= '0';
      end if;

      hb <= hb + 1;
    end if;
  end process;

  u_game : entity work.GameLogic_FSM
    port map (
      clk => clk50, reset => rst,
      btn_up_raw => b_s2(4), btn_down_raw => b_s2(3), btn_left_raw => b_s2(2),
      btn_right_raw => b_s2(1), btn_enter_raw => b_s2(0),
      enemy_type_in => enemy_type_g, enemy_lvl_lsb_in => rx_lv,
      state_code_out => state_code, cursor_out => cursor,
      player_type_out => p_type, player_lvl_out => p_lvl,
      player_hp_out => p_hp, player_max_hp_o => open,
      enemy_type_out => e_type, enemy_lvl_out => e_lvl,
      enemy_hp_out => e_hp, enemy_max_hp_o => open);

  -- colour 11 is not an element in the game rules: fall back to Fire (00)
  enemy_type_g <= rx_colour1 when rx_colour1 /= "11" else "00";

  u_link : entity work.link_master
    port map (
      clk => clk50,
      tx_opcode => state_code, tx_mon_p => p_type, tx_lvl_p => p_lvl, tx_hp_p => p_hp,
      tx_mon_e => e_type, tx_lvl_e => e_lvl, tx_hp_e => e_hp, tx_cursor => cursor,
      rx_colour1 => rx_colour1, rx_lv => rx_lv, rx_new => rx_new, reply_ok => reply_ok,
      frame_sent => open,
      spi_sclk => spi_sclk, spi_mosi => spi_mosi, spi_cs_n => spi_cs_n, spi_miso => spi_miso);

  -- cam_data_ready generator (fixed delay, counted in good replies)
  process (clk50)
  begin
    if rising_edge(clk50) then
      cam_ready <= '0';
      if state_code /= "0011" then
        cap_cnt <= 0;
      elsif rx_new = '1' then
        if cap_cnt = CAPTURE_FRAMES - 1 then
          cap_cnt   <= 0;
          cam_ready <= '1';
        else
          cap_cnt <= cap_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  led <= hb(25) & rx_colour1 & reply_ok & state_code;
end architecture;
