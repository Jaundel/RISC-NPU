library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library std;
use std.env.all;

entity bench_tb is
end bench_tb;

architecture Behavior of bench_tb is

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

    -- 64-word ROM: benchmark program (matches system_memory.mif)
    type rom_t is array (0 to 63) of std_logic_vector(31 downto 0);
    constant rom : rom_t := (
         0 => x"00000000",  -- LDIA 0
         1 => x"10000032",  -- LDIB 50
         2 => x"70000000",  3 => x"70000000",  4 => x"70000000",
         5 => x"70000000",  6 => x"70000000",  7 => x"70000000",
         8 => x"70000000",  9 => x"70000000", 10 => x"70000000",
        11 => x"70000000", 12 => x"70000000", 13 => x"70000000",
        14 => x"70000000", 15 => x"70000000", 16 => x"70000000",
        17 => x"70000000", 18 => x"70000000", 19 => x"70000000",
        20 => x"70000000", 21 => x"70000000", 22 => x"70000000",
        23 => x"70000000", 24 => x"70000000", 25 => x"70000000",
        26 => x"70000000", 27 => x"70000000", 28 => x"70000000",
        29 => x"70000000", 30 => x"70000000", 31 => x"70000000",
        32 => x"70000000", 33 => x"70000000", 34 => x"70000000",
        35 => x"70000000", 36 => x"70000000", 37 => x"70000000",
        38 => x"70000000", 39 => x"70000000", 40 => x"70000000",
        41 => x"70000000", 42 => x"70000000", 43 => x"70000000",
        44 => x"70000000", 45 => x"70000000", 46 => x"70000000",
        47 => x"70000000", 48 => x"70000000", 49 => x"70000000",
        50 => x"70000000", 51 => x"70000000",  -- 50th ADD at addr 51
        52 => x"20000000",  -- STA 0x00
        53 => x"00000032",  -- LDIA 50
        54 => x"10000032",  -- LDIB 50
        55 => x"B0000000",  -- MAC
        56 => x"20000001",  -- STA 0x01
        others => x"00000000"
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
        variable idx : integer;
    begin
        idx := conv_integer(addrOut(5 downto 0));
        dataIn <= rom(idx);
    end process;

    dut : cpu1 port map(
        clk => clk, mem_clk => mem_clk, rst => rst,
        dataIn => dataIn, dataOut => dataOut, addrOut => addrOut,
        dOutA => dOutA, dOutB => dOutB, dOutC => dOutC, dOutZ => dOutZ,
        dOutIR => dOutIR, dOutPC => dOutPC, wEn => wEn,
        outT => outT, wen_mem => wen_mem, en_mem => en_mem
    );

    -- ============================================================
    -- Benchmark measurement process
    --   SW section : counts cycles until A = 2500 via ADD loop
    --   HW section : counts cycles the CPU stalls in MAC_WAIT
    -- ============================================================
    process
        variable cycle          : integer := 0;
        variable sw_start       : integer := 0;
        variable sw_end         : integer := 0;
        variable hw_start       : integer := 0;
        variable hw_end         : integer := 0;
        variable sw_done        : boolean := false;
        variable hw_done        : boolean := false;
        variable state3_entered : boolean := false;
        variable prev_T         : std_logic_vector(2 downto 0) := "000";
    begin
        rst <= '1';
        wait for 30 ns;
        rst <= '0';
        sw_start := 0;

        for i in 0 to 300 loop
            wait until clk'event and clk = '1';
            wait for 1 ns;
            cycle := i + 1;

            -- SW done: A reaches 2500 before the MAC instruction runs
            if not sw_done and not state3_entered
               and dOutA = x"000009C4" then
                sw_end  := cycle;
                sw_done := true;
                report "*** SW done  cycle=" & integer'image(sw_end) &
                       "  A=2500";
            end if;

            -- Detect MAC_WAIT entry
            if not state3_entered and outT = "111" then
                state3_entered := true;
                hw_start := cycle;
            end if;

            -- HW done: T leaves "111" (MAC_WAIT → state_0)
            if state3_entered and not hw_done
               and prev_T = "111" and outT /= "111" then
                hw_end  := cycle;
                hw_done := true;
                report "*** HW done  cycle=" & integer'image(hw_end) &
                       "  MAC_WAIT=" & integer'image(hw_end - hw_start) &
                       "  A=" & integer'image(conv_integer(dOutA));
                assert dOutA = x"000009C4"
                    report "HW result wrong: expected 2500, got " &
                           integer'image(conv_integer(dOutA))
                    severity failure;
            end if;

            prev_T := outT;
            if sw_done and hw_done then exit; end if;
        end loop;

        assert sw_done
            report "FAIL: SW ADD loop never reached A=2500"
            severity failure;
        assert hw_done
            report "FAIL: MAC never completed"
            severity failure;

        report "======================================";
        report "RISC-NPU BENCHMARK  50x50=2500";
        report "SW cycles:  " & integer'image(sw_end - sw_start);
        report "MAC_WAIT:   " & integer'image(hw_end - hw_start);
        report "Speedup:    " & integer'image((sw_end - sw_start) / (hw_end - hw_start)) & "x";
        report "======================================";
        report "bench_tb PASSED";
        stop;
        wait;
    end process;

end Behavior;
