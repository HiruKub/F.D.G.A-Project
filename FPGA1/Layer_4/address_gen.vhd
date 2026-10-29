library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity address_gen is
    Port (
        CLK25         : in  STD_LOGIC;
        control       : in  STD_LOGIC_VECTOR(37 downto 0); -- [?????] ???????? control ????????? opcode
        enable        : in  STD_LOGIC;
        vsync         : in  STD_LOGIC;
        addr          : out STD_LOGIC_VECTOR(14 downto 0);
        in_cam_region : out STD_LOGIC;                     
        h_cnt_out     : out integer range 0 to 639;        
        v_cnt_out     : out integer range 0 to 479         
    );
end address_gen;

architecture Behavioral of address_gen is
    signal h_cnt  : integer range 0 to 639 := 0;
    signal v_cnt  : integer range 0 to 479 := 0;
    signal opcode : std_logic_vector(3 downto 0);
begin

    opcode <= control(37 downto 34);

    -- Process ??????????? VGA (640x480)
    process(CLK25)
    begin
        if rising_edge(CLK25) then
            if vsync = '0' then
                h_cnt <= 0;
                v_cnt <= 0;
            elsif enable = '1' then
                if h_cnt = 639 then
                    h_cnt <= 0;
                    if v_cnt = 479 then
                        v_cnt <= 0;
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    h_cnt_out <= h_cnt;
    v_cnt_out <= v_cnt;

    -- Process ????? Address ???? RAM ?????? Opcode
    process(h_cnt, v_cnt, opcode)
        variable x_scaled : integer;
        variable y_scaled : integer;
        variable rel_x    : integer;
        variable rel_y    : integer;
    begin
        in_cam_region <= '0';
        addr          <= (others => '0');

        -- 1. ???????????? (Opcode "0010" Live / "0011" Freeze)
        if opcode = "0010" or opcode = "0011" then
            if (h_cnt >= 160 and h_cnt < 480) and (v_cnt >= 120 and v_cnt < 360) then
                in_cam_region <= '1';
                x_scaled := (h_cnt - 160) / 2; -- ????? 0 ??? 159
                y_scaled := (v_cnt - 120) / 2; -- ????? 0 ??? 119
                addr     <= std_logic_vector(to_unsigned((y_scaled * 160) + x_scaled, 15));
            end if;

        -- 2. ??? Battle (Opcode "0100" ??????) ???????????????????????????? (X: 520..583, Y: 360..423)
        elsif unsigned(opcode) >= 4 then
            if (h_cnt >= 520 and h_cnt < 584) and (v_cnt >= 360 and v_cnt < 424) then
                rel_x    := h_cnt - 520; -- ???????????????????? 0 ??? 63
                rel_y    := v_cnt - 360; -- ???????????????????? 0 ??? 63
                
                -- ????????????? 160x120 ???????????? 64x64
                x_scaled := (rel_x * 160) / 64; -- ??????????? X
                y_scaled := (rel_y * 120) / 64; -- ??????????? Y
                
                addr     <= std_logic_vector(to_unsigned((y_scaled * 160) + x_scaled, 15));
            end if;
        end if;
    end process;

end Behavioral;