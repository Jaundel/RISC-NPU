library ieee;
use ieee.std_logic_1164.all;
-- Common virtual-pin core boundary: external instruction source, internal data
-- RAM, same observable result/address ports. Not a board or ROM-inclusive fit.
entity research_core_top is
    generic(CONFIG : natural := 0);
    port(clk,rst : in std_logic;
        instruction : in std_logic_vector(31 downto 0);
        address,result_a : out std_logic_vector(31 downto 0));
end;
architecture rtl of research_core_top is
begin
    cpu : entity work.cpu1 generic map(ENABLE_NPU=>CONFIG/=0,
        PARALLEL_MULTIPLIER=>CONFIG=3,FUSED_WIDE_RETIRE=>CONFIG/=1)
        port map(clk,clk,rst,instruction,open,address,result_a,open,open,open,open,open,open,open,open,open);
end;
