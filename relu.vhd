library ieee;
use ieee.std_logic_1164.all;

entity relu is
    port(
        din  : in  std_logic_vector(15 downto 0);
        dout : out std_logic_vector(15 downto 0)
    );
end relu;

architecture Behavior of relu is
begin

    dout <= (others => '0') when din(15) = '1' else din;

end Behavior;
