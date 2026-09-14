library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.neural_program.all;

entity neural_image_tb is
    generic(PIXEL_LIMIT : positive := IMAGE_SIZE*IMAGE_SIZE;
            OUTPUT_FILE : string := "artifacts/raw/rtl-pixels.csv");
end;
architecture test of neural_image_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal valid, done : std_logic;
    signal index : unsigned(15 downto 0);
    signal rgb : std_logic_vector(23 downto 0);
    signal cycles : unsigned(31 downto 0);
    signal pc, a, b : std_logic_vector(31 downto 0);
    signal phase : std_logic_vector(2 downto 0);
begin
    clk <= not clk after 10 ns;
    rst <= '0' after 55 ns;
    dut : entity work.neural_image_system port map(clk, rst, valid, done, index,
        rgb, cycles, pc, a, b, phase);
    process
        file oracle : text open read_mode is "neural/generated/expected-rgb.txt";
        file pixels : text open write_mode is OUTPUT_FILE;
        variable row, output_row : line;
        variable r, g, bl, count : integer := 0;
    begin
        write(output_row, string'("pixel,cycle,r,g,b")); writeline(pixels, output_row);
        loop
            wait until rising_edge(clk); wait for 1 ns;
            assert to_integer(cycles) < PIXEL_LIMIT * 100000
                report "image timeout" severity failure;
            if valid='1' then
                assert not endfile(oracle) report "excess RTL output" severity failure;
                readline(oracle, row); read(row, r); read(row, g); read(row, bl);
                assert to_integer(index)=count report "pixel ordering" severity failure;
                assert to_integer(unsigned(rgb(23 downto 16)))=r and
                       to_integer(unsigned(rgb(15 downto 8)))=g and
                       to_integer(unsigned(rgb(7 downto 0)))=bl
                    report "RGB mismatch at pixel " & integer'image(count) &
                    " got " & to_hstring(rgb) & " expected " & integer'image(r) & "," &
                    integer'image(g) & "," & integer'image(bl) severity failure;
                write(output_row, count); write(output_row, string'(","));
                write(output_row, to_integer(cycles)); write(output_row, string'(","));
                write(output_row, r); write(output_row, string'(","));
                write(output_row, g); write(output_row, string'(","));
                write(output_row, bl); writeline(pixels, output_row);
                count := count + 1;
                if count mod IMAGE_SIZE = 0 then
                    report "verified pixels=" & integer'image(count);
                end if;
                if count=PIXEL_LIMIT then
                    if PIXEL_LIMIT=IMAGE_SIZE*IMAGE_SIZE then
                        assert done='1' report "missing frame_done" severity failure;
                        assert endfile(oracle) report "missing RTL pixels" severity failure;
                    end if;
                    report "neural_image_tb PASSED pixels=" & integer'image(count) &
                        " cycles=" & integer'image(to_integer(cycles));
                    stop; wait;
                end if;
            end if;
        end loop;
    end process;
end;
