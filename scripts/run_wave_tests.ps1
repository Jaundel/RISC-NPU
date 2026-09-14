$ErrorActionPreference = "Stop"

# Native tools do not reliably obey PowerShell's ErrorActionPreference.
# Treat failures and license errors as terminal; never advertise stale VCDs.
function Invoke-CheckedNative {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed (exit $LASTEXITCODE)" }
}

$licensePath = Join-Path $HOME "questa_lic.dat"
$questaBin = "C:\altera_lite\25.1std\questa_fse\win64"
$vcom = (Get-Command vcom -ErrorAction SilentlyContinue).Source
$vsim = (Get-Command vsim -ErrorAction SilentlyContinue).Source

if (-not $vcom) {
    $vcom = Join-Path $questaBin "vcom.exe"
}

if (-not $vsim) {
    $vsim = Join-Path $questaBin "vsim.exe"
}

if (-not (Test-Path $vcom)) {
    throw "Could not find vcom. Add Questa to PATH or update `$questaBin in this script."
}

if (-not (Test-Path $vsim)) {
    throw "Could not find vsim. Add Questa to PATH or update `$questaBin in this script."
}

if (-not $env:SALT_LICENSE_SERVER) {
    if (-not (Test-Path $licensePath)) {
        throw "Set SALT_LICENSE_SERVER or place questa_lic.dat at $licensePath"
    }

    $env:SALT_LICENSE_SERVER = $licensePath
}

New-Item -ItemType Directory -Force waves | Out-Null

Invoke-CheckedNative $vcom @('-2008',
    'multiplier.vhd','accumulator.vhd','relu.vhd','npu_core.vhd',
    'tb/multiplier_tb.vhd','tb/accumulator_tb.vhd','tb/relu_tb.vhd','tb/npu_core_tb.vhd')

Invoke-CheckedNative $vcom @('-2008',
    'fulladd.vhd','adder4.vhd','adder16.vhd','adder32.vhd','add.vhd',
    'mux2to1.vhd','mux4to1.vhd','register32.vhd','PC.vhd',
    'LZE.vhd','UZE.vhd','RED.vhd','alu.vhd','data_mem.vhd','data_path.vhd',
    'reset_circuit.vhd','Control_New.vhd','cpu1.vhd','system_memory.vhd','risc_npu_top.vhd',
    'tb/alu_tb.vhd','tb/reg_test_tb.vhd','tb/cpu_add_tb.vhd','tb/cpu_mac_tb.vhd',
    'tb/bench_tb.vhd','tb/bench_multi_tb.vhd','tb/risc_npu_top_tb.vhd',
    'tb/npu_inference_tb.vhd','tb/cpu_branch_tb.vhd')

$runTag = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDirectory = "waves/$runTag"
New-Item -ItemType Directory -Path $runDirectory | Out-Null
foreach ($test in @('multiplier_tb','accumulator_tb','relu_tb','npu_core_tb',
    'alu_tb','reg_test_tb','cpu_add_tb','cpu_mac_tb','bench_tb','bench_multi_tb',
    'risc_npu_top_tb','npu_inference_tb','cpu_branch_tb')) {
    Invoke-CheckedNative $vsim @('-c',$test,'-do',
        "onerror {quit -code 1}; onbreak {quit -code 1}; vcd file $runDirectory/$test.vcd; vcd add -r /$test/*; run -all; quit -code 0")
}
Get-ChildItem -LiteralPath $runDirectory -Filter *.vcd | Select-Object Name, Length, LastWriteTime
