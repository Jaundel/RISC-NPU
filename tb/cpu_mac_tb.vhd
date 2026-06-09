library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library std;
use std.env.all;

entity cpu_mac_tb is
end cpu_mac_tb;

architecture Behavior of cpu_mac_tb is

    component cpu1 is
        port(
            clk      : in  std_logic;
            mem_clk  : in  std_logic;
            rst      : in  std_logic;
            dataIn   : in  std_logic_vector(31 downto 0);
            dataOut  : out std_logic_vector(31 downto 0);
            addrOut  : out std_logic_vector(31 downto 0);
            dOutA    : out std_logic_vector(31 downto 0);
            dOutB    : out std_logic_vector(31 downto 0);
            dOutC    : out std_logic;
            dOutZ    : out std_logic;
            dOutIR   : out std_logic_vector(31 downto 0);
            dOutPC   : out std_logic_vector(31 downto 0);
            wEn      : out std_logic;
            outT     : out std_logic_vector(2 downto 0);
            wen_mem  : out std_logic;
            en_mem   : out std_logic
        );
    end component;

    type rom_t is array (0 to 15) of std_logic_vector(31 downto 0);

    constant rom : rom_t := (
        0      => x"00000003", -- LDIA 3
        1      => x"10000004", -- LDIB 4
        2      => x"B0000000", -- MAC
        3      => x"00000000", -- LDIA 0, harmless next instruction
        others => x"00000000"
    );

    signal clk     : std_logic := '0';
    signal mem_clk : std_logic := '0';
    signal rst     : std_logic := '0';
    signal dataIn  : std_logic_vector(31 downto 0) := (others => '0');
    signal dataOut : std_logic_vector(31 downto 0);
    signal addrOut : std_logic_vector(31 downto 0);
    signal dOutA   : std_logic_vector(31 downto 0);
    signal dOutB   : std_logic_vector(31 downto 0);
    signal dOutC   : std_logic;
    signal dOutZ   : std_logic;
    signal dOutIR  : std_logic_vector(31 downto 0);
    signal dOutPC  : std_logic_vector(31 downto 0);
    signal wEn     : std_logic;
    signal outT    : std_logic_vector(2 downto 0);
    signal wen_mem : std_logic;
    signal en_mem  : std_logic;

begin

    clk     <= not clk after 5 ns;
    mem_clk <= not mem_clk after 5 ns;

    process(addrOut)
    begin
        case addrOut(3 downto 0) is
            when x"0"   => dataIn <= rom(0);
            when x"1"   => dataIn <= rom(1);
            when x"2"   => dataIn <= rom(2);
            when x"3"   => dataIn <= rom(3);
            when x"4"   => dataIn <= rom(4);
            when x"5"   => dataIn <= rom(5);
            when x"6"   => dataIn <= rom(6);
            when x"7"   => dataIn <= rom(7);
            when x"8"   => dataIn <= rom(8);
            when x"9"   => dataIn <= rom(9);
            when x"A"   => dataIn <= rom(10);
            when x"B"   => dataIn <= rom(11);
            when x"C"   => dataIn <= rom(12);
            when x"D"   => dataIn <= rom(13);
            when x"E"   => dataIn <= rom(14);
            when others => dataIn <= rom(15);
        end case;
    end process;

    dut : cpu1 port map(
        clk      => clk,
        mem_clk  => mem_clk,
        rst      => rst,
        dataIn   => dataIn,
        dataOut  => dataOut,
        addrOut  => addrOut,
        dOutA    => dOutA,
        dOutB    => dOutB,
        dOutC    => dOutC,
        dOutZ    => dOutZ,
        dOutIR   => dOutIR,
        dOutPC   => dOutPC,
        wEn      => wEn,
        outT     => outT,
        wen_mem  => wen_mem,
        en_mem   => en_mem
    );

    process
        variable mac_seen  : boolean := false;
        variable wait_seen : boolean := false;
        variable cycles    : integer := 0;
    begin
        rst <= '1';
        wait for 30 ns;
        rst <= '0';

        while cycles < 80 loop
            wait until clk'event and clk = '1';
            wait for 1 ns;

            if dOutIR(31 downto 28) = "1011" then
                mac_seen := true;
            end if;

            if outT = "111" then
                wait_seen := true;
            end if;

            if dOutA = x"0000000C" then
                assert dOutB = x"00000004"
                    report "CPU MAC test expected B to remain 4"
                    severity failure;
                assert mac_seen
                    report "CPU MAC test reached result before MAC instruction"
                    severity failure;
                assert wait_seen
                    report "CPU MAC test never entered MAC wait state"
                    severity failure;

                report "cpu_mac_tb passed";
                stop;
                wait;
            end if;

            cycles := cycles + 1;
        end loop;

        assert false
            report "CPU MAC test timed out before A became 0x0000000C"
            severity failure;
        wait;
    end process;

end Behavior;
