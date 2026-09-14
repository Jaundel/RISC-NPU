-- ============================================================
-- cpu1.vhd  [MODIFIED for RISC-NPU]
-- Top-level entity connecting CPU and NPU.
--
-- Changes from original lab6:
--   1. Added npu_core component declaration and instantiation
--   2. Added internal signals: npu_start, npu_done, npu_result
--   3. Updated Data_Path port map: added npu_result connection
--   4. Updated Control_NEW port map: added npu_start/npu_done
--   5. npu_core receives op_a/op_b from register A/B lower 8 bits
--
-- DATA FLOW (MAC instruction):
--   1. CPU executes LDA/LDB to load operands into reg A and reg B
--   2. CPU fetches MAC opcode (1011xxxx...)
--   3. Control asserts npu_start='1' for 1 cycle in state_1
--   4. npu_core receives op_a=dOutA[7:0], op_b=dOutB[7:0]
--   5. npu_core runs multiply → accumulate → relu (~10 cycles)
--   6. npu_core asserts npu_done='1', npu_result valid
--   7. Control (state_3) sees npu_done, sets DATA_MUX="11", ld_A='1'
--   8. npu_result flows into reg A via data bus
--   9. CPU continues to next instruction
--
-- ============================================================

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

ENTITY cpu1 IS
GENERIC (
    ENABLE_NPU : boolean := true;
    PARALLEL_MULTIPLIER : boolean := false;
    FUSED_WIDE_RETIRE : boolean := true
);
PORT (
    clk      : IN  STD_LOGIC;
    mem_clk  : IN  STD_LOGIC;
    rst      : IN  STD_LOGIC;
    dataIn   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    dataOut  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    addrOut  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    dOutA    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    dOutB    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    dOutC    : OUT STD_LOGIC;
    dOutZ    : OUT STD_LOGIC;
    dOutIR   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    dOutPC   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    wEn      : OUT STD_LOGIC;
    outT     : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    wen_mem  : OUT STD_LOGIC;
    en_mem   : OUT STD_LOGIC
);
END cpu1;

ARCHITECTURE description OF cpu1 IS

    -- ===========================================================
    -- Component: Data_Path (modified — now has npu_result port)
    -- ===========================================================
    COMPONENT Data_Path IS
    PORT (
        Clk, mClk   : IN STD_LOGIC;
        WEN, EN     : IN STD_LOGIC;
        Clr_A, Ld_A : IN STD_LOGIC;
        Clr_B, Ld_B : IN STD_LOGIC;
        Clr_C, Ld_C : IN STD_LOGIC;
        Clr_Z, Ld_Z : IN STD_LOGIC;
        ClrPC, Ld_PC : IN STD_LOGIC;
        ClrIR, Ld_IR : IN STD_LOGIC;
        Out_A    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Out_B    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Out_C    : OUT STD_LOGIC;
        Out_Z    : OUT STD_LOGIC;
        Out_PC   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Out_IR   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        Inc_PC   : IN STD_LOGIC;
        ADDR_OUT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        DATA_IN  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        DATA_BUS, MEM_OUT, MEM_IN : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        MEM_ADDR : OUT unsigned(7 DOWNTO 0);
        DATA_Mux : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        REG_Mux  : IN STD_LOGIC;
        A_MUX, B_MUX : IN STD_LOGIC;
        IM_MUX1  : IN STD_LOGIC;
        IM_MUX2  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        ALU_Op   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        npu_result : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT;

    -- ===========================================================
    -- Component: Control_NEW (modified — npu_start/npu_done added)
    -- ===========================================================
    COMPONENT Control_NEW IS
    PORT (
        clk, mclk   : IN STD_LOGIC;
        enable      : IN STD_LOGIC;
        statusC, statusZ : IN STD_LOGIC;
        INST        : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        A_Mux, B_Mux : OUT STD_LOGIC;
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
        -- New ports: NPU handshake
        npu_start   : OUT STD_LOGIC;
        npu_done    : IN  STD_LOGIC
    );
    END COMPONENT;

    -- ===========================================================
    -- Component: reset_circuit (unchanged)
    -- ===========================================================
    COMPONENT reset_circuit IS
    PORT (
        Reset      : IN  STD_LOGIC;
        Clk        : IN  STD_LOGIC;
        Enable_PD  : OUT STD_LOGIC;
        Clr_PC     : OUT STD_LOGIC
    );
    END COMPONENT;

    -- ===========================================================
    -- Component: npu_core (new)
    -- TODO: update port names below if your implementations differ
    -- ===========================================================
    COMPONENT npu_core IS
    GENERIC (
        PARALLEL_MULTIPLIER : boolean := false;
        FUSED_WIDE_RETIRE : boolean := true
    );
    PORT (
        clk        : IN  STD_LOGIC;
        rst        : IN  STD_LOGIC;
        npu_start  : IN  STD_LOGIC;
        npu_done   : OUT STD_LOGIC;
        op_a       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        op_b       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        npu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        command : IN STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
        bias : IN STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
        quant_shift : IN STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
        quant_relu : IN STD_LOGIC := '0'
    );
    END COMPONENT;

    -- ===========================================================
    -- Internal Signals
    -- ===========================================================
    -- Existing CPU interconnects
    SIGNAL dp_mux1, dp_clrA, dp_ldA, dp_clrB, dp_ldB,
           dp_clrC, dp_ldC, dp_clrZ, dp_ldZ,
           memWEN, memEN, dp_muxA, dp_muxB : STD_LOGIC;
    SIGNAL mux_data, reg, enpd, irlc, irld,
           pinc, pclr, pcld, out0, out1 : STD_LOGIC;
    SIGNAL outIR  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu    : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL dp_mux2, dp_muxData : STD_LOGIC_VECTOR(1 DOWNTO 0);

    -- Register outputs (needed to feed operands to NPU)
    SIGNAL reg_a_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL reg_b_out : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- NPU interconnect signals
    SIGNAL npu_start_s  : STD_LOGIC;
    SIGNAL npu_done_s   : STD_LOGIC;
    SIGNAL npu_result_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL npu_command_s : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL npu_bias_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN
    with outIR(31 DOWNTO 28) select npu_command_s <=
        "01" when "1100", "10" when "1101", "11" when "1110", "00" when others;
    -- NINIT reads signed register A[15:0]; the accumulator remains signed 32-bit.
    npu_bias_s <= (31 DOWNTO 16 => reg_a_out(15)) & reg_a_out(15 DOWNTO 0);

    -- ===========================================================
    -- Data Path Instantiation
    -- ===========================================================
    dat : Data_Path
    PORT MAP(
        Clk     => clk,       mClk    => mem_clk,
        WEN     => memWEN,    EN      => memEN,
        Clr_A   => dp_clrA,  Ld_A    => dp_ldA,
        Clr_B   => dp_clrB,  Ld_B    => dp_ldB,
        Clr_C   => dp_clrC,  Ld_C    => dp_ldC,
        Clr_Z   => dp_clrZ,  Ld_Z    => dp_ldZ,
        ClrPC   => pclr,     Ld_PC   => pcld,
        ClrIR   => irlc,     Ld_IR   => irld,
        Out_A   => reg_a_out, Out_B  => reg_b_out,
        Out_C   => out0,      Out_Z  => out1,
        Out_PC  => dOutPC,    Out_IR => outIR,
        Inc_PC  => pinc,
        ADDR_OUT => addrOut,  DATA_IN => dataIn,
        DATA_BUS => dataOut,
        DATA_Mux => dp_muxData,
        REG_Mux  => reg,
        A_MUX    => dp_muxA,  B_MUX  => dp_muxB,
        IM_MUX1  => dp_mux1,  IM_MUX2 => dp_mux2,
        ALU_Op   => alu,
        npu_result => npu_result_s
    );

    -- ===========================================================
    -- Control Unit Instantiation
    -- ===========================================================
    control_unit : Control_NEW
    PORT MAP(
        clk     => clk,    mclk    => mem_clk,
        enable  => enpd,
        statusC => out0,   statusZ => out1,
        INST    => outIR,
        A_Mux   => dp_muxA, B_Mux  => dp_muxB,
        IM_MUX1 => dp_mux1, REG_Mux => reg,
        IM_MUX2 => dp_mux2, DATA_Mux => dp_muxData,
        ALU_op  => alu,
        inc_PC  => pinc,   ld_PC   => pcld,
        clr_IR  => irlc,   ld_IR   => irld,
        clr_A   => dp_clrA, clr_B  => dp_clrB,
        clr_C   => dp_clrC, clr_Z  => dp_clrZ,
        ld_A    => dp_ldA,  ld_B   => dp_ldB,
        ld_C    => dp_ldC,  ld_Z   => dp_ldZ,
        T       => outT,
        wen     => memWEN,  en     => memEN,
        -- NPU handshake
        npu_start => npu_start_s,
        npu_done  => npu_done_s
    );

    -- ===========================================================
    -- Reset Circuit Instantiation
    -- ===========================================================
    reset : reset_circuit
    PORT MAP(
        Reset     => rst,
        Clk       => clk,
        Enable_PD => enpd,
        Clr_PC    => pclr
    );

    -- ===========================================================
    -- NPU Core Instantiation
    -- op_a = lower 8 bits of register A (loaded before MAC call)
    -- op_b = lower 8 bits of register B (loaded before MAC call)
    --
    -- TODO: if you want wider operands (e.g. 16-bit), adjust the
    --       bit slices here and update npu_core/multiplier ports.
    -- ===========================================================
    with_npu : if ENABLE_NPU generate
    npu : npu_core
    GENERIC MAP(PARALLEL_MULTIPLIER => PARALLEL_MULTIPLIER,
                FUSED_WIDE_RETIRE => FUSED_WIDE_RETIRE)
    PORT MAP(
        clk        => clk,
        rst        => rst,
        npu_start  => npu_start_s,
        npu_done   => npu_done_s,
        op_a       => reg_a_out(7 DOWNTO 0),
        op_b       => reg_b_out(7 DOWNTO 0),
        npu_result => npu_result_s,
        command => npu_command_s,
        bias => npu_bias_s,
        quant_shift => outIR(4 DOWNTO 0),
        quant_relu => outIR(8)
    );
    end generate;
    without_npu : if not ENABLE_NPU generate
        -- Software-only resource baseline. Accelerator opcodes are unsupported.
        npu_result_s <= (others => '0');
        npu_done_s <= '0';
    end generate;

    -- ===========================================================
    -- Output Assignments
    -- ===========================================================
    dOutA  <= reg_a_out;
    dOutB  <= reg_b_out;
    dOutC   <= out0;
    dOutZ   <= out1;
    dOutIR  <= outIR;
    wEn     <= memWEN;
    wen_mem <= '0';
    en_mem  <= '0';

END description;
