-- ============================================================
-- risc_npu_top.vhd
--
-- Board-level wrapper for the RISC-NPU benchmark.
-- Connects cpu1 to the initialized system_memory ROM so the Quartus
-- top entity is a self-contained FPGA image instead of a bare CPU core.
--
-- DE2-115-style ports:
--   CLOCK_50 : 50 MHz clock input
--   KEY(0)   : active-low reset button
--   LEDR     : final benchmark result and done flag
--   LEDG     : live FSM/PC status
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity risc_npu_top is
    port(
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(0 downto 0);
        LEDR     : out std_logic_vector(17 downto 0);
        LEDG     : out std_logic_vector(8 downto 0)
    );
end entity;

architecture rtl of risc_npu_top is
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

    component system_memory is
        port(
            address : in  std_logic_vector(5 downto 0);
            clock   : in  std_logic := '1';
            data    : in  std_logic_vector(31 downto 0);
            wren    : in  std_logic;
            q       : out std_logic_vector(31 downto 0)
        );
    end component;

    signal rst_s        : std_logic;
    signal instr_q      : std_logic_vector(31 downto 0);
    signal reg_a_s      : std_logic_vector(31 downto 0);
    signal pc_s         : std_logic_vector(31 downto 0);
    signal wen_s        : std_logic;
    signal t_s          : std_logic_vector(2 downto 0);
    signal final_result : std_logic_vector(15 downto 0) := (others => '0');
    signal done_reg     : std_logic := '0';
begin
    rst_s <= not KEY(0);

    instr_mem : system_memory
        port map(
            address => pc_s(5 downto 0),
            clock   => CLOCK_50,
            data    => (others => '0'),
            wren    => '0',
            q       => instr_q
        );

    cpu : cpu1
        port map(
            clk      => CLOCK_50,
            mem_clk  => CLOCK_50,
            rst      => rst_s,
            dataIn   => instr_q,
            dataOut  => open,
            addrOut  => open,
            dOutA    => reg_a_s,
            dOutB    => open,
            dOutC    => open,
            dOutZ    => open,
            dOutIR   => open,
            dOutPC   => pc_s,
            wEn      => wen_s,
            outT     => t_s,
            wen_mem  => open,
            en_mem   => open
        );

    process(CLOCK_50, rst_s)
    begin
        if rst_s = '1' then
            final_result <= (others => '0');
            done_reg     <= '0';
        elsif rising_edge(CLOCK_50) then
            if done_reg = '0' and unsigned(pc_s(5 downto 0)) >= to_unsigned(57, 6) then
                final_result <= reg_a_s(15 downto 0);
                done_reg     <= '1';
            end if;
        end if;
    end process;

    LEDR(15 downto 0) <= final_result;
    LEDR(16)          <= wen_s;
    LEDR(17)          <= done_reg;

    LEDG(2 downto 0) <= t_s;
    LEDG(7 downto 3) <= pc_s(4 downto 0);
    LEDG(8)          <= done_reg;
end architecture;
