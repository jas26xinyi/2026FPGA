param([switch]$SkipImplementation)
$ErrorActionPreference = 'Stop'
$vivado = 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado 2023.2 not found at $vivado" }
Push-Location $root
try {
    foreach ($test in @('tb_lock_controller','tb_keypad_scanner','tb_frame_capture','tb_mosaic_renderer','tb_flash_default_fail','tb_flash_journal')) {
        & $vivado -mode batch -nolog -nojournal -source scripts/run_tests.tcl -tclargs $test
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
    }
    if (-not $SkipImplementation) {
        & $vivado -mode batch -nolog -nojournal -source scripts/build_all.tcl
        if ($LASTEXITCODE -ne 0) { throw 'Vivado build failed' }
    }
} finally { Pop-Location }
