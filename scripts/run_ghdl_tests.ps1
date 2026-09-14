$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# License-free regression route.  It includes every testbench, including the
# DE2-115 board wrapper, while leaving the production Quartus sources intact.
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
    $ghdlCommand = Get-Command ghdl -ErrorAction SilentlyContinue
    $ghdl = if ($ghdlCommand) { $ghdlCommand.Source } else { $null }
    if (-not $ghdl) {
        $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        $ghdl = Get-ChildItem -LiteralPath $wingetRoot -Directory -Filter "ghdl.ghdl*" -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "bin\ghdl.exe" } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    }
    if (-not $ghdl) {
        throw "GHDL was not found. Install it with: winget install --id ghdl.ghdl.ucrt64.mcode --exact"
    }

    $workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("risc-npu-ghdl-" + [guid]::NewGuid().ToString("N"))
    $alteraWork = Join-Path $workRoot "altera_mf"
    New-Item -ItemType Directory -Force -Path $workRoot, $alteraWork | Out-Null

    $common = @("--std=08", "-fsynopsys", "--workdir=$workRoot")
    & $ghdl -a --std=08 -fsynopsys --work=altera_mf "--workdir=$alteraWork" tb/ghdl_compat/altera_mf_stub.vhd
    if ($LASTEXITCODE -ne 0) { throw "GHDL compatibility-library analysis failed" }

    $sources = @(
        "multiplier.vhd", "accumulator.vhd", "relu.vhd", "npu_core.vhd",
        "fulladd.vhd", "adder4.vhd", "adder16.vhd", "adder32.vhd", "add.vhd",
        "mux2to1.vhd", "mux4to1.vhd", "register32.vhd", "PC.vhd",
        "LZE.vhd", "UZE.vhd", "RED.vhd", "alu.vhd", "data_mem.vhd", "data_path.vhd",
        "reset_circuit.vhd", "Control_New.vhd", "cpu1.vhd",
        "tb/multiplier_tb.vhd", "tb/accumulator_tb.vhd", "tb/relu_tb.vhd", "tb/npu_core_tb.vhd",
        "tb/alu_tb.vhd", "tb/reg_test_tb.vhd", "tb/cpu_add_tb.vhd", "tb/cpu_mac_tb.vhd",
        "tb/npu_inference_tb.vhd", "tb/cpu_branch_tb.vhd",
        "tb/bench_tb.vhd", "tb/bench_multi_tb.vhd",
        "tb/ghdl_compat/altsyncram.vhd", "system_memory.vhd", "risc_npu_top.vhd", "tb/risc_npu_top_tb.vhd"
    )
    & $ghdl -a @common "-P$alteraWork" @sources
    if ($LASTEXITCODE -ne 0) { throw "GHDL source analysis failed" }

    $tests = @(
        "multiplier_tb", "accumulator_tb", "relu_tb", "npu_core_tb", "alu_tb", "reg_test_tb",
        "cpu_add_tb", "cpu_mac_tb", "bench_tb", "bench_multi_tb", "risc_npu_top_tb",
        "npu_inference_tb", "cpu_branch_tb"
    )

    foreach ($test in $tests) {
        $runArgs = @("-r") + $common + @("-P$alteraWork", $test, "--assert-level=error")
        $output = (& $ghdl @runArgs 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
            throw "$test failed:`n$output"
        }
        if ($test -eq "bench_tb" -and $output -notmatch "bench_tb PASSED") {
            throw "bench_tb did not reach its pass marker:`n$output"
        }
        if ($test -eq "risc_npu_top_tb" -and $output -notmatch "risc_npu_top_tb passed") {
            throw "risc_npu_top_tb did not reach its pass marker:`n$output"
        }
        Write-Host "PASS  $test"
    }

    Write-Host "All $($tests.Count) RISC-NPU GHDL regressions passed. Temporary work directory: $workRoot"
}
finally {
    Pop-Location
}
