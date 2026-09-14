# RISC-NPU: reproducible architecture study

The experiments compare complete-program execution across four processor
configurations. The article and downloadable evidence are maintained in
[risc-npu-article](https://github.com/Jaundel/risc-npu-article).

## Published evidence, September 13, 2026

- Kernel run: `artifacts/research/20260913T231450Z` — 592 runs, 1,296 outputs.
- Arithmetic run: `artifacts/verification/20260913T231701Z` — 196,608 product
  checks and 12,294 output-conversion checks across three hardware variants.
- Core fits: `artifacts/synthesis/20260913T231206Z` — four configurations,
  three fitter seeds, Cyclone IV E EP4CE115F29C7, 50 MHz constraints.

The 64-element dense signed dot product takes median 12,648 software cycles,
1,418 staged-iterative cycles, 1,290 fused-iterative cycles, and 778 parallel
cycles. Kernel speedup is 16.26x for parallel; including the common initializer
reduces it to 6.12x. All-zero weights favor software (588 versus 778 cycles).
These are simulation counts, not board observations or energy measurements.

## Reproduction

Requires PowerShell 7 for the Windows regression runner, Python with NumPy/Matplotlib, GHDL with VHDL-2008 and Synopsys-library
compatibility, and Quartus Prime Lite 25.1std for FPGA fitting. The measured
Python figure environment used NumPy 2.3.5 and Matplotlib 3.11.2. The GHDL
version is recorded in the kernel manifest. Run from the repository root:

```powershell
.\scripts\run_ghdl_tests.ps1
python research/run_verification.py --ghdl ghdl
python research/run_experiments.py --ghdl ghdl
python research/run_synthesis.py --quartus "C:/altera_lite/25.1std/quartus/bin64/quartus_sh.exe"
```

If GHDL is not on PATH, replace `ghdl` with its absolute executable path.
Each experiment creates a fresh timestamped directory and reports its name.
Do not edit completed run artifacts. Use the newly reported folders below:

```powershell
python research/validate_study.py --run artifacts/research/RUN --verification artifacts/verification/VERIFY --synthesis artifacts/synthesis/FITS
python research/plot_results.py --run artifacts/research/RUN --verification artifacts/verification/VERIFY --synthesis artifacts/synthesis/FITS --article ../risc-npu-article
```

The validator intentionally checks the full published matrix (592 runs); the
`--smoke` option on the kernel runner is for debugging, not publication.
It checks source and artifact hashes, equivalent fixtures, value-independent
kernel instruction hashes, RAM readback, exact cycle accounting, numeric
reference agreement, and the timing summaries. Changing source requires a new
run, not silently relabeling the previous evidence. Bit-identical regeneration
of plots additionally depends on fonts and Matplotlib versions.

## Boundaries and definitions

- This is a custom ISA, not RISC-V. NINIT reads signed A[15:0]. NMAC reads
  signed A[7:0] and B[7:0]; wide accumulation saturates at signed 32-bit limits.
- Software uses runtime zero skipping and immediate bit masks, not repeated
  addition proportional to the operand magnitude. It is not proven optimal.
- Kernels are dimension-unrolled because the ISA lacks indirect loads/stores.
  Instruction ROM is ideal and external to the fitted core; code size is
  reported separately. Data RAM is included in all core fits.
- Kernel timing starts at its first fetch and ends at output-store retirement.
  The untimed readback tail checks actual data RAM. Cold timing also includes
  reset settling and the common synthetic operand-writing prefix.
- At 10 ns the simulation produces convenient traces, not a claim of 100 MHz
  hardware operation. Fmax is reported separately from Quartus timing models.
- Warm-kernel charts use three uniform signed-byte fixtures. Other input
  families and all raw runs remain in the CSV. Shaded ranges are input ranges,
  not confidence intervals. The density sweep uses realized nonzero counts.
- Dedicated multiplier usage must accompany logic-element comparisons. These
  virtual-pin fits do not include program ROM, physical I/O, or a board run.
- No MMIO superiority, trained-network accuracy, measured energy, or SOTA claim.

## Figures

The plotting script exports six SVG/PNG figures from the archived CSV files:
scaling, cycle accounting, sparsity, setup and code size, FPGA cost, and
output conversion. Figure captions define the axes, samples, timing boundaries,
and analytical overlays. Related research is cited in the article.

## Article packaging

With both repositories checked out side by side, stage the article locally:

```powershell
python research/stage_article.py --article ../risc-npu-article
```

To rebuild the evidence archive from completed runs, use
`research/build_publication.py` with `--run`, `--verification`, `--synthesis`,
and `--article`. It validates the evidence and runs the regression suite before
packaging. Neither script publishes the site.
