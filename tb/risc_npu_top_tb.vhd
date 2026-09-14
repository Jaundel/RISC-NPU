library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity risc_npu_top_tb is
end entity;

architecture sim of risc_npu_top_tb is
    component risc_npu_top is
        port(
            CLOCK_50 : in  std_logic;
            KEY      : in  std_logic_vector(0 downto 0);
            LEDR     : out std_logic_vector(17 downto 0);
            LEDG     : out std_logic_vector(8 downto 0)
        );
    end component;

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(0 downto 0) := "0";
    signal ledr : std_logic_vector(17 downto 0);
    signal ledg : std_logic_vector(8 downto 0);
begin
    clk <= not clk after 5 ns;

    dut : risc_npu_top
        port map(
            CLOCK_50 => clk,
            KEY      => key,
            LEDR     => ledr,
            LEDG     => ledg
        );

    process
    begin
        key(0) <= '0';
        wait for 40 ns;
        key(0) <= '1';

        for i in 0 to 260 loop
            wait until rising_edge(clk);
            wait for 1 ns;

            if ledr(17) = '1' then
                assert ledr(15 downto 0) = x"09C4"
                    report "Top-level benchmark result wrong"
                    severity failure;
                report "risc_npu_top_tb passed";
                stop;
                wait;
            end if;
        end loop;

        assert false
            report "Top-level benchmark did not assert done"
            severity failure;
        wait;
    end process;
end architecture;
