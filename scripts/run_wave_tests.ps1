$ErrorActionPreference = "Stop"

$licensePath = Join-Path $HOME "questa_lic.dat"

if (-not $env:SALT_LICENSE_SERVER) {
    if (-not (Test-Path $licensePath)) {
        throw "Set SALT_LICENSE_SERVER or place questa_lic.dat at $licensePath"
    }

    $env:SALT_LICENSE_SERVER = $licensePath
}

New-Item -ItemType Directory -Force waves | Out-Null

vcom -2008 `
    multiplier.vhd accumulator.vhd relu.vhd npu_core.vhd `
    tb\multiplier_tb.vhd tb\accumulator_tb.vhd tb\relu_tb.vhd tb\npu_core_tb.vhd

vsim -c multiplier_tb  -do "vcd file waves/multiplier_tb.vcd;  vcd add -r /multiplier_tb/*;  run -all; quit -f"
vsim -c accumulator_tb -do "vcd file waves/accumulator_tb.vcd; vcd add -r /accumulator_tb/*; run -all; quit -f"
vsim -c relu_tb        -do "vcd file waves/relu_tb.vcd;        vcd add -r /relu_tb/*;        run -all; quit -f"
vsim -c npu_core_tb    -do "vcd file waves/npu_core_tb.vcd;    vcd add -r /npu_core_tb/*;    run -all; quit -f"

Get-ChildItem waves -Filter *.vcd | Select-Object Name, Length, LastWriteTime
