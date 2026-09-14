library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
library std;
use std.env.all;

entity alu_tb is
end alu_tb;

architecture sim of alu_tb is
    component alu is
        port(
            a, b   : in  std_logic_vector(31 downto 0);
            op     : in  std_logic_vector(2 downto 0);
            result : out std_logic_vector(31 downto 0);
            zero   : out std_logic;
            cout   : out std_logic
        );
    end component;

    signal a, b   : std_logic_vector(31 downto 0) := (others => '0');
    signal op     : std_logic_vector(2 downto 0)  := "010";
    signal result : std_logic_vector(31 downto 0);
    signal zero_f : std_logic;
    signal cout_f : std_logic;
begin
    dut : alu port map(a, b, op, result, zero_f, cout_f);

    process
    begin
        -- ADD: 0 + 50 = 50
        a <= x"00000000"; b <= x"00000032"; op <= "010";
        wait for 10 ns;
        assert result = x"00000032"
            report "FAIL ADD 0+50: expected 50, got " & integer'image(conv_integer(result))
            severity failure;
        report "STEP 2a PASS  ADD  0+50 = 50";

        -- ADD: 50 + 50 = 100
        a <= x"00000032"; b <= x"00000032"; op <= "010";
        wait for 10 ns;
        assert result = x"00000064"
            report "FAIL ADD 50+50: expected 100, got " & integer'image(conv_integer(result))
            severity failure;
        report "STEP 2b PASS  ADD  50+50 = 100";

        -- ADD: 2450 + 50 = 2500  (final accumulation in benchmark)
        a <= x"00000992"; b <= x"00000032"; op <= "010";
        wait for 10 ns;
        assert result = x"000009C4"
            report "FAIL ADD 2450+50: expected 2500, got " & integer'image(conv_integer(result))
            severity failure;
        report "STEP 2c PASS  ADD  2450+50 = 2500";

        -- SUB: 100 - 50 = 50
        a <= x"00000064"; b <= x"00000032"; op <= "110";
        wait for 10 ns;
        assert result = x"00000032"
            report "FAIL SUB 100-50: expected 50, got " & integer'image(conv_integer(result))
            severity failure;
        report "STEP 2d PASS  SUB  100-50 = 50";

        report "==============================";
        report "alu_tb  PASSED";
        report "==============================";
        stop;
        wait;
    end process;
end sim;
