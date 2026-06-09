library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library std;
use std.env.all;

entity bench_multi_tb is
end bench_multi_tb;

architecture Behavior of bench_multi_tb is

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

    -- 128-word ROM (7-bit addr) — large enough for N=100 (max addr 106)
    type rom128_t is array(0 to 127) of std_logic_vector(31 downto 0);

    -- Opcode reference: LDIA=0x0..., LDIB=0x1..., STA=0x2...,
    --                   ADD=0x70000000, MAC=0xB0000000

    -- N=10: LDIA 0, LDIB 10, ADD×10, STA 0, LDIA 10, LDIB 10, MAC, STA 1
    --       SW target A = 10×10 = 100 = 0x64
    constant rom10 : rom128_t := (
         0 => x"00000000",   -- LDIA 0
         1 => x"1000000A",   -- LDIB 10
         2 => x"70000000",  3 => x"70000000",  4 => x"70000000",
         5 => x"70000000",  6 => x"70000000",  7 => x"70000000",
         8 => x"70000000",  9 => x"70000000", 10 => x"70000000",
        11 => x"70000000",                          -- ADD × 10 (addr 2..11)
        12 => x"20000000",  -- STA 0
        13 => x"0000000A",  -- LDIA 10
        14 => x"1000000A",  -- LDIB 10
        15 => x"B0000000",  -- MAC
        16 => x"20000001",  -- STA 1
        others => x"00000000"
    );

    -- N=25: LDIA 0, LDIB 25, ADD×25, STA 0, LDIA 25, LDIB 25, MAC, STA 1
    --       SW target A = 25×25 = 625 = 0x271
    constant rom25 : rom128_t := (
         0 => x"00000000",   -- LDIA 0
         1 => x"10000019",   -- LDIB 25
         2 => x"70000000",  3 => x"70000000",  4 => x"70000000",
         5 => x"70000000",  6 => x"70000000",  7 => x"70000000",
         8 => x"70000000",  9 => x"70000000", 10 => x"70000000",
        11 => x"70000000", 12 => x"70000000", 13 => x"70000000",
        14 => x"70000000", 15 => x"70000000", 16 => x"70000000",
        17 => x"70000000", 18 => x"70000000", 19 => x"70000000",
        20 => x"70000000", 21 => x"70000000", 22 => x"70000000",
        23 => x"70000000", 24 => x"70000000", 25 => x"70000000",
        26 => x"70000000",                          -- ADD × 25 (addr 2..26)
        27 => x"20000000",  -- STA 0
        28 => x"00000019",  -- LDIA 25
        29 => x"10000019",  -- LDIB 25
        30 => x"B0000000",  -- MAC
        31 => x"20000001",  -- STA 1
        others => x"00000000"
    );

    -- N=50: matches system_memory.mif / bench_tb.vhd
    --       SW target A = 50×50 = 2500 = 0x9C4
    constant rom50 : rom128_t := (
         0 => x"00000000",   -- LDIA 0
         1 => x"10000032",   -- LDIB 50
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
        50 => x"70000000", 51 => x"70000000",       -- ADD × 50 (addr 2..51)
        52 => x"20000000",  -- STA 0
        53 => x"00000032",  -- LDIA 50
        54 => x"10000032",  -- LDIB 50
        55 => x"B0000000",  -- MAC
        56 => x"20000001",  -- STA 1
        others => x"00000000"
    );

    -- N=100: LDIA 0, LDIB 100, ADD×100, STA 0, LDIA 100, LDIB 100, MAC, STA 1
    --        SW target A = 100×100 = 10000 = 0x2710
    constant rom100 : rom128_t := (
          0 => x"00000000",   -- LDIA 0
          1 => x"10000064",   -- LDIB 100
          2 => x"70000000",   3 => x"70000000",   4 => x"70000000",
          5 => x"70000000",   6 => x"70000000",   7 => x"70000000",
          8 => x"70000000",   9 => x"70000000",  10 => x"70000000",
         11 => x"70000000",  12 => x"70000000",  13 => x"70000000",
         14 => x"70000000",  15 => x"70000000",  16 => x"70000000",
         17 => x"70000000",  18 => x"70000000",  19 => x"70000000",
         20 => x"70000000",  21 => x"70000000",  22 => x"70000000",
         23 => x"70000000",  24 => x"70000000",  25 => x"70000000",
         26 => x"70000000",  27 => x"70000000",  28 => x"70000000",
         29 => x"70000000",  30 => x"70000000",  31 => x"70000000",
         32 => x"70000000",  33 => x"70000000",  34 => x"70000000",
         35 => x"70000000",  36 => x"70000000",  37 => x"70000000",
         38 => x"70000000",  39 => x"70000000",  40 => x"70000000",
         41 => x"70000000",  42 => x"70000000",  43 => x"70000000",
         44 => x"70000000",  45 => x"70000000",  46 => x"70000000",
         47 => x"70000000",  48 => x"70000000",  49 => x"70000000",
         50 => x"70000000",  51 => x"70000000",  52 => x"70000000",
         53 => x"70000000",  54 => x"70000000",  55 => x"70000000",
         56 => x"70000000",  57 => x"70000000",  58 => x"70000000",
         59 => x"70000000",  60 => x"70000000",  61 => x"70000000",
         62 => x"70000000",  63 => x"70000000",  64 => x"70000000",
         65 => x"70000000",  66 => x"70000000",  67 => x"70000000",
         68 => x"70000000",  69 => x"70000000",  70 => x"70000000",
         71 => x"70000000",  72 => x"70000000",  73 => x"70000000",
         74 => x"70000000",  75 => x"70000000",  76 => x"70000000",
         77 => x"70000000",  78 => x"70000000",  79 => x"70000000",
         80 => x"70000000",  81 => x"70000000",  82 => x"70000000",
         83 => x"70000000",  84 => x"70000000",  85 => x"70000000",
         86 => x"70000000",  87 => x"70000000",  88 => x"70000000",
         89 => x"70000000",  90 => x"70000000",  91 => x"70000000",
         92 => x"70000000",  93 => x"70000000",  94 => x"70000000",
         95 => x"70000000",  96 => x"70000000",  97 => x"70000000",
         98 => x"70000000",  99 => x"70000000", 100 => x"70000000",
        101 => x"70000000",                          -- ADD × 100 (addr 2..101)
        102 => x"20000000",  -- STA 0
        103 => x"00000064",  -- LDIA 100
        104 => x"10000064",  -- LDIB 100
        105 => x"B0000000",  -- MAC
        106 => x"20000001",  -- STA 1
        others => x"00000000"
    );

    signal clk        : std_logic := '0';
    signal mem_clk    : std_logic := '0';
    signal rst        : std_logic := '0';
    signal dataIn     : std_logic_vector(31 downto 0) := (others => '0');
    signal dataOut    : std_logic_vector(31 downto 0);
    signal addrOut    : std_logic_vector(31 downto 0);
    signal dOutA      : std_logic_vector(31 downto 0);
    signal dOutB      : std_logic_vector(31 downto 0);
    signal dOutC      : std_logic;
    signal dOutZ      : std_logic;
    signal dOutIR     : std_logic_vector(31 downto 0);
    signal dOutPC     : std_logic_vector(31 downto 0);
    signal wEn        : std_logic;
    signal outT       : std_logic_vector(2 downto 0);
    signal wen_mem    : std_logic;
    signal en_mem     : std_logic;
    signal active_rom : integer range 0 to 3 := 0;

begin

    clk     <= not clk     after 5 ns;
    mem_clk <= not mem_clk after 5 ns;

    -- ROM mux — 7-bit address covers N=100 (max addr 106 < 128)
    process(addrOut, active_rom)
        variable idx : integer;
    begin
        idx := conv_integer(addrOut(6 downto 0));
        case active_rom is
            when 0      => dataIn <= rom10(idx);
            when 1      => dataIn <= rom25(idx);
            when 2      => dataIn <= rom50(idx);
            when others => dataIn <= rom100(idx);
        end case;
    end process;

    dut : cpu1 port map(
        clk => clk, mem_clk => mem_clk, rst => rst,
        dataIn => dataIn, dataOut => dataOut, addrOut => addrOut,
        dOutA => dOutA, dOutB => dOutB, dOutC => dOutC, dOutZ => dOutZ,
        dOutIR => dOutIR, dOutPC => dOutPC, wEn => wEn,
        outT => outT, wen_mem => wen_mem, en_mem => en_mem
    );

    process
        variable cycle          : integer;
        variable sw_end         : integer;
        variable hw_start       : integer;
        variable hw_end         : integer;
        variable sw_done        : boolean;
        variable hw_done        : boolean;
        variable state3_entered : boolean;
        variable prev_T         : std_logic_vector(2 downto 0);

        type sw_targets_t is array(0 to 3) of std_logic_vector(31 downto 0);
        type n_values_t   is array(0 to 3) of integer;
        constant sw_targets : sw_targets_t := (
            x"00000064",  -- 10×10 = 100
            x"00000271",  -- 25×25 = 625
            x"000009C4",  -- 50×50 = 2500
            x"00002710"   -- 100×100 = 10000
        );
        constant n_values : n_values_t := (10, 25, 50, 100);
    begin
        report "======================================";
        report "RISC-NPU MULTI-SIZE BENCHMARK";
        report "N = 10 / 25 / 50 / 100";
        report "======================================";

        for test in 0 to 3 loop
            active_rom <= test;
            wait for 10 ns;     -- let ROM mux settle
            rst <= '1';
            wait for 30 ns;
            rst <= '0';

            cycle          := 0;
            sw_end         := 0;
            hw_start       := 0;
            hw_end         := 0;
            sw_done        := false;
            hw_done        := false;
            state3_entered := false;
            prev_T         := "000";

            for i in 0 to 400 loop
                wait until clk'event and clk = '1';
                wait for 1 ns;
                cycle := i + 1;

                if not sw_done and not state3_entered
                   and dOutA = sw_targets(test) then
                    sw_end  := cycle;
                    sw_done := true;
                end if;

                if not state3_entered and outT = "111" then
                    state3_entered := true;
                    hw_start := cycle;
                end if;

                if state3_entered and not hw_done
                   and prev_T = "111" and outT /= "111" then
                    hw_end  := cycle;
                    hw_done := true;
                end if;

                prev_T := outT;
                if sw_done and hw_done then exit; end if;
            end loop;

            assert sw_done
                report "FAIL N=" & integer'image(n_values(test)) &
                       ": SW loop never completed"
                severity failure;
            assert hw_done
                report "FAIL N=" & integer'image(n_values(test)) &
                       ": MAC never completed"
                severity failure;

            report "N=" & integer'image(n_values(test)) &
                   "  SW_cycles=" & integer'image(sw_end) &
                   "  MAC_WAIT=" & integer'image(hw_end - hw_start) &
                   "  Speedup=" & integer'image(sw_end / (hw_end - hw_start)) & "x";
        end loop;

        report "======================================";
        report "bench_multi_tb PASSED";
        report "======================================";
        stop;
        wait;
    end process;

end Behavior;
