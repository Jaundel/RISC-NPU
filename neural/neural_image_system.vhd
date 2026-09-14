-- Synthesizable CPU-driven neural renderer. No host computes activations/RGB.
-- ROM supplies firmware; coordinate hardware substitutes two immediates.
-- Pixel output is a ready-less stream: consumer must accept every valid pulse.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.neural_program.all;

entity neural_image_system is
    port(clk, rst : in std_logic;
         pixel_valid, frame_done : out std_logic;
         pixel_index : out unsigned(15 downto 0);
         pixel_rgb : out std_logic_vector(23 downto 0);
         cycle_count : out unsigned(31 downto 0);
         debug_pc, debug_a, debug_b : out std_logic_vector(31 downto 0);
         debug_phase : out std_logic_vector(2 downto 0));
end;

architecture rtl of neural_image_system is
    signal cpu_rst : std_logic;
    signal reset_cycles : integer range 0 to 3 := 3;
    signal pixel : integer range 0 to IMAGE_SIZE * IMAGE_SIZE - 1 := 0;
    signal red, green : std_logic_vector(7 downto 0) := (others=>'0');
    signal finished : std_logic := '0';
    signal cycles : unsigned(31 downto 0) := (others=>'0');
    signal instruction, address, reg_a, reg_b, ir, pc, bus_data : std_logic_vector(31 downto 0);
    signal phase : std_logic_vector(2 downto 0);
    signal flag_c, flag_z, wen, wm, em : std_logic;
    signal rom_q : std_logic_vector(31 downto 0);
begin
    assert IMAGE_SIZE >= 2 and IMAGE_SIZE <= 256 report "image dimensions out of range" severity failure;
    cpu_rst <= '1' when rst='1' or reset_cycles>0 or finished='1' else '0';
    dut : entity work.cpu1 port map(clk, clk, cpu_rst, instruction, bus_data,
        address, reg_a, reg_b, flag_c, flag_z, ir, pc, wen, phase, wm, em);

    -- Synchronous firmware ROM. CPU fetch and post-MAC bubble accommodate it.
    process(clk)
        variable index : natural;
    begin
        if rising_edge(clk) then
            if not is_x(address) then
                index := to_integer(unsigned(address(15 downto 0)));
                if index < PROGRAM_LENGTH then rom_q <= PROGRAM_ROM(index);
                else rom_q <= x"80000000"; end if;
            end if;
        end if;
    end process;
    process(address, pixel, rom_q)
        variable coordinate : natural;
    begin
        instruction <= rom_q;
        if address = x"00000000" or address = x"00000002" then
            if address = x"00000000" then coordinate := pixel mod IMAGE_SIZE;
            else coordinate := pixel / IMAGE_SIZE; end if;
            coordinate := (coordinate * 127 + (IMAGE_SIZE-1)/2) / (IMAGE_SIZE-1);
            instruction <= std_logic_vector(to_unsigned(coordinate, 32));
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            pixel_valid <= '0';
            if rst='1' then
                reset_cycles <= 3; pixel <= 0; finished <= '0'; cycles <= (others=>'0');
                red <= (others=>'0'); green <= (others=>'0');
                pixel_index <= (others=>'0'); pixel_rgb <= (others=>'0');
            elsif finished='0' then
                cycles <= cycles + 1;
                if reset_cycles > 0 then reset_cycles <= reset_cycles - 1;
                elsif wen='1' and phase="010" and ir(31 downto 28)="0010" then
                    case ir(7 downto 0) is
                        when x"F0" => red <= reg_a(7 downto 0);
                        when x"F1" => green <= reg_a(7 downto 0);
                        when x"F2" =>
                            pixel_rgb <= red & green & reg_a(7 downto 0);
                            pixel_index <= to_unsigned(pixel, 16); pixel_valid <= '1';
                            if pixel = IMAGE_SIZE*IMAGE_SIZE-1 then finished <= '1';
                            else pixel <= pixel + 1; reset_cycles <= 3; end if;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;
    frame_done <= finished; cycle_count <= cycles;
    debug_pc <= pc; debug_a <= reg_a; debug_b <= reg_b; debug_phase <= phase;
end;
