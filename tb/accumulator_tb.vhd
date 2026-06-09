library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity accumulator_tb is
end accumulator_tb;

architecture Behavior of accumulator_tb is

    component accumulator is
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            en       : in  std_logic;
            data_in  : in  std_logic_vector(15 downto 0);
            q        : out std_logic_vector(15 downto 0);
            sat_flag : out std_logic;
            neg_flag : out std_logic
        );
    end component;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal en       : std_logic := '0';
    signal data_in  : std_logic_vector(15 downto 0) := (others => '0');
    signal q        : std_logic_vector(15 downto 0);
    signal sat_flag : std_logic;
    signal neg_flag : std_logic;

begin

    clk <= not clk after 5 ns;

    dut : accumulator port map(
        clk      => clk,
        rst      => rst,
        en       => en,
        data_in  => data_in,
        q        => q,
        sat_flag => sat_flag,
        neg_flag => neg_flag
    );

    process
        procedure reset_acc is
        begin
            rst <= '1';
            wait for 20 ns;
            rst <= '0';
            wait for 10 ns;
        end procedure;

        procedure add_case(
            constant data_in_v : in std_logic_vector(15 downto 0);
            constant q_v       : in std_logic_vector(15 downto 0);
            constant sat_v     : in std_logic;
            constant neg_v     : in std_logic
        ) is
        begin
            data_in <= data_in_v;
            en      <= '1';
            wait until clk'event and clk = '1';
            wait for 1 ns;
            en      <= '0';

            assert q = q_v
                report "accumulator q mismatch"
                severity failure;
            assert sat_flag = sat_v
                report "accumulator sat_flag mismatch"
                severity failure;
            assert neg_flag = neg_v
                report "accumulator neg_flag mismatch"
                severity failure;

            wait until clk'event and clk = '1';
            wait for 1 ns;
        end procedure;
    begin
        reset_acc;
        add_case(x"000A", x"000A", '0', '0');
        add_case(x"FFF6", x"0000", '0', '0');

        reset_acc;
        add_case(x"7000", x"7000", '0', '0');
        add_case(x"7000", x"7FFF", '1', '0');

        reset_acc;
        add_case(x"9000", x"9000", '0', '1');
        add_case(x"9000", x"8001", '1', '1');

        report "accumulator_tb passed";
        stop;
        wait;
    end process;

end Behavior;
