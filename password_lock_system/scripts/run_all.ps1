# 一键回归入口：依次启动 11 个独立 Vivado 批处理仿真；默认随后执行完整综合实现。
# -SkipImplementation 仅跑仿真，-DisableRaspberryPiCamera 验证不带 UART 的综合配置。
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
    # 独立进程运行每个 testbench，规避 Windows 上 XSim 连续关闭偶发卡住的问题。
    $tests = @('tb_basic_entry_timeout','tb_basic_admin_save','tb_basic_alarm_policy','tb_lock_controller','tb_temporary_password_generator','tb_alarm_buzzer','tb_rpi_camera_link','tb_keypad_scanner','tb_sevenseg_display','tb_flash_default_fail','tb_flash_journal')
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
