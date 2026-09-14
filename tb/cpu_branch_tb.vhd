library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity cpu_branch_tb is end;
architecture test of cpu_branch_tb is
    type rom_t is array(0 to 63) of std_logic_vector(31 downto 0);
    constant rom : rom_t := (
        0=>x"77000000", 1=>x"78000000", -- explicit clear flags
        2=>x"00000001", 3=>x"10000001", 4=>x"72000000", -- 1-1 => zero
        5=>x"00000009", 6=>x"7A000009", -- load must preserve Z; branch to 9
        7=>x"000000EE", 8=>x"8000003F", -- wrong branch sentinel
        9=>x"00000000", 10=>x"10000001", 11=>x"72000000", -- -1
        12=>x"70000000", -- FFFFFFFF+1 => carry
        13=>x"00000007", 14=>x"7C000011", -- preserve C; branch to 17
        15=>x"000000EE", 16=>x"8000003F",
        17=>x"78000000", 18=>x"7A00003F", -- untaken
        19=>x"77000000", 20=>x"7C00003F", -- untaken
        21=>x"0000002A", 22=>x"20000000", 23=>x"80000017",
        others=>x"8000003F");
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal instruction, pc, a, b, bus_data, address, ir : std_logic_vector(31 downto 0);
    signal c, z, wen, wm, em : std_logic;
    signal phase : std_logic_vector(2 downto 0);
begin
    clk <= not clk after 5 ns;
    instruction <= rom(to_integer(unsigned(address(5 downto 0)))) when not is_x(address) else (others=>'0');
    dut : entity work.cpu1 port map(clk, clk, rst, instruction, bus_data,
        address, a, b, c, z, ir, pc, wen, phase, wm, em);
    process
        variable completed : boolean := false;
    begin
        wait for 30 ns; rst <= '0';
        for cycle in 0 to 200 loop
            wait until rising_edge(clk); wait for 1 ns;
            assert pc /= x"0000003F" report "branch took wrong path" severity failure;
            if pc = x"00000017" then
                assert a = x"0000002A" report "branch result incorrect" severity failure;
                completed := true; exit;
            end if;
        end loop;
        assert completed report "branch program timed out" severity failure;
        report "cpu_branch_tb PASSED"; stop; wait;
    end process;
end;
