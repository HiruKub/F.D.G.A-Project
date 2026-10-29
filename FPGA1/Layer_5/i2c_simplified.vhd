library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_simplified is
    port (
        clk                 : in  std_logic;
        instruction_address : out integer range 0 to 54;
        instruction_data    : in  std_logic_vector(15 downto 0);
        i2c_scl             : out std_logic;
        i2c_sda             : inout std_logic
    );
end i2c_simplified;

architecture Behavioral of i2c_simplified is

    constant clk_div        : integer range 0 to 250 := 62; -- SCL ~400kHz @ 25MHz
    constant poweron_exp    : integer range 0 to 4   := 4;
    constant soft_reset_exp : integer range 0 to 9   := 9;

    constant poweron_max    : integer range 0 to 4_000   := (2 ** poweron_exp) * clk_div;
    constant soft_reset_max : integer range 0 to 128_000 := (2 ** soft_reset_exp) * clk_div;

    constant q1             : integer := clk_div / 4;
    constant q2             : integer := (clk_div * 2) / 4;
    constant q3             : integer := (clk_div * 3) / 4;
    constant q4             : integer := clk_div - 1;

    constant DEV_ID         : STD_LOGIC_VECTOR(7 downto 0) := x"42";

    type state_type is (
        ST_POWERON_DELAY, ST_START, ST_SEND_DEV_ID, ST_SEND_REG,
        ST_SEND_DATA, ST_STOP, ST_RESET_DELAY, ST_NEXT, ST_DONE
    );

    signal state     : state_type := ST_POWERON_DELAY;
    signal timer_cnt : integer range 0 to soft_reset_max := 0; 
    signal inst_ptr  : integer range 0 to 54 := 0;
    signal bit_idx   : integer range 0 to 8 := 8;

begin
    process (clk)
    begin
        if rising_edge(clk) then
            case state is
                when ST_POWERON_DELAY =>
                    if timer_cnt < poweron_max - 1 then
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        state <= ST_START;
                    end if;

                when ST_START =>
                    if timer_cnt < q1 then
                        i2c_scl <= '1';
                        i2c_sda <= 'Z';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q2 then
                        i2c_scl <= '1';
                        i2c_sda <= '0';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q4 then
                        i2c_scl <= '0';
                        i2c_sda <= '0';
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        bit_idx <= 8;
                        instruction_address <= inst_ptr;
                        state <= ST_SEND_DEV_ID;
                    end if;

                when ST_SEND_DEV_ID =>
                    if timer_cnt < q1 then
                        i2c_scl <= '0';
                        if bit_idx > 0 then
                            i2c_sda <= DEV_ID(bit_idx - 1);
                        else
                            i2c_sda <= 'Z';
                        end if;
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q3 then
                        i2c_scl   <= '1';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q4 then
                        i2c_scl   <= '0';
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        if bit_idx > 0 then
                            bit_idx <= bit_idx - 1;
                        else
                            bit_idx <= 8;
                            state   <= ST_SEND_REG;
                        end if;
                    end if;

                when ST_SEND_REG =>
                    if timer_cnt < q1 then
                        i2c_scl <= '0';
                        if bit_idx > 0 then
                            i2c_sda <= instruction_data((bit_idx - 1) + 8);
                        else
                            i2c_sda <= 'Z';
                        end if;
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q3 then
                        i2c_scl   <= '1';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q4 then
                        i2c_scl   <= '0';
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        if bit_idx > 0 then
                            bit_idx <= bit_idx - 1;
                        else
                            bit_idx <= 8;
                            state   <= ST_SEND_DATA;
                        end if;
                    end if;

                when ST_SEND_DATA =>
                    if timer_cnt < q1 then
                        i2c_scl <= '0';
                        if bit_idx > 0 then
                            i2c_sda <= instruction_data(bit_idx - 1);
                        else
                            i2c_sda <= 'Z';
                        end if;
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q3 then
                        i2c_scl   <= '1';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q4 then
                        i2c_scl   <= '0';
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        if bit_idx > 0 then
                            bit_idx <= bit_idx - 1;
                        else
                            bit_idx <= 8;
                            state   <= ST_STOP;
                        end if;
                    end if;

                when ST_STOP =>
                    if timer_cnt < q1 then
                        i2c_scl <= '0';
                        i2c_sda <= '0';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q2 then
                        i2c_scl <= '1';
                        i2c_sda <= '0';
                        timer_cnt <= timer_cnt + 1;
                    elsif timer_cnt < q4 then
                        i2c_scl <= '1';
                        i2c_sda <= 'Z';
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        if inst_ptr = 0 then
                            state <= ST_RESET_DELAY;
                        else
                            state <= ST_NEXT;
                        end if;
                    end if;

                when ST_RESET_DELAY =>
                    if timer_cnt < soft_reset_max - 1 then
                        timer_cnt <= timer_cnt + 1;
                    else
                        timer_cnt <= 0;
                        state <= ST_NEXT;
                    end if;

                when ST_NEXT =>
                    if inst_ptr < 54 then
                        inst_ptr <= inst_ptr + 1;
                        state    <= ST_START;
                    else
                        state    <= ST_DONE;
                    end if;

                when ST_DONE => null;

                when others =>
                    timer_cnt <= 0;
                    state     <= ST_DONE;
            end case;
        end if;
    end process;

end Behavioral;