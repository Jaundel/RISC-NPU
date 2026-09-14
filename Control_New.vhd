-- ============================================================
-- Control_New.vhd  [RISC-NPU]
--
-- CPU control FSM with a MAC ISA extension.
--   1011 = MAC: pulse npu_start, enter MAC_WAIT, then latch the
--               npu_result into Reg_A when npu_done is asserted.
--
-- All control outputs receive safe defaults before state-specific
-- overrides. This keeps the control unit combinational and prevents
-- Quartus from inferring accidental latches.
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;

entity Control_New is
    port(
        clk, mclk       : in  std_logic;
        enable          : in  std_logic;
        statusC, statusZ: in  std_logic;
        INST            : in  std_logic_vector(31 downto 0);
        A_Mux, B_Mux    : out std_logic;
        IM_MUX1, REG_Mux: out std_logic;
        IM_MUX2, DATA_Mux : out std_logic_vector(1 downto 0);
        ALU_op          : out std_logic_vector(2 downto 0);
        inc_PC, ld_PC   : out std_logic;
        clr_IR          : out std_logic;
        ld_IR           : out std_logic;
        clr_A, clr_B, clr_C, clr_Z : out std_logic;
        ld_A, ld_B, ld_C, ld_Z     : out std_logic;
        T               : out std_logic_vector(2 downto 0);
        wen, en         : out std_logic;
        npu_start       : out std_logic;
        npu_done        : in  std_logic
    );
end Control_New;

architecture description of Control_New is
    type STATETYPE is (state_0, state_1, state_2, state_3);
    signal present_state    : STATETYPE;
    signal Instruction_sig  : std_logic_vector(3 downto 0);
    signal Instruction_sig2 : std_logic_vector(7 downto 0);
begin
    Instruction_sig  <= INST(31 downto 28);
    Instruction_sig2 <= INST(31 downto 24);

    process (present_state, INST, statusC, statusZ, enable,
             Instruction_sig, Instruction_sig2, npu_done)
    begin
        A_Mux     <= '0';
        B_Mux     <= '0';
        IM_MUX1   <= '0';
        REG_Mux   <= '0';
        IM_MUX2   <= "00";
        DATA_Mux  <= "00";
        ALU_op    <= "010";
        inc_PC    <= '0';
        ld_PC     <= '0';
        clr_IR    <= '0';
        ld_IR     <= '0';
        clr_A     <= '0';
        clr_B     <= '0';
        clr_C     <= '0';
        clr_Z     <= '0';
        ld_A      <= '0';
        ld_B      <= '0';
        ld_C      <= '0';
        ld_Z      <= '0';
        wen       <= '0';
        en        <= '0';
        npu_start <= '0';

        if enable = '1' then
            case present_state is
                when state_0 =>
                    DATA_Mux <= "00";
                    ld_IR    <= '1';

                when state_1 =>
                    ld_PC  <= '1';
                    inc_PC <= '1';

                    case Instruction_sig is
                        when "0010" =>      -- STA
                            REG_Mux  <= '0';
                            DATA_Mux <= "00";
                            en       <= '1';
                            wen      <= '1';

                        when "0011" =>      -- STB
                            REG_Mux  <= '1';
                            DATA_Mux <= "00";
                            en       <= '1';
                            wen      <= '1';

                        when "1001" =>      -- LDA
                            ld_A     <= '1';
                            A_Mux    <= '0';
                            DATA_Mux <= "01";
                            en       <= '1';

                        when "1010" =>      -- LDB
                            ld_B     <= '1';
                            B_Mux    <= '0';
                            DATA_Mux <= "01";
                            en       <= '1';

                        when "1011" | "1100" | "1101" | "1110" => -- NPU commands
                            npu_start <= '1';
                            inc_PC    <= '0';
                            ld_PC     <= '0';

                        when others =>
                            null;
                    end case;

                when state_2 =>
                    if Instruction_sig = "0101" then
                        ld_PC <= '1';
                    elsif Instruction_sig = "0110" then
                        ld_PC <= '1';
                    elsif Instruction_sig = "1000" then
                        ld_PC <= '1';
                    elsif Instruction_sig = "1001" then    -- LDA
                        ld_A     <= '1';
                        A_Mux    <= '0';
                        DATA_Mux <= "01";
                        en       <= '1';
                    elsif Instruction_sig = "1010" then    -- LDB
                        ld_B     <= '1';
                        B_Mux    <= '0';
                        DATA_Mux <= "01";
                        en       <= '1';
                    elsif Instruction_sig = "0010" then    -- STA
                        REG_Mux  <= '0';
                        DATA_Mux <= "00";
                        en       <= '1';
                        wen      <= '1';
                    elsif Instruction_sig = "0011" then    -- STB
                        REG_Mux  <= '1';
                        DATA_Mux <= "00";
                        en       <= '1';
                        wen      <= '1';
                    elsif Instruction_sig = "0000" then    -- LDIA
                        ld_A  <= '1';
                        A_Mux <= '1';
                    elsif Instruction_sig = "0001" then    -- LDIB
                        ld_B  <= '1';
                        B_Mux <= '1';
                    elsif Instruction_sig = "0100" then    -- OR
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "001";
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "00";
                    elsif Instruction_sig2 = "01111001" then  -- AND
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "000";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "01";
                    elsif Instruction_sig2 = "01111110" then  -- SUB
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "110";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "10";
                    elsif Instruction_sig2 = "01110000" then  -- ADD
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "010";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "00";
                    elsif Instruction_sig2 = "01110010" then
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "110";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "00";
                    elsif Instruction_sig2 = "01110011" then
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "010";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "10";
                    elsif Instruction_sig2 = "01111011" then
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "000";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "00";
                    elsif Instruction_sig2 = "01110001" then
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "010";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "01";
                    elsif Instruction_sig2 = "01111101" then  -- OR2
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "001";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                        IM_MUX2  <= "01";
                    elsif Instruction_sig2 = "01110100" then  -- SLL
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "100";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                    elsif Instruction_sig2 = "01111111" then  -- SRL
                        ld_A     <= '1';
                        ld_C     <= '1';
                        ld_Z     <= '1';
                        ALU_op   <= "101";
                        A_Mux    <= '0';
                        DATA_Mux <= "10";
                        IM_MUX1  <= '0';
                    elsif Instruction_sig2 = "01110101" then  -- CLRA
                        clr_A <= '1';
                    elsif Instruction_sig2 = "01110110" then  -- CLRB
                        clr_B <= '1';
                    elsif Instruction_sig2 = "01110111" then  -- CLRC
                        clr_C <= '1';
                    elsif Instruction_sig2 = "01111000" then  -- CLRZ
                        clr_Z <= '1';
                    elsif Instruction_sig2 = "01111010" then  -- JZ
                        if statusZ = '1' then
                            ld_PC  <= '1';
                            inc_PC <= '0';
                        end if;
                    elsif Instruction_sig2 = "01111100" then  -- JC
                        if statusC = '1' then
                            ld_PC  <= '1';
                            inc_PC <= '0';
                        end if;
                    end if;

                when state_3 =>
                    if npu_done = '1' then
                        DATA_Mux <= "11";
                        ld_A     <= '1';
                        A_Mux    <= '0';
                        inc_PC   <= '1';
                        ld_PC    <= '1';
                    end if;
            end case;
        end if;
    end process;

    process (clk, enable)
    begin
        if enable = '1' then
            if rising_edge(clk) then
                if present_state = state_0 then
                    present_state <= state_1;
                elsif present_state = state_1 then
                    if Instruction_sig = "1011" or Instruction_sig = "1100" or
                       Instruction_sig = "1101" or Instruction_sig = "1110" then
                        present_state <= state_3;
                    else
                        present_state <= state_2;
                    end if;
                elsif present_state = state_2 then
                    present_state <= state_0;
                elsif present_state = state_3 then
                    if npu_done = '1' then
                        -- One no-op state_2 cycle gives synchronous instruction
                        -- memory time to present the post-MAC instruction.
                        present_state <= state_2;
                    else
                        present_state <= state_3;
                    end if;
                else
                    present_state <= state_0;
                end if;
            end if;
        else
            present_state <= state_0;
        end if;
    end process;

    with present_state select
        T <= "001" when state_0,
             "010" when state_1,
             "100" when state_2,
             "111" when state_3,
             "001" when others;

end description;
