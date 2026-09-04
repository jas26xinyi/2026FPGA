param(
    [switch]$SkipImplementation,
    [switch]$DisableRaspberryPiCamera
)
$ErrorActionPreference = 'Stop'
$vivado = 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado 2023.2 not found at $vivado" }
Push-Location $root
try {
    $previousCameraSetting = $env:ENABLE_RPI_CAMERA
    $env:ENABLE_RPI_CAMERA = if ($DisableRaspberryPiCamera) { '0' } else { '1' }
    $tests = @('tb_lock_controller','tb_temporary_password_generator','tb_alarm_buzzer','tb_rpi_camera_link','tb_keypad_scanner','tb_sevenseg_display','tb_flash_default_fail','tb_flash_journal')
    foreach ($test in $tests) {
        & $vivado -mode batch -nolog -nojournal -source scripts/run_tests.tcl -tclargs $test
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
    }
    if (-not $SkipImplementation) {
        & $vivado -mode batch -nolog -nojournal -source scripts/build_all.tcl
        if ($LASTEXITCODE -ne 0) { throw 'Vivado build failed' }
    }
} finally {
    $env:ENABLE_RPI_CAMERA = $previousCameraSetting
    Pop-Location
}
