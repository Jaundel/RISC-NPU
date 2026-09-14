library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
entity research_arithmetic_tb is generic(RESULTS_FILE : string := "quantization.csv"); end;
architecture test of research_arithmetic_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';
    signal cmd : std_logic_vector(1 downto 0) := "01";
    signal a,b : std_logic_vector(7 downto 0) := (others=>'0');
    signal bias : std_logic_vector(31 downto 0) := (others=>'0');
    signal shift : std_logic_vector(4 downto 0) := (others=>'0');
    signal relu_en : std_logic := '0';
    signal done : std_logic_vector(1 to 3);
    type results_t is array(1 to 3) of std_logic_vector(31 downto 0);
    signal result : results_t;
begin
    clk <= not clk after 5 ns;
    variants : for i in 1 to 3 generate
        dut : entity work.npu_core generic map(PARALLEL_MULTIPLIER=>i=3,FUSED_WIDE_RETIRE=>i/=1)
            port map(clk,rst,start,done(i),a,b,result(i),cmd,bias,shift,relu_en);
    end generate;
    process
        file csv : text open write_mode is RESULTS_FILE;
        variable line_out : line;
        variable q,qr : integer;
        type counts_t is array(1 to 3) of natural;
        variable low : counts_t := (others=>100);
        variable high : counts_t := (others=>0);
        procedure issue(command : std_logic_vector(1 downto 0); expected : std_logic_vector(31 downto 0)) is
            variable seen : std_logic_vector(1 to 3) := (others=>'0');
        begin
            wait until falling_edge(clk); cmd<=command; start<='1';
            wait until rising_edge(clk); wait for 1 ns;
            for i in 1 to 3 loop
                if done(i)='1' then
                    assert result(i)=expected report "immediate result mismatch" severity failure;
                    seen(i):='1';
                end if;
            end loop;
            -- Change live ports after acceptance; a correct transaction uses latches.
            start<='0'; a<=x"5A"; b<=x"A5";
            if seen/="111" then
                for cycle in 1 to 32 loop
                    wait until rising_edge(clk); wait for 1 ns;
                    for i in 1 to 3 loop
                        if done(i)='1' then
                            assert seen(i)='0' report "duplicate completion" severity failure;
                            assert result(i)=expected report "arithmetic mismatch config=" & integer'image(i) &
                                " got=" & to_hstring(result(i)) & " expected=" & to_hstring(expected) severity failure;
                            seen(i):='1';
                            if command="10" then
                                if cycle<low(i) then low(i):=cycle; end if;
                                if cycle>high(i) then high(i):=cycle; end if;
                            end if;
                        end if;
                    end loop;
                    exit when seen="111";
                end loop;
            end if;
            assert seen="111" report "completion timeout" severity failure;
            wait until rising_edge(clk); wait for 1 ns;
            assert done="000" report "completion pulse too long" severity failure;
        end procedure;
    begin
        wait for 30 ns; rst<='0';
        for x in -128 to 127 loop
            for y in -128 to 127 loop
                bias<=(others=>'0'); issue("01",x"00000000");
                a<=std_logic_vector(to_signed(x,8)); b<=std_logic_vector(to_signed(y,8));
                issue("10",std_logic_vector(to_signed(x*y,32)));
            end loop;
        end loop;
        bias<=x"7FFFFFFF"; issue("01",x"7FFFFFFF"); a<=x"01"; b<=x"01"; issue("10",x"7FFFFFFF");
        bias<=x"80000000"; issue("01",x"80000000"); a<=x"FF"; b<=x"01"; issue("10",x"80000000");
        bias<=x"FFFFFFFB"; issue("01",x"FFFFFFFB"); shift<="00001"; issue("11",x"FFFFFFFD");
        relu_en<='1'; issue("11",x"00000000"); relu_en<='0';
        bias<=x"00007FFF"; issue("01",x"00007FFF"); issue("11",x"0000007F");
        bias<=x"FFFF8000"; issue("01",x"FFFF8000"); issue("11",x"FFFFFF80");
        write(line_out,string'("accumulator,shift,signed_int8,relu_int8")); writeline(csv,line_out);
        shift<="00011";
        for value in -1024 to 1024 loop
            bias<=std_logic_vector(to_signed(value,32)); issue("01",std_logic_vector(to_signed(value,32)));
            q:=to_integer(shift_right(to_signed(value,32),3));
            if q>127 then q:=127; elsif q< -128 then q:=-128; end if;
            relu_en<='0'; issue("11",std_logic_vector(to_signed(q,32)));
            write(line_out,value); write(line_out,string'(",3,")); write(line_out,to_integer(signed(result(3))));
            qr:=q; if qr<0 then qr:=0; end if;
            relu_en<='1'; issue("11",std_logic_vector(to_signed(qr,32)));
            write(line_out,string'(",")); write(line_out,to_integer(signed(result(3)))); writeline(csv,line_out);
        end loop;
        for i in 1 to 3 loop
            report "LATENCY config=" & integer'image(i) & " min=" & integer'image(low(i)) & " max=" & integer'image(high(i));
        end loop;
        report "EXHAUSTIVE_PASS pairs=65536 configurations=3 product_checks=196608 operand_capture=pass saturation=pass quantization=pass";
        report "QUANTIZATION_SWEEP_PASS inputs=2049 modes=2 configurations=3 checks=12294";
        stop; wait;
    end process;
end;
