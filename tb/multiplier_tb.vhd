library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity multiplier_tb is
end multiplier_tb;

architecture Behavior of multiplier_tb is

    component multiplier is
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            start  : in  std_logic;
            a      : in  std_logic_vector(7 downto 0);
            b      : in  std_logic_vector(7 downto 0);
            done   : out std_logic;
            result : out std_logic_vector(15 downto 0)
        );
    end component;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '0';
    signal start  : std_logic := '0';
    signal a      : std_logic_vector(7 downto 0)  := (others => '0');
    signal b      : std_logic_vector(7 downto 0)  := (others => '0');
    signal done   : std_logic;
    signal result : std_logic_vector(15 downto 0);

begin

    clk <= not clk after 5 ns;

    dut : multiplier port map(
        clk    => clk,
        rst    => rst,
        start  => start,
        a      => a,
        b      => b,
        done   => done,
        result => result
    );

    process
        procedure run_case(
            constant a_in     : in std_logic_vector(7 downto 0);
            constant b_in     : in std_logic_vector(7 downto 0);
            constant expected : in std_logic_vector(15 downto 0)
        ) is
        begin
            a     <= a_in;
            b     <= b_in;
            start <= '1';
            wait until clk'event and clk = '1';
            wait for 1 ns;
            start <= '0';

            wait until done = '1';
            wait for 1 ns;
            assert result = expected
                report "multiplier result mismatch"
                severity failure;

            wait until clk'event and clk = '1';
            wait for 1 ns;
            assert done = '0'
                report "multiplier done must be a 1-cycle pulse"
                severity failure;
        end procedure;
    begin
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 10 ns;

        run_case(x"03", x"04", x"000C");
        run_case(x"FD", x"04", x"FFF4");
        run_case(x"FD", x"FE", x"0006");
        run_case(x"07", x"00", x"0000");

        report "multiplier_tb passed";
        stop;
        wait;
    end process;

end Behavior;
