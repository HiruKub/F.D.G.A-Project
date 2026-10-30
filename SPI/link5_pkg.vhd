library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package link5_pkg is
  constant FRAME_LEN   : natural := 5;
  constant LAST_OPCODE : natural := 13;      -- opcodes 0..13 (Title .. Loss)

  subtype byte_t is std_logic_vector(7 downto 0);
  type frame_t is array (0 to FRAME_LEN - 1) of byte_t;

  type fields_t is record
    opcode : std_logic_vector(3 downto 0);
    mon_p  : std_logic_vector(1 downto 0);
    lvl_p  : std_logic_vector(5 downto 0);
    hp_p   : std_logic_vector(7 downto 0);
    mon_e  : std_logic_vector(1 downto 0);
    lvl_e  : std_logic_vector(5 downto 0);
    hp_e   : std_logic_vector(7 downto 0);
    cursor : std_logic_vector(1 downto 0);
    pad    : std_logic_vector(1 downto 0);
  end record;

  function pack(f : fields_t) return frame_t;
  function unpack(fr : frame_t) return fields_t;
  -- test row n (0..12): walking-one / walking-zero patterns so every payload bit
  -- is seen as both 0 and 1 over one full cycle of rows
  -- function test_fields(n : natural) return fields_t;
  -- reply computed from the PREVIOUS opcode: 000 | op(1:0) | op(3:2) | parity(op)
  -- function status_byte(op : std_logic_vector(3 downto 0)) return byte_t;
end package;

package body link5_pkg is

  function pack(f : fields_t) return frame_t is
    variable v : std_logic_vector(39 downto 0);
    variable r : frame_t;
  begin
    v := f.opcode & f.mon_p & f.lvl_p & f.hp_p & f.mon_e & f.lvl_e & f.hp_e & f.cursor & f.pad;
    for i in 0 to FRAME_LEN - 1 loop
      r(i) := v(39 - 8 * i downto 32 - 8 * i);
    end loop;
    return r;
  end function;

  function unpack(fr : frame_t) return fields_t is
    variable v : std_logic_vector(39 downto 0);
    variable f : fields_t;
  begin
    for i in 0 to FRAME_LEN - 1 loop
      v(39 - 8 * i downto 32 - 8 * i) := fr(i);
    end loop;
    f.opcode := v(39 downto 36);
    f.mon_p  := v(35 downto 34);
    f.lvl_p  := v(33 downto 28);
    f.hp_p   := v(27 downto 20);
    f.mon_e  := v(19 downto 18);
    f.lvl_e  := v(17 downto 12);
    f.hp_e   := v(11 downto 4);
    f.cursor := v(3 downto 2);
    f.pad    := v(1 downto 0);
    return f;
  end function;

  -- function test_fields(n : natural) return fields_t is
  --   variable f : fields_t;
  -- begin
  --   f.opcode := std_logic_vector(to_unsigned(n, 4));
  --   f.mon_p  := std_logic_vector(to_unsigned(n mod 4, 2));
  --   f.mon_e  := std_logic_vector(to_unsigned((n + 1) mod 4, 2));
  --   f.cursor := std_logic_vector(to_unsigned((n + 2) mod 4, 2));
  --   f.lvl_p  := std_logic_vector(shift_left(to_unsigned(1, 6), n mod 6));
  --   f.hp_p   := std_logic_vector(shift_left(to_unsigned(1, 8), (n + 1) mod 8));
  --   f.lvl_e  := not std_logic_vector(shift_left(to_unsigned(1, 6), (n + 2) mod 6));
  --   f.hp_e   := not std_logic_vector(shift_left(to_unsigned(1, 8), (n + 3) mod 8));
  --   f.pad    := (others => '0');
  --   return f;
  -- end function;

  -- function status_byte(op : std_logic_vector(3 downto 0)) return byte_t is
  --   variable lv : std_logic;
  -- begin
  --   lv := op(3) xor op(2) xor op(1) xor op(0);
  --   return "000" & op(1 downto 0) & op(3 downto 2) & lv;
  -- end function;

end package body;
