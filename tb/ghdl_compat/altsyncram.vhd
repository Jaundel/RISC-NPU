-- Functional model used only by scripts/run_ghdl_tests.ps1.
-- It mirrors the initialized 64-word program ROM in system_memory.mif so the
-- board wrapper can be tested without a proprietary simulator license.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity altsyncram is
    generic (
        clock_enable_input_a   : string;
        clock_enable_output_a  : string;
        init_file              : string;
        intended_device_family : string;
        lpm_hint               : string;
        lpm_type               : string;
        numwords_a             : natural;
        operation_mode         : string;
        outdata_aclr_a         : string;
        outdata_reg_a          : string;
        power_up_uninitialized : string;
        widthad_a              : natural;
        width_a                : natural;
        width_byteena_a        : natural
    );
    port (
        address_a : in  std_logic_vector(5 downto 0);
        clock0    : in  std_logic;
        data_a    : in  std_logic_vector(31 downto 0);
        wren_a    : in  std_logic;
        q_a       : out std_logic_vector(31 downto 0)
    );
end entity;

architecture behavioral of altsyncram is
    type memory_t is array (0 to 63) of std_logic_vector(31 downto 0);
    signal memory : memory_t := (
        0 => x"00000000", 1 => x"10000032", 2 to 51 => x"70000000",
        52 => x"20000000", 53 => x"00000032", 54 => x"10000032",
        55 => x"B0000000", 56 => x"20000001", others => x"50000039"
    );
begin
    process (clock0)
    begin
        if rising_edge(clock0) then
            if wren_a = '1' then
                memory(to_integer(unsigned(address_a))) <= data_a;
            end if;
            q_a <= memory(to_integer(unsigned(address_a)));
        end if;
    end process;
end architecture;
