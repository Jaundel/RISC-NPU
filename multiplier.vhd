library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity multiplier is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        start  : in  std_logic;
        a      : in  std_logic_vector(7 downto 0);
        b      : in  std_logic_vector(7 downto 0);
        done   : out std_logic;
        result : out std_logic_vector(15 downto 0)
    );
end multiplier;

architecture Behavior of multiplier is

    signal a_reg      : std_logic_vector(15 downto 0) := (others => '0');
    signal b_reg      : std_logic_vector(7 downto 0)  := (others => '0');
    signal acc_reg    : std_logic_vector(15 downto 0) := (others => '0');
    signal result_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal count      : std_logic_vector(3 downto 0)  := (others => '0');
    signal busy       : std_logic := '0';
    signal neg_result : std_logic := '0';
    signal done_s     : std_logic := '0';

begin

    process(clk, rst)
        variable a_abs  : std_logic_vector(7 downto 0);
        variable b_abs  : std_logic_vector(7 downto 0);
        variable acc_v  : std_logic_vector(15 downto 0);
        variable prod_v : std_logic_vector(15 downto 0);
    begin
        if rst = '1' then
            a_reg      <= (others => '0');
            b_reg      <= (others => '0');
            acc_reg    <= (others => '0');
            result_reg <= (others => '0');
            count      <= (others => '0');
            busy       <= '0';
            neg_result <= '0';
            done_s     <= '0';

        elsif clk'event and clk = '1' then
            done_s <= '0';

            if busy = '0' then
                if start = '1' then
                    if a(7) = '1' then
                        a_abs := (not a) + 1;
                    else
                        a_abs := a;
                    end if;

                    if b(7) = '1' then
                        b_abs := (not b) + 1;
                    else
                        b_abs := b;
                    end if;

                    a_reg      <= "00000000" & a_abs;
                    b_reg      <= b_abs;
                    acc_reg    <= (others => '0');
                    count      <= (others => '0');
                    neg_result <= a(7) xor b(7);
                    busy       <= '1';
                end if;

            else
                acc_v := acc_reg;

                if b_reg(0) = '1' then
                    acc_v := acc_reg + a_reg;
                end if;

                acc_reg <= acc_v;
                a_reg   <= a_reg(14 downto 0) & '0';
                b_reg   <= '0' & b_reg(7 downto 1);

                if count = "0111" then
                    prod_v := acc_v;

                    if neg_result = '1' then
                        prod_v := (not acc_v) + 1;
                    end if;

                    result_reg <= prod_v;
                    done_s     <= '1';
                    busy       <= '0';
                    count      <= (others => '0');
                else
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;

    done   <= done_s;
    result <= result_reg;

end Behavior;
