-- ============================================================
-- npu_core.vhd
-- RISC-NPU Project — Neural Processing Unit Top-Level Wrapper
--
-- PURPOSE:
--   Wraps multiplier, accumulator, and relu into a single NPU tile.
--   Presents a simple start/done handshake interface to the CPU.
--   Result is sign-extended to 32 bits and routed to DATA_MUX "11"
--   in data_path.vhd so the CPU can latch it into register A.
--
-- OPCODE MAPPING (decoded by Control_New.vhd):
--   MAC   (1011) : multiply op_a × op_b, accumulate into acc register
--   RELU  (1100) : [future] select relu_out vs acc_out on result bus
--   VLOAD (1101) : [handled in datapath] load immediate into A or B
--
-- TIMING (one MAC operation):
--   T0          : CPU at state_1, decodes MAC opcode, asserts npu_start='1'
--   T1..T1+N    : Multiplier runs (iterative shift-add, ~8 cycles)
--   T1+N        : mul_done='1', acc_en is requested
--   T1+N+1      : accumulator latches product
--   T1+N+2      : npu_done='1', result valid on npu_result
--   T1+N+2      : Control sees npu_done, sets DATA_MUX="11", ld_A='1'
--   T1+N+3      : CPU back to state_0, register A holds NPU result
--
-- CHECKPOINT 1 STATUS:
--   1. multiplier.vhd implemented  (iterative signed 8×8 shift-add)
--   2. accumulator.vhd implemented (16-bit saturating, sat_flag, neg_flag)
--   3. relu.vhd implemented        (combinational, dout = max(0, din))
--   4. NPU state machine implemented with start/done handshake
--   5. npu_result sign extension wired
--
-- TODO:
--   Decide whether MAC returns acc_out directly or relu_out by default.
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity npu_core is
    generic(
        PARALLEL_MULTIPLIER : boolean := false;
        FUSED_WIDE_RETIRE : boolean := true
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;

        -- -------------------------------------------------------
        -- Control handshake (driven by Control_New.vhd)
        -- -------------------------------------------------------
        npu_start  : in  std_logic;    -- pulse '1' for 1 cycle to begin MAC
        npu_done   : out std_logic;    -- held '1' for 1 cycle when result is valid

        -- -------------------------------------------------------
        -- Operand inputs
        -- Sourced from CPU register A (lower 8 bits) and B (lower 8 bits)
        -- Loaded by the CPU using VLOAD / LDA / LDB before issuing MAC
        -- -------------------------------------------------------
        op_a       : in  std_logic_vector(7 downto 0);   -- multiplicand
        op_b       : in  std_logic_vector(7 downto 0);   -- multiplier

        -- -------------------------------------------------------
        -- Result output — sign-extended to 32 bits
        -- Connected to DATA_MUX "11" slot in data_path.vhd
        -- -------------------------------------------------------
        npu_result : out std_logic_vector(31 downto 0);
        -- 00 legacy MAC/ReLU, 01 signed bias load, 10 wide MAC,
        -- 11 arithmetic right shift then signed-int8 or ReLU-int8 clamp.
        command    : in std_logic_vector(1 downto 0) := "00";
        bias       : in std_logic_vector(31 downto 0) := (others => '0');
        quant_shift: in std_logic_vector(4 downto 0) := "00000";
        quant_relu : in std_logic := '0'
    );
end entity;

architecture Behavior of npu_core is

    -- ===========================================================
    -- Component Declarations
    -- Port names match the leaf entity declarations.
    -- ===========================================================

    component multiplier is
        port(
            clk    : in  std_logic;
            rst    : in  std_logic;
            start  : in  std_logic;
            a      : in  std_logic_vector(7 downto 0);
            b      : in  std_logic_vector(7 downto 0);
            done   : out std_logic;
            result : out std_logic_vector(15 downto 0)
        );
    end component;

    component accumulator is
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            en       : in  std_logic;
            data_in  : in  std_logic_vector(15 downto 0);
            q        : out std_logic_vector(15 downto 0);
            sat_flag : out std_logic;
            neg_flag : out std_logic
        );
    end component;

    component relu is
        port(
            din  : in  std_logic_vector(15 downto 0);
            dout : out std_logic_vector(15 downto 0)
        );
    end component;

    -- ===========================================================
    -- Internal Signals
    -- ===========================================================

    -- Multiplier outputs
    signal mul_start  : std_logic;
    signal mul_done   : std_logic;
    signal mul_result : std_logic_vector(15 downto 0);
    signal operand_a, operand_b : std_logic_vector(7 downto 0);

    -- Accumulator signals
    signal acc_en     : std_logic;
    signal acc_out    : std_logic_vector(15 downto 0);
    -- ReLU output
    signal relu_out   : std_logic_vector(15 downto 0);

    -- Result register (holds value until next MAC)
    signal result_reg : std_logic_vector(31 downto 0);
    signal wide_acc : signed(31 downto 0);
    signal active_command : std_logic_vector(1 downto 0);

    function saturate32(v : signed(32 downto 0)) return signed is
    begin
        if v(32) /= v(31) then
            if v(32) = '0' then return signed'(x"7FFFFFFF");
            else return signed'(x"80000000"); end if;
        end if;
        return v(31 downto 0);
    end function;

    -- ===========================================================
    -- NPU Internal State Machine
    -- Controls sequencing of multiply → accumulate → output
    --
    --   NPU_IDLE     → npu_start='1'  → NPU_MUL_WAIT
    --   NPU_MUL_WAIT → mul_done='1'   → NPU_ACC
    --   NPU_ACC      → (1 cycle)      → NPU_CAPTURE
    --   NPU_CAPTURE  → (1 cycle)      → NPU_DONE_STATE
    --   NPU_DONE_STATE → (1 cycle)    → NPU_IDLE
    -- ===========================================================
    type npu_state_t is (NPU_IDLE, NPU_MUL_WAIT, NPU_ACC, NPU_CAPTURE, NPU_DONE_STATE);
    signal npu_state : npu_state_t;

begin

    -- ===========================================================
    -- Multiplier Instantiation
    -- TODO: gate mul_start so it only pulses in NPU_IDLE when
    --       npu_start='1', not continuously.
    -- ===========================================================
    serial_product : if not PARALLEL_MULTIPLIER generate
    mul0 : multiplier port map (
        clk    => clk,
        rst    => rst,
        start  => mul_start,
        a      => operand_a,
        b      => operand_b,
        done   => mul_done,
        result => mul_result
    );
    end generate;

    parallel_product : if PARALLEL_MULTIPLIER generate
        process(clk, rst)
        begin
            if rst = '1' then
                mul_done <= '0';
                mul_result <= (others => '0');
            elsif rising_edge(clk) then
                mul_done <= mul_start;
                if mul_start = '1' then
                    mul_result <= std_logic_vector(signed(operand_a) * signed(operand_b));
                end if;
            end if;
        end process;
    end generate;

    -- ===========================================================
    -- Accumulator Instantiation
    -- acc_en is pulsed for exactly 1 cycle in NPU_ACC state.
    -- TODO: if you want to accumulate across multiple MACs,
    --       only reset the accumulator on explicit CLR opcode.
    -- ===========================================================
    acc0 : accumulator port map (
        clk      => clk,
        rst      => rst,
        en       => acc_en,
        data_in  => mul_result,
        q        => acc_out,
        sat_flag => open,
        neg_flag => open
    );

    -- ===========================================================
    -- ReLU Instantiation (combinational — no clock needed)
    -- ===========================================================
    relu0 : relu port map (
        din  => acc_out,
        dout => relu_out
    );

    -- ===========================================================
    -- NPU State Machine
    -- ===========================================================
    process(clk, rst)
        variable quantized : signed(31 downto 0);
    begin
        if rst = '1' then
            npu_state  <= NPU_IDLE;
            npu_done   <= '0';
            acc_en     <= '0';
            mul_start  <= '0';
            result_reg <= (others => '0');
            wide_acc <= (others => '0');
            active_command <= "00";
            operand_a <= (others => '0');
            operand_b <= (others => '0');

        elsif rising_edge(clk) then
            -- Default outputs (override in each state as needed)
            npu_done  <= '0';
            acc_en    <= '0';
            mul_start <= '0';

            case npu_state is

                -- -------------------------------------------------
                -- IDLE: wait for CPU to assert npu_start
                -- -------------------------------------------------
                when NPU_IDLE =>
                    if npu_start = '1' then
                        -- Capture the complete arithmetic transaction at acceptance.
                        -- The caller may change operands while the unit is busy.
                        operand_a <= op_a;
                        operand_b <= op_b;
                        active_command <= command;
                        if command = "01" then
                            wide_acc <= signed(bias);
                            result_reg <= bias;
                            npu_done <= '1';
                            npu_state <= NPU_DONE_STATE;
                        elsif command = "11" then
                            -- Arithmetic shift rounds negative values toward -infinity.
                            quantized := shift_right(wide_acc, to_integer(unsigned(quant_shift)));
                            if quantized > 127 then quantized := to_signed(127, 32);
                            elsif quant_relu = '1' and quantized < 0 then quantized := (others => '0');
                            elsif quantized < -128 then quantized := to_signed(-128, 32);
                            end if;
                            result_reg <= std_logic_vector(quantized);
                            npu_done <= '1';
                            npu_state <= NPU_DONE_STATE;
                        else
                            mul_start <= '1';
                            npu_state <= NPU_MUL_WAIT;
                        end if;
                    end if;

                -- -------------------------------------------------
                -- MUL_WAIT: stall here until multiplier finishes
                -- TODO: mul_done timing depends on your multiplier
                --       implementation — verify cycle count
                -- -------------------------------------------------
                when NPU_MUL_WAIT =>
                    if mul_done = '1' then
                        if active_command = "10" then
                            wide_acc <= saturate32(resize(wide_acc, 33) + resize(signed(mul_result), 33));
                            if FUSED_WIDE_RETIRE then
                                result_reg <= std_logic_vector(saturate32(resize(wide_acc, 33) + resize(signed(mul_result), 33)));
                                npu_done <= '1';
                            end if;
                        else
                            acc_en <= '1';
                        end if;
                        if active_command = "10" and FUSED_WIDE_RETIRE then
                            npu_state <= NPU_DONE_STATE;
                        else
                            npu_state <= NPU_ACC;
                        end if;
                    end if;

                -- -------------------------------------------------
                -- ACC: accumulator latches product on this clock
                -- TODO: decide here whether to use acc_out or relu_out
                --       For MAC opcode: store acc_out (pre-ReLU)
                --       For RELU opcode: store relu_out (post-ReLU)
                --       Current default: stores relu_out
                -- -------------------------------------------------
                when NPU_ACC =>
                    npu_state  <= NPU_CAPTURE;

                -- -------------------------------------------------
                -- CAPTURE: accumulator output is now stable
                -- -------------------------------------------------
                when NPU_CAPTURE =>
                    if active_command = "10" then
                        result_reg <= std_logic_vector(wide_acc);
                    else
                        result_reg <= std_logic_vector(resize(signed(relu_out), 32));
                    end if;
                    npu_done   <= '1';
                    npu_state  <= NPU_DONE_STATE;

                -- -------------------------------------------------
                -- DONE: result valid for 1 cycle, then back to IDLE
                -- -------------------------------------------------
                when NPU_DONE_STATE =>
                    npu_state <= NPU_IDLE;

                when others =>
                    npu_state <= NPU_IDLE;

            end case;
        end if;
    end process;

    -- ===========================================================
    -- Result Output: sign-extend 16-bit result to 32 bits
    -- The CPU reads this via DATA_MUX = "11" into register A.
    --
    -- TODO: if you want raw accumulator (no ReLU), change
    --       result_reg source in NPU_ACC state above.
    -- ===========================================================
    npu_result <= result_reg;

end Behavior;
