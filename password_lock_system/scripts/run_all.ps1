param(
    [switch]$SkipImplementation,
    [switch]$EnableCamera
)
$ErrorActionPreference = 'Stop'
$vivado = 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado 2023.2 not found at $vivado" }
Push-Location $root
try {
    $previousCameraSetting = $env:ENABLE_CAMERA
    $env:ENABLE_CAMERA = if ($EnableCamera) { '1' } else { '0' }
    $tests = @('tb_lock_controller','tb_alarm_buzzer','tb_keypad_scanner','tb_sevenseg_display','tb_flash_default_fail','tb_flash_journal')
    if ($EnableCamera) {
        $tests += @('tb_frame_capture','tb_mosaic_renderer')
    }
    foreach ($test in $tests) {
        & $vivado -mode batch -nolog -nojournal -source scripts/run_tests.tcl -tclargs $test
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
    }
    if (-not $SkipImplementation) {
        & $vivado -mode batch -nolog -nojournal -source scripts/build_all.tcl
        if ($LASTEXITCODE -ne 0) { throw 'Vivado build failed' }
    }
} finally {
    $env:ENABLE_CAMERA = $previousCameraSetting
    Pop-Location
}
