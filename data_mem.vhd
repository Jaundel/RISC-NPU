library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity data_mem is
port(
    clk      : in std_logic;
    addr     : in unsigned(7 downto 0);
    data_in  : in    std_logic_vector(31 downto 0);
    wen      : in    std_logic;
    en       : in std_logic;
    data_out : out   std_logic_vector(31 downto 0)
    );
end data_mem;

architecture Behavior of data_mem is
    type RAM is array (0 to 255) of std_logic_vector(31 downto 0);
    signal DATAMEM : RAM;
begin
    -- Hold the registered read port when disabled or writing. This matches
    -- FPGA block-RAM clock-enable behaviour; callers sample only enabled reads.
    process(clk)
    begin
        if(clk'event and clk='0') then
            if en = '1' then
                if (wen = '0') then
                    data_out <= DATAMEM(conv_integer(addr));
                end if;
                if (wen = '1') then
                    DATAMEM(conv_integer(addr)) <= data_in;
                end if;
            end if;
        end if;
    end process;
end Behavior;
