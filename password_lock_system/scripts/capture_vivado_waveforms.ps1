# 打开每个 WDB/WCFG 的 Vivado GUI，并截取波形区域保存为 PNG。
# CropLeft/Top/Width/Height 是相对 Vivado 主窗口的裁剪参数，可按显示器缩放调整。
param(
    [string]$OutputRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'simulation_waveforms'),
    [string[]]$CaseIds = @(),
    [int]$CropLeft = 960,
    [int]$CropTop = 150,
    [int]$CropWidth = 1600,
    [int]$CropHeight = 1000
)

$ErrorActionPreference = 'Stop'
$vivado = 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat'
$openScript = Join-Path $PSScriptRoot 'open_waveform_gui.tcl'

if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado not found: $vivado" }

# 条目必须与 generate_waveforms.ps1 的目录和 testbench 名称一致。
$cases = @(
    @{ Id='01'; Dir='01_basic_entry_timeout'; Test='tb_basic_entry_timeout' },
    @{ Id='02'; Dir='02_admin_password_save'; Test='tb_basic_admin_save' },
    @{ Id='03'; Dir='03_error_alarm_policy'; Test='tb_basic_alarm_policy' },
    @{ Id='04'; Dir='04_matrix_keypad'; Test='tb_keypad_scanner' },
    @{ Id='05'; Dir='05_seven_segment'; Test='tb_sevenseg_display' },
    @{ Id='06'; Dir='06_alarm_buzzer'; Test='tb_alarm_buzzer' },
    @{ Id='07'; Dir='07_flash_default_failure'; Test='tb_flash_default_fail' },
    @{ Id='08'; Dir='08_flash_dual_journal'; Test='tb_flash_journal' },
    @{ Id='09'; Dir='09_extra_random_password'; Test='tb_temporary_password_generator' },
    @{ Id='10'; Dir='10_extra_camera_uart'; Test='tb_rpi_camera_link' },
    @{ Id='11'; Dir='11_integrated_controller_regression'; Test='tb_lock_controller' }
)

if ($CaseIds.Count -gt 0) {
    $cases = @($cases | Where-Object { $_.Id -in $CaseIds })
    if ($cases.Count -eq 0) { throw 'No waveform cases matched CaseIds' }
}

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class VivadoWaveCapture {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
'@

[VivadoWaveCapture]::SetProcessDPIAware() | Out-Null

# 等待本次启动的新 Vivado GUI 主窗口，排除运行前已经存在的进程 ID。
function Get-NewVivadoWindow {
    param([int[]]$ExistingIds)

    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $window = Get-Process -Name vivado -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -notin $ExistingIds -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
        if ($window) { return $window }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)

    throw 'Timed out waiting for the Vivado GUI window'
}

# 最大化、置前并读取窗口坐标，然后只截取波形面板区域。
function Save-WindowCrop {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$Path
    )

    $handle = $Process.MainWindowHandle
    [VivadoWaveCapture]::ShowWindow($handle, 3) | Out-Null
    [VivadoWaveCapture]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Seconds 3

    $rect = New-Object VivadoWaveCapture+RECT
    if (-not [VivadoWaveCapture]::GetWindowRect($handle, [ref]$rect)) {
        throw 'Could not read the Vivado window bounds'
    }

    $windowWidth = $rect.Right - $rect.Left
    $windowHeight = $rect.Bottom - $rect.Top
    $width = [Math]::Min($CropWidth, $windowWidth - $CropLeft)
    $height = [Math]::Min($CropHeight, $windowHeight - $CropTop)
    if ($width -le 0 -or $height -le 0) {
        throw "Crop is outside the Vivado window: ${windowWidth}x${windowHeight}"
    }

    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $sourceX = $rect.Left + $CropLeft
        $sourceY = $rect.Top + $CropTop
        $graphics.CopyFromScreen($sourceX, $sourceY, 0, 0, [System.Drawing.Size]::new($width, $height))
        $absolutePath = [System.IO.Path]::GetFullPath($Path)
        $bitmap.Save($absolutePath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

# 每项最多尝试两次；无论成功失败都关闭本次启动的 Vivado，避免后台积累窗口。
foreach ($case in $cases) {
    $base = Join-Path (Join-Path $OutputRoot $case.Dir) $case.Test
    $wdb = "$base.wdb"
    $wcfg = "$base.wcfg"
    $png = "$base.png"
    if (-not (Test-Path -LiteralPath $wdb)) { throw "Missing WDB: $wdb" }
    if (-not (Test-Path -LiteralPath $wcfg)) { throw "Missing WCFG: $wcfg" }

    $captured = $false
    for ($attempt = 1; $attempt -le 2 -and -not $captured; $attempt++) {
        $existingIds = @(Get-Process -Name vivado -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
        $launcher = Start-Process -FilePath $vivado -ArgumentList @(
            '-mode', 'gui', '-nolog', '-nojournal', '-source', $openScript,
            '-tclargs', $wdb, $wcfg
        ) -PassThru

        $window = $null
        try {
            $window = Get-NewVivadoWindow -ExistingIds $existingIds
            Start-Sleep -Seconds 12
            Save-WindowCrop -Process $window -Path $png
            Write-Output "Captured $($case.Id): $png"
            $captured = $true
        } catch {
            if ($attempt -eq 2) { throw }
            Write-Warning "Vivado capture attempt $attempt failed for $($case.Test); retrying"
        } finally {
            if ($window -and -not $window.HasExited) {
                $window.CloseMainWindow() | Out-Null
                if (-not $window.WaitForExit(10000)) {
                    Stop-Process -Id $window.Id -Force
                }
            }
            if ($launcher -and -not $launcher.HasExited) {
                $launcher.WaitForExit(5000) | Out-Null
            }
            Start-Sleep -Seconds 2
        }
    }
}

Write-Output "PASS: captured $($cases.Count) Vivado waveform images at $OutputRoot"
