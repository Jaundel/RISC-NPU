library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity accumulator is
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        data_in  : in  std_logic_vector(15 downto 0);
        q        : out std_logic_vector(15 downto 0);
        sat_flag : out std_logic;
        neg_flag : out std_logic
    );
end accumulator;

architecture Behavior of accumulator is

    signal q_reg        : std_logic_vector(15 downto 0) := (others => '0');
    signal sat_flag_reg : std_logic := '0';
    signal neg_flag_reg : std_logic := '0';

begin

    process(clk, rst)
        variable sum_v  : std_logic_vector(15 downto 0);
        variable next_q : std_logic_vector(15 downto 0);
        variable sat_v  : std_logic;
    begin
        if rst = '1' then
            q_reg        <= (others => '0');
            sat_flag_reg <= '0';
            neg_flag_reg <= '0';

        elsif clk'event and clk = '1' then
            if en = '1' then
                sum_v  := q_reg + data_in;
                next_q := sum_v;
                sat_v  := '0';

                if q_reg(15) = data_in(15) and sum_v(15) /= q_reg(15) then
                    sat_v := '1';

                    if q_reg(15) = '0' then
                        next_q := x"7FFF";
                    else
                        next_q := x"8001";
                    end if;
                end if;

                q_reg        <= next_q;
                sat_flag_reg <= sat_v;
                neg_flag_reg <= next_q(15);
            end if;
        end if;
    end process;

    q        <= q_reg;
    sat_flag <= sat_flag_reg;
    neg_flag <= neg_flag_reg;

end Behavior;
