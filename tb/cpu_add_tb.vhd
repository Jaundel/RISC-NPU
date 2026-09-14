-- Minimal CPU test: LDIA 0, LDIB 50, ADD
-- Verifies that after one ADD the CPU latches A = 50.
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
library std;
use std.env.all;

entity cpu_add_tb is
end cpu_add_tb;

architecture sim of cpu_add_tb is

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

    -- 4-word ROM: LDIA 0, LDIB 50, ADD, NOP
    type rom_t is array(0 to 3) of std_logic_vector(31 downto 0);
    constant rom : rom_t := (
        0 => x"00000000",  -- LDIA 0
        1 => x"10000032",  -- LDIB 50
        2 => x"70000000",  -- ADD
        3 => x"00000000"   -- NOP (LDIA 0 spin)
    );

    signal clk      : std_logic := '0';
    signal mem_clk  : std_logic := '0';
    signal rst      : std_logic := '0';
    signal dataIn   : std_logic_vector(31 downto 0) := (others => '0');
    signal dataOut  : std_logic_vector(31 downto 0);
    signal addrOut  : std_logic_vector(31 downto 0);
    signal dOutA    : std_logic_vector(31 downto 0);
    signal dOutB    : std_logic_vector(31 downto 0);
    signal dOutC    : std_logic;
    signal dOutZ    : std_logic;
    signal dOutIR   : std_logic_vector(31 downto 0);
    signal dOutPC   : std_logic_vector(31 downto 0);
    signal wEn      : std_logic;
    signal outT     : std_logic_vector(2 downto 0);
    signal wen_mem  : std_logic;
    signal en_mem   : std_logic;

begin
    clk     <= not clk     after 5 ns;
    mem_clk <= not mem_clk after 5 ns;

    process(addrOut)
    begin
        dataIn <= rom(conv_integer(addrOut(1 downto 0)));
    end process;

    dut : cpu1 port map(
        clk => clk, mem_clk => mem_clk, rst => rst,
        dataIn => dataIn, dataOut => dataOut, addrOut => addrOut,
        dOutA => dOutA, dOutB => dOutB, dOutC => dOutC, dOutZ => dOutZ,
        dOutIR => dOutIR, dOutPC => dOutPC, wEn => wEn,
        outT => outT, wen_mem => wen_mem, en_mem => en_mem
    );

    process
        variable cycle : integer := 0;
        variable passed : boolean := false;
    begin
        rst <= '1';
        wait for 30 ns;
        rst <= '0';

        for i in 0 to 30 loop
            wait until clk'event and clk = '1';
            wait for 1 ns;
            cycle := i + 1;
            if not passed and dOutA = x"00000032" then
                report "STEP 3 PASS  single ADD: A=50 after " &
                       integer'image(cycle) & " cycles";
                passed := true;
            end if;

            if passed then exit; end if;
        end loop;

        assert passed
            report "STEP 3 FAIL  single ADD: A never reached 50 in 30 cycles"
            severity failure;

        stop;
        wait;
    end process;
end sim;
