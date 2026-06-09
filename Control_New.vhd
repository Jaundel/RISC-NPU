-- ============================================================
-- Control_New.vhd  [MODIFIED for RISC-NPU]
-- Changes from original lab6:
--   1. Added ports: npu_start (out), npu_done (in)
--   2. Added state_3 (MAC_WAIT) to STATETYPE
--   3. Added state_3 combinational logic block (stub)
--   4. Modified state transition process to loop in state_3
--      until npu_done='1', then advance to state_0
--   5. Added opcode stubs in state_1 for new NPU opcodes:
--        1011 = MAC   (multiply-accumulate, start NPU)
--        1100 = RELU  (latch relu result into A)
--        1101 = VLOAD (no extra control needed — uses LDA/LDB)
--
-- NEW ISA EXTENSION:
--   Opcode  Mnemonic  Action
--   1011    MAC       Reg_A ← NPU(A[7:0] × B[7:0])  [multi-cycle]
--   1100    RELU      Reg_A ← relu(Reg_A)             [single-cycle, via ALU or NPU]
--   1101    VLOAD     Load immediate into A or B       [same as LDA/LDB immediate]
--
-- TODO LIST (implement in order):
--   [ ] 1. Fill in state_3 combinational outputs (DATA_MUX="11", ld_A='1'
--            on npu_done, hold everything else while waiting)
--   [ ] 2. Complete state_1 MAC case: set npu_start='1', stall PC
--   [ ] 3. Add RELU opcode (1100) handling in state_2
--   [ ] 4. Verify npu_start is only asserted for 1 clock cycle
--   [ ] 5. Add VLOAD handling if different from existing LDA immediate
-- ============================================================

library ieee;
use ieee.std_logic_1164.ALL;

ENTITY Control_New IS
    PORT(
        clk, mclk   : IN  STD_LOGIC;
        enable      : IN  STD_LOGIC;
        statusC, statusZ : IN STD_LOGIC;
        INST        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        A_Mux, B_Mux    : OUT STD_LOGIC;
        IM_MUX1, REG_Mux : OUT STD_LOGIC;
        IM_MUX2, DATA_Mux : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        ALU_op      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        inc_PC, ld_PC : OUT STD_LOGIC;
        clr_IR      : OUT STD_LOGIC;
        ld_IR       : OUT STD_LOGIC;
        clr_A, clr_B, clr_C, clr_Z : OUT STD_LOGIC;
        ld_A, ld_B, ld_C, ld_Z     : OUT STD_LOGIC;
        T           : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        wen, en     : OUT STD_LOGIC;

        -- -------------------------------------------------------
        -- NPU handshake ports (new for RISC-NPU)
        -- npu_start: asserted for 1 cycle when MAC opcode decoded
        -- npu_done:  asserted by npu_core when result is ready
        -- -------------------------------------------------------
        npu_start   : OUT STD_LOGIC;
        npu_done    : IN  STD_LOGIC
    );
END Control_New;

ARCHITECTURE description OF Control_New IS

    -- state_3 = MAC_WAIT: CPU stalls here until npu_done='1'
    TYPE STATETYPE IS (state_0, state_1, state_2, state_3);
    SIGNAL present_state    : STATETYPE;
    SIGNAL Instruction_sig  : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL Instruction_sig2 : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
    Instruction_sig  <= INST(31 DOWNTO 28);
    Instruction_sig2 <= INST(31 DOWNTO 24);

    -- ===========================================================
    -- Combinational Output Process
    -- ===========================================================
    PROCESS (present_state, INST, statusC, statusZ, enable,
             Instruction_sig, Instruction_sig2, npu_done)
    BEGIN
        if enable = '1' then

            -- ---------------------------------------------------
            -- STATE_0: Fetch — load IR from data bus
            -- ---------------------------------------------------
            if present_state = state_0 then
                DATA_Mux  <= "00";
                clr_IR    <= '0';
                ld_IR     <= '1';
                ld_PC     <= '0';
                inc_PC    <= '0';
                clr_A     <= '0'; ld_A  <= '0';
                clr_B     <= '0'; ld_B  <= '0';
                clr_C     <= '0'; ld_C  <= '0';
                clr_Z     <= '0'; ld_Z  <= '0';
                en        <= '0'; wen   <= '0';
                npu_start <= '0';

            -- ---------------------------------------------------
            -- STATE_1: Decode / Execute1
            -- ---------------------------------------------------
            elsif present_state = state_1 then
                clr_IR    <= '0'; ld_IR  <= '0';
                ld_PC     <= '1'; inc_PC <= '1';
                clr_A     <= '0'; ld_A   <= '0';
                clr_B     <= '0'; ld_B   <= '0';
                clr_C     <= '0'; ld_C   <= '0';
                clr_Z     <= '0'; ld_Z   <= '0';
                en        <= '0'; wen    <= '0';
                npu_start <= '0';

                if Instruction_sig = "0010" then       -- STA
                    REG_Mux  <= '0'; DATA_Mux <= "00";
                    en <= '1'; wen <= '1';

                elsif Instruction_sig = "0011" then    -- STB
                    REG_Mux  <= '1'; DATA_Mux <= "00";
                    en <= '1'; wen <= '1';

                elsif Instruction_sig = "1001" then    -- LDA
                    ld_A    <= '1'; A_Mux    <= '0';
                    DATA_Mux <= "01"; en <= '1'; wen <= '0';

                elsif Instruction_sig = "1010" then    -- LDB
                    ld_B    <= '1'; B_Mux    <= '0';
                    DATA_Mux <= "01"; en <= '1'; wen <= '0';

                -- -----------------------------------------------
                -- MAC opcode: start NPU, stall PC increment
                -- TODO(state_1_MAC):
                --   1. Assert npu_start='1' for this 1 cycle
                --   2. Do NOT increment PC yet (inc_PC='0')
                --   3. The state transition process below will
                --      route to state_3 (MAC_WAIT) instead of state_2
                -- -----------------------------------------------
                elsif Instruction_sig = "1011" then    -- MAC
                    npu_start <= '1';
                    inc_PC    <= '0';
                    ld_PC     <= '0';
                    -- TODO: confirm no register changes needed here

                -- -----------------------------------------------
                -- RELU opcode: latch relu result from NPU into A
                -- TODO(state_1_RELU): decide if RELU is single-cycle
                --   Option A: npu_core always has relu_out available
                --             → DATA_MUX="11", ld_A='1' here
                --   Option B: issue a separate RELU command to npu_core
                -- -----------------------------------------------
                elsif Instruction_sig = "1100" then    -- RELU
                    -- TODO: implement RELU latch
                    null;

                -- -----------------------------------------------
                -- VLOAD opcode: load immediate into A
                -- Same as existing LDA immediate — may not need changes
                -- TODO: verify if separate opcode is needed
                -- -----------------------------------------------
                elsif Instruction_sig = "1101" then    -- VLOAD
                    -- TODO: implement VLOAD
                    null;

                end if;

            -- ---------------------------------------------------
            -- STATE_2: Execute2 / writeback
            -- (unchanged from lab6 — all original opcodes below)
            -- ---------------------------------------------------
            elsif present_state = state_2 then

                if Instruction_sig = "0101" then
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='1'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; clr_Z<='0'; ld_Z<='0';
                    npu_start <= '0';
                elsif Instruction_sig = "0110" then
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='1'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; clr_Z<='0'; ld_Z<='0';
                    npu_start <= '0';
                elsif Instruction_sig = "1000" then
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='1'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; clr_Z<='0'; ld_Z<='0';
                    npu_start <= '0';
                elsif Instruction_sig = "1001" then    -- LDA (2-cycle)
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_A<='1'; A_Mux<='0'; DATA_Mux<="01"; en<='1'; wen<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "1010" then    -- LDB (2-cycle)
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_B<='1'; B_Mux<='0'; DATA_Mux<="01"; en<='1'; wen<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "0010" then    -- STA (2-cycle)
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    REG_Mux<='0'; DATA_Mux<="00"; en<='1'; wen<='1';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "0011" then    -- STB (2-cycle)
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    REG_Mux<='1'; DATA_Mux<="00"; en<='1'; wen<='1';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "0000" then    -- LDIA
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_A<='1'; A_Mux<='1';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "0001" then    -- LDIB
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_B<='1'; B_Mux<='1';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig = "0100" then    -- OR
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_A<='1';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111001" then  -- AND
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="000";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="01";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111110" then  -- SUB
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="110";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="10";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110000" then  -- ADD
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="010";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="00";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110010" then
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="110";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="00";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110011" then
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="010";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="10";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111011" then
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="000";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="00";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110001" then
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="010";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="01";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111101" then
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="001";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0'; IM_MUX2<="01";
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110100" then  -- SLL
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="100";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111111" then  -- SRL
                    ld_A<='1'; ld_C<='1'; ld_Z<='1'; ALU_op<="101";
                    A_Mux<='0'; DATA_Mux<="10"; IM_MUX1<='0';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; clr_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110101" then  -- CLRA
                    clr_A<='1';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    ld_A<='0'; clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110110" then  -- CLRB
                    clr_B<='1';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01110111" then  -- CLRC
                    clr_C<='1';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111000" then  -- CLRZ
                    clr_Z<='1';
                    clr_IR<='0'; ld_IR<='0'; ld_PC<='0'; inc_PC<='0';
                    clr_A<='0'; ld_A<='0'; clr_B<='0'; ld_B<='0';
                    clr_C<='0'; ld_C<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111010" then  -- JZ
                    if (statusZ = '1') then
                        ld_PC<='1'; inc_PC<='1';
                    end if;
                    clr_IR<='0'; ld_IR<='0'; clr_A<='0'; ld_A<='0';
                    clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                elsif Instruction_sig2 = "01111100" then  -- JC
                    if (statusC = '1') then
                        ld_PC<='1'; inc_PC<='1';
                    end if;
                    clr_IR<='0'; ld_IR<='0'; clr_A<='0'; ld_A<='0';
                    clr_B<='0'; ld_B<='0'; clr_C<='0'; ld_C<='0';
                    clr_Z<='0'; ld_Z<='0'; npu_start <= '0';
                else
                    npu_start <= '0';
                end if;

            -- ---------------------------------------------------
            -- STATE_3: MAC_WAIT — stall CPU until NPU finishes
            --
            -- TODO(state_3):
            --   While npu_done='0':
            --     Hold all register loads low (ld_A, ld_B, etc.)
            --     Hold inc_PC='0', ld_PC='0' (don't advance)
            --     npu_start='0' (don't re-trigger multiplier)
            --
            --   When npu_done='1':
            --     Set DATA_MUX="11" (route npu_result to data bus)
            --     Set ld_A='1'      (latch NPU result into register A)
            --     Set inc_PC='1'    (advance to next instruction)
            --     Set ld_PC='1'
            --
            --   The state transition process (below) exits state_3
            --   back to state_0 when npu_done='1'.
            -- ---------------------------------------------------
            elsif present_state = state_3 then
                npu_start <= '0';
                en        <= '0';
                wen       <= '0';
                clr_IR    <= '0'; ld_IR  <= '0';
                clr_A     <= '0'; clr_B  <= '0';
                clr_C     <= '0'; ld_C   <= '0';
                clr_Z     <= '0'; ld_Z   <= '0';
                clr_B     <= '0'; ld_B   <= '0';

                if npu_done = '1' then
                    -- NPU result ready: route to data bus, latch into A, advance PC
                    DATA_Mux <= "11";
                    ld_A     <= '1';
                    A_Mux    <= '0';
                    inc_PC   <= '1';
                    ld_PC    <= '1';
                    ld_Z     <= '0';   -- Z flag not updated on MAC (ALU zero_flag is not NPU-related)
                else
                    -- Still waiting: freeze everything
                    DATA_Mux <= "00";
                    ld_A     <= '0';
                    inc_PC   <= '0';
                    ld_PC    <= '0';
                end if;

            end if;
        end if;
    END PROCESS;

    -- ===========================================================
    -- State Transition Process
    -- Modified from lab6: state_3 loops until npu_done='1'
    -- ===========================================================
    PROCESS (clk, enable)
    begin
        if enable = '1' then
            if rising_edge(clk) then
                if present_state = state_0 then
                    present_state <= state_1;
                elsif present_state = state_1 then
                    -- TODO(transition_MAC): if MAC opcode decoded in state_1,
                    --   go to state_3 (MAC_WAIT) instead of state_2
                    if Instruction_sig = "1011" then
                        present_state <= state_3;
                    else
                        present_state <= state_2;
                    end if;
                elsif present_state = state_2 then
                    present_state <= state_0;
                elsif present_state = state_3 then
                    -- Stay in state_3 until NPU signals done
                    if npu_done = '1' then
                        present_state <= state_0;
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
    END process;

    WITH present_state select
        T <= "001" when state_0,
             "010" when state_1,
             "100" when state_2,
             "111" when state_3,   -- new: MAC_WAIT visible on T output
             "001" when others;

END description;
