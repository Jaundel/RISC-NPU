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
--   T1+N        : mul_done='1', accumulator latches product
--   T1+N+1      : npu_done='1', result valid on npu_result
--   T1+N+1      : Control sees npu_done, sets DATA_MUX="11", ld_A='1'
--   T1+N+2      : CPU back to state_0, register A holds NPU result
--
-- TODO LIST (implement in order):
--   1. Implement multiplier.vhd  (iterative signed 8×8 shift-add)
--   2. Implement accumulator.vhd (16-bit saturating, sat_flag, neg_flag)
--   3. Implement relu.vhd        (combinational, dout = max(0, din))
--   4. Update component port maps below to match your implementations
--   5. Implement the NPU state machine process
--   6. Wire npu_result sign extension correctly
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity npu_core is
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
        npu_result : out std_logic_vector(31 downto 0)
    );
end entity;

architecture Behavior of npu_core is

    -- ===========================================================
    -- Component Declarations
    -- TODO: After implementing each component, verify that the
    --       port names here match the entity declarations exactly.
    -- ===========================================================

    component multiplier is
        -- TODO(multiplier): update port names to match your implementation
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
        -- TODO(accumulator): update port names to match your implementation
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
        -- TODO(relu): update port names to match your implementation
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

    -- Accumulator signals
    signal acc_en     : std_logic;
    signal acc_out    : std_logic_vector(15 downto 0);
    signal sat_flag   : std_logic;
    signal neg_flag   : std_logic;

    -- ReLU output
    signal relu_out   : std_logic_vector(15 downto 0);

    -- Result register (holds value until next MAC)
    signal result_reg : std_logic_vector(15 downto 0);

    -- ===========================================================
    -- NPU Internal State Machine
    -- Controls sequencing of multiply → accumulate → output
    --
    -- TODO(state_machine): implement transitions below
    --   NPU_IDLE     → npu_start='1'  → NPU_MUL_WAIT
    --   NPU_MUL_WAIT → mul_done='1'   → NPU_ACC
    --   NPU_ACC      → (1 cycle)      → NPU_DONE
    --   NPU_DONE     → (1 cycle)      → NPU_IDLE
    -- ===========================================================
    type npu_state_t is (NPU_IDLE, NPU_MUL_WAIT, NPU_ACC, NPU_DONE);
    signal npu_state : npu_state_t;

begin

    -- ===========================================================
    -- Multiplier Instantiation
    -- TODO: gate mul_start so it only pulses in NPU_IDLE when
    --       npu_start='1', not continuously.
    -- ===========================================================
    mul0 : multiplier port map (
        clk    => clk,
        rst    => rst,
        start  => mul_start,
        a      => op_a,
        b      => op_b,
        done   => mul_done,
        result => mul_result
    );

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
        sat_flag => sat_flag,
        neg_flag => neg_flag
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
    -- TODO: implement this process — stubs provided below
    -- ===========================================================
    process(clk, rst)
    begin
        if rst = '1' then
            npu_state  <= NPU_IDLE;
            npu_done   <= '0';
            acc_en     <= '0';
            mul_start  <= '0';
            result_reg <= (others => '0');

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
                        mul_start <= '1';          -- kick off multiplier
                        npu_state <= NPU_MUL_WAIT;
                    end if;

                -- -------------------------------------------------
                -- MUL_WAIT: stall here until multiplier finishes
                -- TODO: mul_done timing depends on your multiplier
                --       implementation — verify cycle count
                -- -------------------------------------------------
                when NPU_MUL_WAIT =>
                    if mul_done = '1' then
                        acc_en    <= '1';          -- latch product into accumulator
                        npu_state <= NPU_ACC;
                    end if;

                -- -------------------------------------------------
                -- ACC: accumulator latched, capture result
                -- TODO: decide here whether to use acc_out or relu_out
                --       For MAC opcode: store acc_out (pre-ReLU)
                --       For RELU opcode: store relu_out (post-ReLU)
                --       Current default: stores relu_out
                -- -------------------------------------------------
                when NPU_ACC =>
                    result_reg <= relu_out;        -- TODO: switch to acc_out if needed
                    npu_done   <= '1';
                    npu_state  <= NPU_DONE;

                -- -------------------------------------------------
                -- DONE: result valid for 1 cycle, then back to IDLE
                -- -------------------------------------------------
                when NPU_DONE =>
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
    npu_result <= (31 downto 16 => result_reg(15)) & result_reg;

end Behavior;
