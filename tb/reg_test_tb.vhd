library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity reg_test_tb is
end reg_test_tb;

architecture sim of reg_test_tb is
    component register32
        port(d : in std_logic_vector(31 downto 0);
             ld : in std_logic;
             clr : in std_logic;
             clk : in std_logic;
             Q : out std_logic_vector(31 downto 0));
    end component;

    signal clk : std_logic := '0';
    signal d   : std_logic_vector(31 downto 0) := (others => '0');
    signal ld  : std_logic := '0';
    signal clr : std_logic := '0';
    signal Q   : std_logic_vector(31 downto 0);
begin
    clk <= not clk after 5 ns;

    dut : register32 port map(d, ld, clr, clk, Q);

    process
    begin
        -- Mimic the CPU: ld goes high ONE FULL CYCLE before the latching edge
        -- Cycle 1: ld='0' (like state_1)
        wait until clk'event and clk = '1';  -- rising edge 1
        d  <= x"00000032";   -- 50
        ld <= '0';
        wait for 1 ns;
        report "After edge1: clk='1', ld='0', Q=" & integer'image(0);

        -- Cycle 2: ld='1' for full cycle (like state_2)
        wait until clk'event and clk = '1';  -- rising edge 2 (transitioning to state_2)
        -- At this edge, ld is still '0' - no latch expected
        wait for 1 ns;
        ld <= '1';  -- Set ld='1' AFTER the edge (mimics delta-cycle combinatorial)
        wait for 1 ns;
        report "After edge2 +2ns: ld='1', Q=" & integer'image(0);

        -- Cycle 3: rising edge should latch d (like state_2 -> state_0 transition)
        wait until clk'event and clk = '1';  -- rising edge 3
        -- At this edge, ld='1' (stable from 2ns after edge2)
        wait for 1 ns;
        report "After edge3: Q=" & integer'image(0);
        assert Q = x"00000032"
            report "FAIL: Q should be 50, ld was '1' for full cycle before edge3"
            severity failure;
        report "PASS: register32 latches correctly when ld held for full cycle";

        stop;
        wait;
    end process;
end sim;
