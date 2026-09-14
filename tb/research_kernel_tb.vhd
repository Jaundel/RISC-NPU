library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

-- Identical entry/exit boundaries for every implementation. Inputs are written
-- by a common boot prefix; only runtime RAM values reach the kernel.
entity research_kernel_tb is
    generic(PROGRAM_FILE : string := "program.hex"; EXPECTED_FILE : string := "expected.hex";
        START_PC : natural := 0; OUTPUT_COUNT : positive := 1;
        CONFIG : natural := 0; MAX_CYCLES : positive := 1000000);
end;
architecture test of research_kernel_tb is
    type rom_t is array(0 to 65535) of std_logic_vector(31 downto 0);
    impure function read_rom return rom_t is
        file f : text open read_mode is PROGRAM_FILE;
        variable l : line;
        variable r : rom_t := (others => x"8000FFFF");
        variable i : natural := 0;
    begin
        while not endfile(f) loop readline(f,l); hread(l,r(i)); i:=i+1; end loop;
        return r;
    end;
    constant rom : rom_t := read_rom;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal instruction, pc, a, b, bus_data, address, ir : std_logic_vector(31 downto 0);
    signal c,z,wen,wm,em : std_logic;
    signal phase : std_logic_vector(2 downto 0);
begin
    clk <= not clk after 5 ns;
    instruction <= rom(to_integer(unsigned(address(15 downto 0)))) when not is_x(address) else (others=>'0');
    dut : entity work.cpu1 generic map(ENABLE_NPU=>CONFIG/=0,
        PARALLEL_MULTIPLIER=>CONFIG=3, FUSED_WIDE_RETIRE=>CONFIG/=1)
        port map(clk,clk,rst,instruction,bus_data,address,a,b,c,z,ir,pc,wen,phase,wm,em);
    process
        file expected : text open read_mode is EXPECTED_FILE;
        variable l : line;
        variable wanted : std_logic_vector(31 downto 0);
        variable active : boolean := false;
        variable measured : boolean := false;
        type outputs_t is array(0 to 7) of std_logic_vector(31 downto 0);
        variable saved : outputs_t;
        variable audits : natural := 0;
        variable total,kernel,fetch,memory_ops,npu_wait,npu_setup,scalar,retired,outputs : natural := 0;
        variable opcode : std_logic_vector(3 downto 0);
    begin
        wait for 30 ns; rst <= '0';
        for cycle in 1 to MAX_CYCLES loop
            wait until rising_edge(clk);
            if not measured then total := total+1; end if;
            if not measured and phase="001" and pc=std_logic_vector(to_unsigned(START_PC,32)) then active:=true; end if;
            if measured and phase="100" and ir(31 downto 28)=x"9" and unsigned(ir(7 downto 0))=240+audits then
                wait for 1 ns;
                assert a=saved(audits) report "RAM readback mismatch" severity failure;
                audits:=audits+1;
                if audits=OUTPUT_COUNT then report "RAM_READBACK_PASS"; stop; wait; end if;
            end if;
            if active and not measured then
                kernel:=kernel+1; opcode:=ir(31 downto 28);
                if phase="001" then fetch:=fetch+1;
                elsif opcode=x"9" or opcode=x"A" or opcode=x"2" or opcode=x"3" then memory_ops:=memory_ops+1;
                elsif phase="111" and (opcode=x"D" or opcode=x"B") then npu_wait:=npu_wait+1;
                elsif opcode=x"C" or opcode=x"E" then npu_setup:=npu_setup+1;
                else scalar:=scalar+1; end if;
                if phase="100" then
                    retired:=retired+1;
                    if opcode=x"2" and unsigned(ir(7 downto 0))=240+outputs then
                        readline(expected,l); hread(l,wanted);
                        -- The store committed on the preceding falling edge.
                        assert a=wanted report "output mismatch row=" & integer'image(outputs) &
                            " got=" & to_hstring(a) & " expected=" & to_hstring(wanted) severity failure;
                        assert wen='1' report "store not enabled" severity failure;
                        saved(outputs):=wanted;
                        outputs:=outputs+1;
                        if outputs=OUTPUT_COUNT then
                            assert endfile(expected) report "unused expected outputs" severity failure;
                            report "RESULT cycles=" & integer'image(kernel) & " cold=" & integer'image(total) &
                                " fetch=" & integer'image(fetch) & " memory=" & integer'image(memory_ops) &
                                " wait=" & integer'image(npu_wait) & " setup=" & integer'image(npu_setup) &
                                " scalar=" & integer'image(scalar) & " retired=" & integer'image(retired) &
                                " outputs=" & integer'image(outputs);
                            measured:=true;
                        end if;
                    end if;
                end if;
            end if;
        end loop;
        assert false report "kernel timed out" severity failure;
    end process;
end;
