library ieee;
use ieee.std_logic_1164.all;

entity alu is
	port (
		a : in std_logic_vector(31 downto 0);
		b : in std_logic_vector(31 downto 0);
		op : in std_logic_vector(2 downto 0);
		result : out std_logic_vector(31 downto 0);
		zero : out std_logic;
		cout : out std_logic
	);
end alu;

architecture Behavior of alu is
	component adder32 is
		port (
			Cin : in std_logic;
			X, Y : in std_logic_vector(31 downto 0);
			S : out std_logic_vector(31 downto 0);
			Cout : out std_logic
		);
	end component;

	signal result_s : std_logic_vector(31 downto 0) := (others => '0');
	signal cout_s : std_logic := '0';
	signal zero_s : std_logic := '0';
	signal result_add : std_logic_vector(31 downto 0) := (others => '0');
	signal cout_add : std_logic := '0';
	signal result_sub : std_logic_vector(31 downto 0) := (others => '0');
	signal cout_sub : std_logic := '0';

	begin

	add0 : adder32 port map (op(2), a, b, result_add, cout_add);
	sub0 : adder32 port map (op(2), a, not b, result_sub, cout_sub);

	process (a, b, op, result_add, result_sub, cout_add, cout_sub)
		variable result_v : std_logic_vector(31 downto 0);
		variable cout_v   : std_logic;
	begin
		case (op) is
			when "000" => -- a and b
				result_v := a and b;
				cout_v   := '0';
			when "001" => -- a or b
				result_v := a or b;
				cout_v   := '0';
			when "010" => -- a + b
				result_v := result_add;
				cout_v   := cout_add;
			when "110" => -- a - b
				result_v := result_sub;
				cout_v   := cout_sub;
			when "100" => -- a sll 1
				result_v := a(30 downto 0) & '0';
				cout_v   := a(31);
			when "101" => -- a srl 1
				result_v := '0' & a(31 downto 1);
				cout_v   := '0';
			when others =>
				result_v := a;
				cout_v   := '0';
		end case;

		result_s <= result_v;
		cout_s   <= cout_v;

		if result_v = x"00000000" then
			zero_s <= '1';
		else
			zero_s <= '0';
		end if;
	end process;

			result <= result_s;
			cout <= cout_s;
			zero <= zero_s;
end Behavior;

