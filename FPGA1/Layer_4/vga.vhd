library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VGA is
    Port(
        CLK25       : in std_logic;      -- รับ Clock 25MHz จาก top_level
        Hsync       : out std_logic;
        Vsync       : out std_logic;
        Nblank      : out std_logic;
        activeArea  : out std_logic
    );
end VGA;

architecture Behavioral of VGA is
    signal h_count  : integer := 0;
    signal v_count  : integer := 0;
    signal active_area_sig : std_logic := '0';
begin
    
    -- กระบวนการนับตำแหน่งพิกเซล (ทำงานบนขอบขาขึ้นของคล็อก 25MHz โดยตรง)
    proc_sync: process(CLK25)
    begin
        if rising_edge(CLK25) then
            if h_count = 799 then
                h_count <= 0;
                if v_count = 524 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;                
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;
    
    -- กำหนดพื้นที่แสดงผลภาพ (640x480)
    active_area_sig <= '1' when (h_count < 640) and (v_count < 480) else '0';
    activeArea      <= active_area_sig;
    
    -- สร้างสัญญาณ H-Sync และ V-Sync
    Hsync <= '0' when (h_count >= 656 and h_count <= 751) else '1';
    Vsync <= '0' when (v_count >= 490 and v_count <= 491) else '1'; 
    
    -- พอร์ตอื่นๆ ที่ top_level ต้องการ
    Nblank <= active_area_sig; -- สัญญาณดรอปสีจอ (ใช้งานร่วมกับ activeArea)

end Behavioral;