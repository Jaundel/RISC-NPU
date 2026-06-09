library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity relu_tb is
end relu_tb;

architecture Behavior of relu_tb is

    component relu is
        port(
            din  : in  std_logic_vector(15 downto 0);
            dout : out std_logic_vector(15 downto 0)
        );
    end component;

    signal din  : std_logic_vector(15 downto 0) := (others => '0');
    signal dout : std_logic_vector(15 downto 0);

begin

    dut : relu port map(
        din  => din,
        dout => dout
    );

    process
    begin
        din <= x"0005";
        wait for 1 ns;
        assert dout = x"0005"
            report "relu positive input mismatch"
            severity failure;

        din <= x"0000";
        wait for 1 ns;
        assert dout = x"0000"
            report "relu zero input mismatch"
            severity failure;

        din <= x"FFFF";
        wait for 1 ns;
        assert dout = x"0000"
            report "relu negative input mismatch"
            severity failure;

        din <= x"8000";
        wait for 1 ns;
        assert dout = x"0000"
            report "relu most-negative input mismatch"
            severity failure;

        report "relu_tb passed";
        stop;
        wait;
    end process;

end Behavior;
