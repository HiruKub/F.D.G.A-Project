library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity color_analyzer is
    Port (
        clk             : in  STD_LOGIC;
        control         : in  STD_LOGIC_VECTOR(37 downto 0);
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
begin

    process(clk)
        variable r_val, g_val, b_val       : unsigned(3 downto 0);
        variable v_sum_r, v_sum_g, v_sum_b : unsigned(20 downto 0); -- Variable คำนวณยอดรวมชั่วคราว
        variable rank1_code                : STD_LOGIC_VECTOR(1 downto 0);
        variable rank2_val                 : unsigned(20 downto 0);
        variable rank2_lsb                 : STD_LOGIC;
    begin
        if rising_edge(clk) then
            -- 1. รีเซ็ตเฉพาะตัวนับสะสมเมื่อเริ่มเฟรมใหม่ (ห้ามรีเซ็ต result_reg เพื่อให้ค้างค่าเฟรมเก่าไว้)
            if h_pos = 0 and v_pos = 0 then
                sum_r <= (others => '0');
                sum_g <= (others => '0');
                sum_b <= (others => '0');

            -- 2. เมื่ออยู่ในพื้นที่กล้อง ให้บวกค่า และเปรียบเทียบแปลผลส่งเข้า result_reg ทันทีทุกพิกเซล
            elsif in_cam_region = '1' then
                r_val := unsigned(cam_pixel(11 downto 8));
                g_val := unsigned(cam_pixel(7 downto 4));
                b_val := unsigned(cam_pixel(3 downto 0));

                -- บวกค่าเก็บเข้า Variable เพื่อให้นำไปเปรียบเทียบใน Clock นี้ได้ทันที
                v_sum_r := sum_r + r_val;
                v_sum_g := sum_g + g_val;
                v_sum_b := sum_b + b_val;

                -- อัปเดต Signal สะสมไว้ใช้ใน Clock ถัดไป
                sum_r <= v_sum_r;
                sum_g <= v_sum_g;
                sum_b <= v_sum_b;

                -- เปรียบเทียบและหาอันดับสีทันทีแบบ Real-time
                if v_sum_r >= v_sum_g and v_sum_r >= v_sum_b then
                    rank1_code := "00";
                    if v_sum_g >= v_sum_b then rank2_val := v_sum_g; else rank2_val := v_sum_b; end if;
                elsif v_sum_g >= v_sum_r and v_sum_g >= v_sum_b then
                    rank1_code := "01";
                    if v_sum_r >= v_sum_b then rank2_val := v_sum_r; else rank2_val := v_sum_b; end if;
                else
                    rank1_code := "10";
                    if v_sum_r >= v_sum_g then rank2_val := v_sum_r; else rank2_val := v_sum_g; end if;
                end if;

                rank2_lsb  := rank2_val(0);
                
                -- อัปเดตค่าผลลัพธ์ทันที
                result_reg <= rank1_code & rank2_lsb;
            end if;
        end if;
    end process;

    analysis_result <= result_reg;
end Behavioral;