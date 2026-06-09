# RISC-NPU — Complete Project Context & Handoff Document

> **For any AI or collaborator continuing this work:**
> Read this entire document before touching any file.
> Every design decision made, every tradeoff considered, every paper cited,
> and every line of VHDL written has a reason documented here.

---

## 0. Quick Identity

| Field | Value |
|---|---|
| **Project name** | RISC-NPU |
| **Student** | Jaundel Simon, jaundel.simon@torontomu.ca |
| **Program** | Computer Engineering, Toronto Metropolitan University |
| **Hardware target** | Altera Cyclone IV E — EP4CE115F29C7 |
| **Toolchain** | Intel Quartus Prime Lite 25.1std (free) |
| **Language** | VHDL (IEEE std_logic_1164, std_logic_arith, std_logic_unsigned) |
| **Project folder** | `C:\Users\jaund\Downloads\RISC-NPU\` |
| **Status as of 2026-06-08** | Skeleton complete. NPU stubs need implementation. |

---

## 1. One-Sentence Thesis

> **A general-purpose CPU becomes a neural accelerator when its ISA is extended with MAC, RELU, and VLOAD opcodes that dispatch multiply-accumulate operations to a dedicated NPU co-processor — measurable by comparing software dot-product cycle counts against hardware MAC instruction cycle counts on the same FPGA.**

This is the claim the finished project proves. Everything in the codebase exists to demonstrate this one thing.

---

## 2. Why This Project Exists

### 2.1 Portfolio Motivation

Jaundel is a computer engineering student building a hardware ML portfolio in the style of otoro.net and distill.pub — work that is visually compelling, technically grounded, and portfolio-ready for ML hardware roles and graduate school applications.

The hardware ML space (Groq, Tenstorrent, Cerebras, Google TPU, Nvidia) is hiring people who can work at the intersection of computer architecture and machine learning. The canonical proof of that ability is: *"I extended a CPU ISA to accelerate neural network inference and benchmarked the result."*

This project is that proof. It is not a toy. It needs to produce a real cycle-count comparison that demonstrates measurable speedup.

### 2.2 Why RISC-NPU Specifically

Seven other project ideas were evaluated (see `npu-project-ideas.md`). RISC-NPU was selected as the primary project because:

1. **Feasibility**: The CPU (lab6final) already exists and compiles. The NPU stubs (Neural-Processing-Unit-Core) already exist. The integration hook (`DATA_MUX "11"` slot in `data_path.vhd`) was already identified. No greenfield development required.
2. **Thesis clarity**: One claim, one number — cycle count with MAC instruction vs. cycle count in software.
3. **Research grounding**: Direct parallels to published FPGA ISA extension work (see Section 4).
4. **Extensibility**: RISC-NPU naturally extends into HARDMAX+Observatory (sparsity exploitation) if time allows.

---

## 3. The Two Source Projects

### 3.1 lab6final — The 32-bit CPU (DONE, DO NOT BREAK)

Location: `C:\Users\jaund\Downloads\lab6final\lab6\`

This is a working, previously-submitted 32-bit CPU built in Quartus 16.0 for the EP4CE115F29C7. It compiles and runs correctly. All files from this project have been copied into RISC-NPU.

**Architecture summary:**

```
cpu1.vhd (top-level)
├── Data_Path (data_path.vhd)
│   ├── IR register (register32.vhd)
│   ├── PC (PC.vhd)
│   ├── Register A (register32.vhd)
│   ├── Register B (register32.vhd)
│   ├── Data Memory 256×32 (data_mem.vhd)
│   ├── ALU (alu.vhd)
│   │   └── adder32 → adder16 → adder4 → fulladd
│   ├── LZE / UZE / RED (immediate extension)
│   ├── mux2to1, mux4to1
│   └── DATA_MUX 4-to-1:
│       "00" = DATA_IN       (external / instruction memory)
│       "01" = data_mem_out  (data memory read)
│       "10" = ALU_out       (ALU result)
│       "11" = (others=>'0') ← *** THIS IS THE NPU HOOK ***
└── Control_New (Control_New.vhd)
    └── 3-state FSM: state_0=Fetch, state_1=Execute1, state_2=Execute2
```

**Key signals to know:**
- `out0` / `statusC` — carry flag (also connected to `dOutC`)
- `out1` / `statusZ` — zero flag (also connected to `dOutZ`)
- `outIR` — current instruction register output (fed into Control)
- `enpd` — enable signal from reset_circuit (CPU runs when this is '1')
- `pclr` — PC clear signal from reset_circuit

**Existing ISA (4-bit primary opcode, bits 31:28):**

| Opcode | Mnemonic | Description |
|---|---|---|
| 0000 | LDIA | Load immediate into A (lower 28 bits zero-extended) |
| 0001 | LDIB | Load immediate into B |
| 0010 | STA  | Store A to memory[IR[7:0]] |
| 0011 | STB  | Store B to memory[IR[7:0]] |
| 0100 | OR   | A ← A OR B |
| 0101–0110 | (branch support) | Used in state_2 |
| 1001 | LDA  | Load A from memory[IR[7:0]] |
| 1010 | LDB  | Load B from memory[IR[7:0]] |

**Extended 8-bit opcodes (bits 31:24, used in state_2):**

| Opcode (8-bit) | Mnemonic | Operation |
|---|---|---|
| 01110000 | ADD  | A ← A + B |
| 01110010 | SUB2 | A ← A - B (variant) |
| 01110011 | ADD2 | A ← A + B (variant) |
| 01110100 | SLL  | A ← A << 1 |
| 01111111 | SRL  | A ← A >> 1 |
| 01111001 | AND  | A ← A AND B |
| 01111110 | SUB  | A ← A - B |
| 01111101 | OR2  | A ← A OR B (variant) |
| 01110101 | CLRA | Clear A |
| 01110110 | CLRB | Clear B |
| 01110111 | CLRC | Clear carry |
| 01111000 | CLRZ | Clear zero |
| 01111010 | JZ   | Jump if zero |
| 01111100 | JC   | Jump if carry |

### 3.2 Neural-Processing-Unit-Core — The NPU Stubs

Location: `C:\Users\jaund\Downloads\Neural-Processing-Unit-Core\npu\`

This repository contains stub VHDL files with only TODO comments. These are the building blocks for the NPU. All have been copied into RISC-NPU.

| File | Purpose | Status |
|---|---|---|
| `multiplier.vhd` | Iterative signed 8×8 shift-add, start/done interface | **TODO — implement first** |
| `accumulator.vhd` | 16-bit saturating accumulator, sat_flag, neg_flag | **TODO — implement second** |
| `relu.vhd` | Combinational: dout = max(0, din) for signed(15:0) | **TODO — implement third** |
| `weights_bias.vhd` | Signed weight/bias constants | TODO — optional for v1 |
| `counter.vhd` | General-purpose counter | TODO — optional for v1 |

---

## 4. Research Papers That Back This Project

These papers were found by browsing 250+ arXiv papers via Chrome search across 8 query sets. All specific numbers below were read directly from abstracts.

### 4.1 Primary Justification Papers (RISC-NPU directly)

**[P1] arXiv:2511.06955** — *FPGA-based RISC-V ISA Extension for Neural Network Acceleration* (Nov 2025)
- Platform: PYNQ-Z2 (Zynq-7000, comparable to Cyclone IV class)
- Result: **2.14× speedup**, **49.1% energy reduction**, **38.8% DSP utilization**
- Relevance: Direct precedent for the RISC-NPU thesis. Shows that ISA extension to dispatch MAC operations to custom hardware produces measurable speedup on FPGA. This paper is the benchmark to cite when explaining *why* ISA extensions work.
- Key finding: DSP utilization stays below 40% even with the extension — meaning there is headroom on the Cyclone IV for both CPU and NPU.

**[P2] arXiv:2508.01800** — *MARVEL: Custom RISC-V Extensions for Lightweight AI* (2025)
- Shows that custom ISA extensions for AI inference are a mature technique, not experimental.
- Relevance: Situates RISC-NPU in the context of a broader trend toward AI-extended ISAs.

**[P3] arXiv:2508.12846** — *IzhiRISC-V: Custom ISA Extension for Spiking Neural Networks* (DAC 2026)
- Implements a custom ISA extension for SNN (spiking neural network) computation.
- Relevance: Shows that custom ISA extensions are appearing even at top venues (DAC) for neural computation beyond standard CNNs — validates the thesis direction.

**[P4] arXiv:2504.19659** — *HW/SW Co-Design of RISC-V Extensions for Sparse DNNs* (2025)
- Focuses on hardware-software co-design where ISA extensions exploit activation sparsity.
- Relevance: Connects RISC-NPU to the future HARDMAX extension. If RISC-NPU is built first, HARDMAX is a natural second paper/project that this paper supports.

### 4.2 Supporting Architecture Papers

**[P5] arXiv:2402.00395** — *ONE-SA: A One-Stop Systolic Array for DNNs* (DATE 2024)
- Result: **25.73× speedup vs CPU**, **5.21× speedup vs GPU**, **<1.5% extra BRAMs/LUTs**
- Relevance: Systolic array architecture is the gold standard for hardware MAC acceleration. ONE-SA shows the performance ceiling. RISC-NPU is the simpler entry point; SystolicNPU (another idea) is the step toward this.

**[P6] arXiv:2409.03508** — *DSP Optimization for FPGA Systolic Matrix Engines* (FPL 2024)
- Targets TPUv1 and Vitis AI DPU architectures on FPGA.
- Relevance: Shows that systolic approaches on Cyclone IV-class FPGAs are feasible with careful DSP mapping.

**[P7] arXiv:2603.14988** — *bitSMM: Bit-Serial Matrix Multiplication* (CGRA4HPC 2026)
- Relevance: Alternative to DSP-based multiplication. Bit-serial approaches are area-efficient on FPGAs, which is relevant to the shift-add multiplier design in `multiplier.vhd`.

### 4.3 Papers Supporting Future Extensions (HARDMAX, Observatory)

**[P8] arXiv:2511.03079** — *LogicSparse: Engine-Free Unstructured Sparsity on FPGAs* (ICFPT 2025)
- Implements MAC suppression for sparse networks without a dedicated sparsity engine.
- Relevance: Direct precedent for HARDMAX. The zero_out gating mechanism in HARDMAX mirrors the LogicSparse approach.

**[P9] arXiv:2512.21777** — *Online Learning ELM on FPGA* (Dec 2025)
- Result: Reduces training complexity from **O(M³) to O(M)**, only **3.6% accuracy degradation**
- Relevance: Supports the AdaptiveSparse-NPU extension (Learning FPGA idea). Shows that on-FPGA learning with accuracy-complexity tradeoff is viable.

**[P10] arXiv:2603.24186** — *TsetlinWiSARD: On-Chip Training on FPGAs* (DAC 2026)
- On-chip training at DAC 2026 — shows the field is actively moving toward hardware that learns.
- Relevance: Future extension support.

**[P11] arXiv:2605.18003** — *Spiker-LL: Adaptive Local Learning in SNNs on FPGA* (May 2026)
- Most recent paper found. Adaptive learning in hardware, May 2026.
- Relevance: Cutting-edge support for the AdaptiveSparse-NPU concept.

### 4.4 Papers for BNN and Attention Extensions (Other Ideas)

**[P12] arXiv:2512.19304** — *BNN for Handwritten Digit Recognition on FPGA* (Dec 2025)
- Implements XNOR+popcount BNN entirely on FPGA.
- Relevance: Supports Binary Thunder (project idea #4). Zero DSP blocks for inference is the key claim.

**[P13] arXiv:2409.14023** — *FAMOUS: Attention Mechanism Accelerator on UltraScale+* (ICFPT 2024)
- Full attention head in hardware on Xilinx UltraScale+.
- Relevance: Supports "One Attention Head in Silicon" (project idea #5).

**[P14] arXiv:2501.13379** — *Approximate Softmax Evaluation for DNNs* (LASCAS 2026)
- Approximation methods for softmax that are hardware-friendly.
- Relevance: The max-subtraction softmax approximation used in the attention idea.

**[P15] arXiv:2408.10243** — *TrIM: Triangular Input Movement Systolic Array* (TCAS-I 2024)
- Novel systolic array that reduces data movement overhead.
- Relevance: Supports SystolicNPU (project idea #6).

---

## 5. RISC-NPU Architecture

### 5.1 Block Diagram (ASCII)

```
                    ┌─────────────────────────────────────────────┐
                    │                   cpu1.vhd                   │
                    │                                              │
                    │  ┌──────────────────────────────────────┐   │
                    │  │           data_path.vhd              │   │
                    │  │                                      │   │
  dataIn ──────────►│  │  DATA_MUX (4-to-1)                   │   │
                    │  │  "00" ← DATA_IN                      │   │
                    │  │  "01" ← data_mem_out                 │   │
                    │  │  "10" ← ALU_out                      │   │
  npu_result ──────►│  │  "11" ← npu_result  ◄── HOOK        │   │
                    │  │         │                            │   │
                    │  │         ▼                            │   │
                    │  │      data_bus_s ──► Reg A / Reg B    │   │
                    │  │                         │            │   │
                    │  └──────────────────────────────────────┘   │
                    │              │  reg_a_out[7:0]               │
                    │              │  reg_b_out[7:0]               │
                    │              ▼                               │
                    │  ┌───────────────────────┐                  │
                    │  │      npu_core.vhd      │                  │
                    │  │                       │                  │
  npu_start ───────►│  │  multiplier.vhd       │                  │
                    │  │  accumulator.vhd      │──► npu_result    │
  npu_done  ◄───────│  │  relu.vhd             │                  │
                    │  │                       │                  │
                    │  └───────────────────────┘                  │
                    │                                              │
                    │  ┌──────────────────────────────────────┐   │
                    │  │         Control_New.vhd               │   │
                    │  │  state_0 → state_1 → state_2          │   │
                    │  │                    ↘ state_3          │   │
                    │  │  (MAC_WAIT: loop until npu_done='1')  │   │
                    │  └──────────────────────────────────────┘   │
                    └─────────────────────────────────────────────┘
```

### 5.2 New ISA Extension

Three new opcodes added for RISC-NPU. 4-bit primary opcode (bits 31:28):

| Opcode | Mnemonic | Encoding | Cycles | Operation |
|---|---|---|---|---|
| 1011 | MAC | `1011_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx` | ~12 (variable) | Reg_A ← NPU(A[7:0] × B[7:0]), result sign-extended to 32 bits |
| 1100 | RELU | `1100_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx` | 1 | Reg_A ← max(0, Reg_A) |
| 1101 | VLOAD | `1101_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx` | 1–2 | Load immediate into A or B (maps to existing LDA immediate path) |

**MAC instruction timing (state machine):**
```
Clock:    1      2         3..N+2       N+3         N+4
State:  state_0  state_1   state_3     state_3      state_0
Action: Fetch   Decode    Stall(×N)   Latch result  Next fetch
                npu_start  (wait for   DATA_MUX="11"
                ='1'       npu_done)   ld_A='1'
```
N = number of cycles the multiplier takes (typically 8–10 for iterative shift-add).

### 5.3 Signal Routing: How NPU Result Gets Into Register A

This is the critical path to understand:

1. `npu_core` computes result, asserts `npu_done_s = '1'`
2. `Control_New` sees `npu_done = '1'` in `state_3`, sets `DATA_MUX = "11"` and `ld_A = '1'`
3. `data_path` DATA_MUX routes `npu_result` port → `data_bus_s`
4. `data_bus_s` feeds Register A's D input
5. `ld_A = '1'` on rising clock edge → Register A latches the NPU result
6. `Control_New` state machine transitions `state_3 → state_0` (back to Fetch)

### 5.4 Operand Loading Convention

Before issuing a MAC instruction, the CPU program must load operands:
```
LDIA  op_a_value    ; reg A[7:0] = multiplicand
LDIB  op_b_value    ; reg B[7:0] = multiplier
MAC                 ; reg A = NPU(A[7:0] × B[7:0])
```

Only the lower 8 bits of A and B are used as operands (see `cpu1.vhd` NPU instantiation:
`op_a => reg_a_out(7 DOWNTO 0), op_b => reg_b_out(7 DOWNTO 0)`).

---

## 6. Current Codebase State (as of 2026-06-08)

### 6.1 File Inventory

| File | Source | Status | Notes |
|---|---|---|---|
| `cpu1.vhd` | Modified from lab6 | **Skeleton — compiles with stubs** | Added npu_core instantiation, npu signals |
| `data_path.vhd` | Modified from lab6 | **Skeleton — compiles** | npu_result port added, DATA_MUX "11" wired |
| `Control_New.vhd` | Modified from lab6 | **Skeleton — needs testing** | state_3 added, MAC opcode stub, npu_start/done ports |
| `npu_core.vhd` | New | **Skeleton — will not compile** | Instantiates unimplemented components |
| `multiplier.vhd` | From NPU repo | **TODO stub — one comment line** | Must implement first |
| `accumulator.vhd` | From NPU repo | **TODO stub — one comment line** | Must implement second |
| `relu.vhd` | From NPU repo | **TODO stub — one comment line** | Must implement third |
| `weights_bias.vhd` | From NPU repo | TODO stub | Optional for v1 |
| `counter.vhd` | From NPU repo | TODO stub | Optional for v1 |
| `alu.vhd` | Copied from lab6 | **Done — do not modify** | 32-bit, 6 ops |
| `adder32/16/4.vhd` | Copied from lab6 | **Done — do not modify** | Ripple-carry hierarchy |
| `fulladd.vhd` | Copied from lab6 | **Done — do not modify** | 1-bit full adder |
| `add.vhd` | Copied from lab6 | **Done — do not modify** | |
| `LZE/UZE/RED.vhd` | Copied from lab6 | **Done — do not modify** | Immediate extension |
| `PC.vhd` | Copied from lab6 | **Done — do not modify** | Program counter |
| `mux2to1.vhd` | Copied from lab6 | **Done — do not modify** | |
| `mux4to1.vhd` | Copied from lab6 | **Done — do not modify** | |
| `register32.vhd` | Copied from lab6 | **Done — do not modify** | |
| `data_mem.vhd` | Copied from lab6 | **Done — do not modify** | 256×32-bit data memory |
| `reset_circuit.vhd` | Copied from lab6 | **Done — do not modify** | Power-on reset |
| `system_memory.vhd` | Copied from lab6 | **Done — do not modify** | Instruction memory |
| `system_memory.mif` | Copied from lab6 | **Must update for benchmark** | Write test program here |
| `system_memory.qip` | Copied from lab6 | Done | Quartus IP reference |
| `RISC-NPU.qpf` | Created by Quartus | Done | Project file |
| `RISC-NPU.qsf` | Created by Quartus + updated | Done | All source files registered |

### 6.2 Known Issues and Caveats

**Issue 1: MEM_ADDR type mismatch**
`data_path.vhd` declares `MEM_ADDR : out unsigned(7 downto 0)` but `cpu1.vhd` component declaration uses `STD_LOGIC_VECTOR(7 DOWNTO 0)`. This existed in the original lab6 and may cause a Quartus warning. One of the two needs to be made consistent. Recommend changing `cpu1.vhd` component declaration to `unsigned(7 DOWNTO 0)`.

**Issue 2: npu_core will not compile until stubs are implemented**
The project will fail compilation until `multiplier.vhd`, `accumulator.vhd`, and `relu.vhd` are implemented. Quartus will complain about empty entity bodies.

**Issue 3: out7 / out6 signals in cpu1.vhd**
The original lab6 `cpu1.vhd` assigns `wen_mem <= out7` and `en_mem <= out6` but `out7` and `out6` are declared and never driven (they default to 'U'). This was present in the original code and was inherited. These outputs appear to be debug/monitoring outputs that were wired but unused. Do not fix unless it causes compilation errors.

**Issue 4: Instruction_sig declared inside architecture body vs. process**
In `Control_New.vhd`, `Instruction_sig` is a concurrent signal driven by `INST(31 DOWNTO 28)`. It is read inside both the combinational process and the state transition process. This is correct VHDL but ensure both processes include `Instruction_sig` in their sensitivity lists.

---

## 7. Implementation Guide (Ordered TODO List)

### Step 1: Implement multiplier.vhd

The multiplier is the bottleneck. Everything else waits for it.

**Specification:**
- Inputs: `a` (8-bit signed), `b` (8-bit signed), `start` (1-bit), `clk`, `rst`
- Outputs: `result` (16-bit signed), `done` (1-bit)
- Algorithm: Iterative shift-and-add (Booth or simple shift-add)
- Timing: Assert `done` for exactly 1 cycle when result is valid, approximately 8–10 cycles after `start`

**Simple shift-add algorithm in hardware:**
```
On start='1': load a_reg = a, b_reg = b, count = 0, acc = 0
Each cycle: if b_reg[0]='1', acc += a_reg
            a_reg <<= 1
            b_reg >>= 1
            count++
            if count = 8: done='1', result = acc[15:0]
```

**Port names to use** (match the component declaration in `npu_core.vhd`):
```vhdl
entity multiplier is
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        start  : in  std_logic;
        a      : in  std_logic_vector(7 downto 0);
        b      : in  std_logic_vector(7 downto 0);
        done   : out std_logic;
        result : out std_logic_vector(15 downto 0)
    );
end entity;
```

### Step 2: Implement accumulator.vhd

**Specification:**
- Inputs: `clk`, `rst`, `en` (load enable), `data_in` (16-bit)
- Outputs: `q` (16-bit accumulated sum), `sat_flag` (overflow), `neg_flag` (negative)
- Behavior: On `en='1'`, q <= q + data_in. On `rst='1'`, q <= 0. Saturate at ±32767.

**Port names to use** (match `npu_core.vhd`):
```vhdl
entity accumulator is
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        data_in  : in  std_logic_vector(15 downto 0);
        q        : out std_logic_vector(15 downto 0);
        sat_flag : out std_logic;
        neg_flag : out std_logic
    );
end entity;
```

### Step 3: Implement relu.vhd

**Specification:**
- Combinational (no clock)
- Input: `din` (signed 16-bit)
- Output: `dout` = max(0, din)
- If din[15]='1' (negative), dout = 0. Else dout = din.

**Port names to use** (match `npu_core.vhd`):
```vhdl
entity relu is
    port(
        din  : in  std_logic_vector(15 downto 0);
        dout : out std_logic_vector(15 downto 0)
    );
end entity;
```

**Implementation (3 lines):**
```vhdl
dout <= (others => '0') when din(15) = '1' else din;
```

### Step 4: Verify npu_core.vhd compiles

After Steps 1–3, `npu_core.vhd` should compile. Open Quartus, run Analysis & Synthesis. Expected: warnings about unused signals (sat_flag, neg_flag not currently consumed by cpu1), not errors.

### Step 5: Fix the MEM_ADDR type mismatch

In `cpu1.vhd`, change the Data_Path component declaration:
```vhdl
-- Change this:
MEM_ADDR : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
-- To this:
MEM_ADDR : OUT unsigned(7 DOWNTO 0);
```
Or add `use ieee.numeric_std.all` and use `std_logic_vector` everywhere with explicit casts. Pick one and be consistent.

### Step 6: Simulate npu_core standalone

Before integrating, simulate `npu_core.vhd` in Quartus Simulation or ModelSim:
- Apply `start='1'` for 1 cycle with `op_a = 0x03, op_b = 0x04`
- Wait for `npu_done='1'`
- Verify `npu_result = 0x0000000C` (sign-extended 12)

### Step 7: Write the benchmark program in system_memory.mif

The `.mif` file holds the instruction memory. Write a program that:

**Software version (cycles A):**
```
; Dot product: [3,5,7] · [2,4,6] = 6+20+42 = 68
; Uses only ALU — no MAC instruction
LDIA 3       ; A = 3
LDIB 2       ; B = 2
MUL_SW:      ; multiply by repeated addition (no hardware MUL)
  ... (loop)
ADD          ; accumulate
... (repeat for other pairs)
STA 0x10     ; store result to memory[0x10]
```

**Hardware version (cycles B):**
```
; Same dot product using MAC instruction
LDIA 3       ; A = 3
LDIB 2       ; B = 2
MAC          ; A = NPU(3 × 2) = 6
LDIA 5       ; A = 5 (but need to preserve accumulation...)
...
```

**Cycle counting approach:** Use a hardware cycle counter (counter.vhd, optional) or count manually by simulation. The key number to report is: **software cycle count ÷ hardware cycle count = speedup factor.**

For a 3-element dot product, software multiply-by-addition requires approximately 9×8 = 72 cycles just for the multiplications. Hardware MAC requires ~12 cycles per multiplication. Expected speedup: **~6×** for multiply, with accumulation overhead reducing it to ~3–4× end-to-end.

### Step 8: Full compile and timing analysis

Run full Quartus compilation (not just Analysis & Synthesis). Check:
- **Fmax**: Should be >50 MHz for the CPU, possibly lower with NPU. Report the number.
- **Logic utilization**: Report LEs used / 114480 available (Cyclone IV E EP4CE115F29C7)
- **DSP utilization**: This is the key metric. The shift-add multiplier uses zero DSPs.

### Step 9: Write the portfolio writeup

The finished project needs:
1. Architecture diagram (use the ASCII one in Section 5.1 as a starting point)
2. The single cycle-count table: Software vs. MAC instruction, 3 different input sizes
3. Quartus utilization screenshot
4. Simulation waveform showing npu_done pulsing and result appearing on npu_result

---

## 8. Thesis Statement (Full Version)

> A general-purpose CPU can be extended to perform neural network multiply-accumulate operations more efficiently than software emulation by adding dedicated MAC hardware and routing its result through the existing data bus. Using an Altera Cyclone IV E FPGA, we extend a 32-bit CPU with a MAC opcode (1011) that dispatches 8×8 signed multiplication to an NPU co-processor, stalls the pipeline via a new MAC_WAIT state (state_3), and returns the result to the register file through the pre-existing DATA_MUX integration hook. Benchmarking a 3-element dot product, we demonstrate a [N]× reduction in execution cycles compared to software-emulated multiplication, with zero DSP block utilization, demonstrating that hardware-accelerated MAC is achievable in an FPGA soft-CPU with minimal architectural disruption.

Fill in [N] after running the benchmark program.

---

## 9. Why This Thesis Is Novel (the "Why Hasn't This Been Done?" Answer)

Most FPGA accelerators are standalone — they don't integrate with a CPU the student built themselves. The novelty of this project is:

1. **End-to-end ownership**: The CPU is original student work (lab6), not a purchased IP core. The NPU is original student work. The integration is original student work. No black boxes.
2. **Integration at the ISA level**: The NPU is not a memory-mapped peripheral (which is the easy approach). It is an ISA extension — the CPU's control FSM directly manages the NPU's start/done handshake and stalls the pipeline. This is how real hardware (RISC-V Zicond, ARM NEON) works.
3. **The DATA_MUX hook**: The integration point (`DATA_MUX "11"` was `(others => '0')` in the original CPU) shows that the original CPU architecture anticipated extension. This is a clean, defensible design story.

---

## 10. Project Rank Among All Ideas Considered

Eight project ideas were evaluated. RISC-NPU was ranked #5 in terms of raw impressiveness but #1 in terms of feasibility × thesis clarity × completion likelihood. The full ranking was:

1. AdaptiveSparse-NPU (HARDMAX + Learning + Observatory) — highest ceiling, hardest to finish
2. SystolicNPU — architecturally impressive, moderate difficulty
3. HARDMAX + Observatory (no learning) — clean thesis, medium difficulty
4. One Attention Head in Silicon — industry-relevant, medium-high difficulty
5. **RISC-NPU** ← **this project** — best risk-adjusted choice
6. Binary Thunder — fast to build, memorable result
7. SIMD CPU — weakest thesis of the group

RISC-NPU was chosen because a finished RISC-NPU beats an unfinished AdaptiveSparse-NPU every time.

---

## 11. Extension Roadmap (After RISC-NPU Is Done)

If RISC-NPU is completed with time remaining, the natural extensions are:

**Extension A — Neuron Observatory (low effort, high visual impact):**
Add a 16-entry trace FIFO that captures NPU internal signals (acc_out, relu_out, zero_out) each time a MAC executes. Add a `TRACE_READ` opcode that drains the FIFO over UART. Write a Python terminal that renders a live activation heatmap. This requires no changes to the CPU architecture — only additions to npu_core.

**Extension B — HARDMAX (medium effort, stronger thesis):**
Add a `zero_out` flag to each ReLU unit (zero_out = '1' when relu_out = 0). Gate subsequent MAC start signals with this flag. Add counters `mac_theoretical` and `mac_actual`. Report MAC savings over UART. This is the sparsity exploitation paper.

**Extension C — AdaptiveSparse-NPU (high effort, highest impact):**
Add writable weight RAM (replace weight constants with a BRAM). Implement weight perturbation (random search): perturb one weight, measure loss decrease, keep or reject. Show that MAC savings increase as the network converges. This is the full learning + sparsity story. See the AdaptiveSparse-NPU thesis in the conversation history for the complete architecture.

---

## 12. Key Design Decisions and Why

| Decision | Alternative Considered | Reason for Choice |
|---|---|---|
| Shift-add multiplier (no DSPs) | Use FPGA DSP blocks | Zero DSP utilization is a portfolio talking point. Also demonstrates that the result comes from custom logic, not vendor IP. |
| state_3 MAC_WAIT in FSM | Handshake via memory-mapped register | ISA-level stall is cleaner and shows real pipeline design knowledge. Memory-mapped would require an extra LDA/STA per MAC call. |
| 8-bit operands from register lower bits | Full 32-bit multiplication | 8×8→16 fits in a simple shift-add. A 32×32 multiplier would take 32 cycles minimum and overflow into 64-bit result requiring more register width changes. 8-bit is sufficient to demonstrate the concept and matches the NPU stub specification. |
| Result returned via DATA_MUX "11" | Separate output register/port | The DATA_MUX "11" slot was already wired to `(others=>'0')` in the original CPU — it was clearly an intentional integration hook. Using it requires zero new wiring to the register file. |
| ReLU applied by default in NPU | Separate RELU instruction | The current skeleton applies ReLU by default in `npu_core.vhd`. This can be changed by routing `acc_out` instead of `relu_out` in the NPU_ACC state. Decision not yet finalized — mark as TODO. |
| Fixed weights (no learning) | On-chip backpropagation | Hardware backpropagation requires fixed-point gradient math which can fail silently. Fixed weights + Python pre-training is safer and still demonstrates the hardware acceleration claim. |

---

## 13. Vocabulary Reference

Terms used throughout the codebase and this document:

| Term | Definition in this project |
|---|---|
| **MAC** | Multiply-Accumulate: a × b + acc. The fundamental operation of neural network inference. |
| **ISA extension** | Adding new opcodes to the CPU instruction set that dispatch to custom hardware. |
| **DATA_MUX** | The 4-to-1 multiplexer in data_path.vhd that selects what value appears on the data bus. Controlled by `DATA_MUX[1:0]` from Control_New. |
| **state_3** | New FSM state added to Control_New. CPU stalls here until npu_done='1'. Equivalent to a multi-cycle instruction in a pipelined CPU. |
| **npu_start** | 1-cycle pulse from Control_New to npu_core. Kicks off the multiply-accumulate sequence. |
| **npu_done** | 1-cycle pulse from npu_core to Control_New. Signals that npu_result is valid and can be latched into register A. |
| **npu_result** | 32-bit sign-extended output of npu_core. Connected to DATA_MUX "11" slot in data_path. |
| **zero_out** | (Future extension) Flag asserted when relu output is exactly zero. Used in HARDMAX sparsity gating. |
| **T output** | 3-bit debug output from Control_New showing current FSM state. "001"=state_0, "010"=state_1, "100"=state_2, "111"=state_3. |

---

## 14. Contact and Repository Context

- **Student**: Jaundel Simon — jaundel.simon@torontomu.ca
- **CPU source**: `C:\Users\jaund\Downloads\lab6final\lab6\` (original, do not modify)
- **NPU stubs source**: `C:\Users\jaund\Downloads\Neural-Processing-Unit-Core\npu\` (original, do not modify)
- **This project**: `C:\Users\jaund\Downloads\RISC-NPU\` (active development)
- **Project ideas document**: `C:\Users\jaund\Downloads\lab6final\npu-project-ideas.md` (all 8 ideas with full research backing)

---

*Last updated: 2026-06-08. Written by Claude (Anthropic) in Cowork mode as a handoff document for continued AI-assisted development.*
