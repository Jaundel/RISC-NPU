library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity npu_core_tb is
end npu_core_tb;

architecture Behavior of npu_core_tb is

    component npu_core is
        port(
            clk        : in  std_logic;
            rst        : in  std_logic;
            npu_start  : in  std_logic;
            npu_done   : out std_logic;
            op_a       : in  std_logic_vector(7 downto 0);
            op_b       : in  std_logic_vector(7 downto 0);
            npu_result : out std_logic_vector(31 downto 0)
        );
    end component;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '0';
    signal npu_start  : std_logic := '0';
    signal npu_done   : std_logic;
    signal op_a       : std_logic_vector(7 downto 0) := (others => '0');
    signal op_b       : std_logic_vector(7 downto 0) := (others => '0');
    signal npu_result : std_logic_vector(31 downto 0);

begin

    clk <= not clk after 5 ns;

    dut : npu_core port map(
        clk        => clk,
        rst        => rst,
        npu_start  => npu_start,
        npu_done   => npu_done,
        op_a       => op_a,
        op_b       => op_b,
        npu_result => npu_result
    );

    process
        procedure run_mac(
            constant op_a_v   : in std_logic_vector(7 downto 0);
            constant op_b_v   : in std_logic_vector(7 downto 0);
            constant result_v : in std_logic_vector(31 downto 0)
        ) is
            variable cycles : integer;
        begin
            op_a      <= op_a_v;
            op_b      <= op_b_v;
            npu_start <= '1';
            wait until clk'event and clk = '1';
            wait for 1 ns;
            npu_start <= '0';

            cycles := 0;
            while npu_done /= '1' loop
                wait until clk'event and clk = '1';
                wait for 1 ns;
                cycles := cycles + 1;
                assert cycles < 32
                    report "npu_core timed out waiting for npu_done"
                    severity failure;
            end loop;

            assert npu_result = result_v
                report "npu_core result mismatch"
                severity failure;

            wait until clk'event and clk = '1';
            wait for 1 ns;
            assert npu_done = '0'
                report "npu_core done must be a 1-cycle pulse"
                severity failure;
        end procedure;
    begin
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 10 ns;

        run_mac(x"03", x"04", x"0000000C");
        run_mac(x"02", x"05", x"00000016");

        report "npu_core_tb passed";
        stop;
        wait;
    end process;

end Behavior;
