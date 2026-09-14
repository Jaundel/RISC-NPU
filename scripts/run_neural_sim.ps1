param([int]$PixelLimit = 4096, [switch]$Trace)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    $ghdlCommand = Get-Command ghdl -ErrorAction SilentlyContinue
    $ghdl = if ($ghdlCommand) { $ghdlCommand.Source } else {
        Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages') -Directory -Filter 'ghdl.ghdl*' |
            ForEach-Object { Join-Path $_.FullName 'bin/ghdl.exe' } |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $ghdl) { throw 'GHDL is required' }
    $workRoot = Join-Path ([IO.Path]::GetTempPath()) ('risc-neural-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workRoot | Out-Null
    New-Item -ItemType Directory -Force artifacts/raw | Out-Null
    $common = @('--std=08', '-fsynopsys', "--workdir=$workRoot")
    $sources = @('multiplier.vhd','accumulator.vhd','relu.vhd','npu_core.vhd',
        'fulladd.vhd','adder4.vhd','adder16.vhd','adder32.vhd','add.vhd',
        'mux2to1.vhd','mux4to1.vhd','register32.vhd','PC.vhd','LZE.vhd','UZE.vhd',
        'RED.vhd','alu.vhd','data_mem.vhd','data_path.vhd','reset_circuit.vhd',
        'Control_New.vhd','cpu1.vhd','neural/generated/neural_program.vhd',
        'neural/neural_image_system.vhd','tb/neural_image_tb.vhd')
    & $ghdl -a @common @sources
    if ($LASTEXITCODE -ne 0) { throw 'Neural RTL analysis failed' }
    $runArgs = @('-r') + $common + @('neural_image_tb', "-gPIXEL_LIMIT=$PixelLimit", '--assert-level=error')
    if ($Trace) {
        $runArgs += '-gOUTPUT_FILE=artifacts/raw/trace-pixels.csv'
        $runArgs += '--vcd=artifacts/raw/neural-trace.vcd'
    }
    & $ghdl @runArgs
    if ($LASTEXITCODE -ne 0) { throw 'Neural RTL execution failed' }
}
finally { Pop-Location }
