library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity npu_inference_tb is end;
architecture test of npu_inference_tb is
    signal clk : std_logic := '0';
    signal rst, start, done : std_logic := '0';
    signal a, b : std_logic_vector(7 downto 0) := (others => '0');
    signal result, bias : std_logic_vector(31 downto 0) := (others => '0');
    signal command : std_logic_vector(1 downto 0) := "00";
    signal shift : std_logic_vector(4 downto 0) := "00000";
    signal relu_en : std_logic := '0';
begin
    clk <= not clk after 5 ns;
    dut : entity work.npu_core port map(clk, rst, start, done, a, b,
        result, command, bias, shift, relu_en);
    process
        procedure issue(cmd, av, bv, seed, sh : integer; activation : std_logic; expected : integer) is
            variable completed : boolean := false;
        begin
            wait until falling_edge(clk);
            command <= std_logic_vector(to_unsigned(cmd, 2));
            a <= std_logic_vector(to_signed(av, 8));
            b <= std_logic_vector(to_signed(bv, 8));
            bias <= std_logic_vector(to_signed(seed, 32));
            shift <= std_logic_vector(to_unsigned(sh, 5)); relu_en <= activation;
            start <= '1';
            wait until rising_edge(clk); wait for 1 ns;
            start <= '0';
            for tick in 0 to 25 loop
                if done = '1' then completed := true; exit; end if;
                wait until rising_edge(clk); wait for 1 ns;
            end loop;
            assert completed report "NPU command timeout" severity failure;
            assert signed(result) = to_signed(expected, 32)
                report "NPU mismatch expected=" & integer'image(expected) &
                    " actual=" & integer'image(to_integer(signed(result))) severity failure;
            wait until rising_edge(clk); wait for 1 ns;
            assert done = '0' report "done must be a single-cycle pulse" severity failure;
        end procedure;
        variable av, bv, total : integer;
    begin
        rst <= '1'; wait for 22 ns; rst <= '0';
        issue(1, 0, 0, -20, 0, '0', -20);
        issue(2, -128, -128, 0, 0, '0', 16364);
        issue(2, 127, -128, 0, 0, '0', 108);
        issue(3, 0, 0, 0, 1, '0', 54);
        issue(1, 0, 0, -65, 0, '0', -65);
        issue(3, 0, 0, 0, 6, '0', -2);
        issue(3, 0, 0, 0, 6, '1', 0);
        issue(1, 0, 0, -1000, 0, '0', -1000);
        issue(3, 0, 0, 0, 0, '0', -128);
        issue(1, 0, 0, 2147483640, 0, '0', 2147483640);
        issue(2, 127, 127, 0, 0, '0', 2147483647);
        issue(3, 0, 0, 0, 0, '0', 127);
        issue(1, 0, 0, -2147483640, 0, '0', -2147483640);
        issue(2, -128, 127, 0, 0, '0', -2147483648);
        -- Independent integer accumulation over a deterministic signed sequence.
        issue(1, 0, 0, 7, 0, '0', 7); total := 7;
        for i in 0 to 255 loop
            av := i - 128; bv := ((i * 73 + 19) mod 256) - 128;
            total := total + av * bv;
            issue(2, av, bv, 0, 0, '0', total);
        end loop;
        rst <= '1'; wait for 12 ns; rst <= '0';
        issue(2, 3, 4, 0, 0, '0', 12);
        report "npu_inference_tb PASSED"; stop; wait;
    end process;
end;
