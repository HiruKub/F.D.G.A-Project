library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity color_analyzer is
    Port (
        clk             : in  STD_LOGIC;
        control          : in  STD_LOGIC_VECTOR(37 downto 0);
        h_pos           : in  integer range 0 to 639;
        v_pos           : in  integer range 0 to 479;
        in_cam_region   : in  STD_LOGIC;
        cam_pixel       : in  STD_LOGIC_VECTOR(11 downto 0);
        analysis_result : out STD_LOGIC_VECTOR(2 downto 0)
    );
end color_analyzer;

architecture Behavioral of color_analyzer is
    signal sum_r, sum_g, sum_b : unsigned(20 downto 0) := (others => '0');
    signal result_reg          : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal opcode              : std_logic_vector(3 downto 0);
begin
    opcode <= control(37 downto 34);

    process(clk)
        variable r_val, g_val, b_val : unsigned(3 downto 0);
        variable rank1_code          : STD_LOGIC_VECTOR(1 downto 0);
        variable rank2_val           : unsigned(20 downto 0);
        variable rank2_lsb           : STD_LOGIC;
    begin
        if rising_edge(clk) then
            -- 1. ?????????????????????????????????? (????????????)
            if h_pos = 0 and v_pos = 0 then
                sum_r <= (others => '0');
                sum_g <= (others => '0');
                sum_b <= (others => '0');

            -- 2. ?????????????????????????????????????? (???? Opcode "0010" Live ??? "0011" Freeze)
            elsif (opcode = "0010" or opcode = "0011") and in_cam_region = '1' then
                r_val := unsigned(cam_pixel(11 downto 8));
                g_val := unsigned(cam_pixel(7 downto 4));
                b_val := unsigned(cam_pixel(3 downto 0));

                sum_r <= sum_r + r_val;
                sum_g <= sum_g + g_val;
                sum_b <= sum_b + b_val;
            end if;

            -- 3. ?????????????? Latch ??????? Register ?????????????????? (??????????)
            if h_pos = 639 and v_pos = 479 then
                if sum_r >= sum_g and sum_r >= sum_b then
                    rank1_code := "00";
                    if sum_g >= sum_b then rank2_val := sum_g; else rank2_val := sum_b; end if;
                elsif sum_g >= sum_r and sum_g >= sum_b then
                    rank1_code := "01";
                    if sum_r >= sum_b then rank2_val := sum_r; else rank2_val := sum_b; end if;
                else
                    rank1_code := "10";
                    if sum_r >= sum_g then rank2_val := sum_r; else rank2_val := sum_g; end if;
                end if;

                rank2_lsb  := rank2_val(0);
                result_reg <= rank1_code & rank2_lsb;
            end if;
        end if;
    end process;

    analysis_result <= result_reg;
end Behavioral;