param(
    [string]$OutputRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'simulation_waveforms'),
    [string[]]$CaseIds = @(),
    [switch]$AppendLog
)

$ErrorActionPreference = 'Stop'
$vivado = 'D:\Xilinx\Vivado\2023.2\bin\vivado.bat'
$python = 'D:\anaconda\python.exe'
$projectRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectRoot

if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado not found: $vivado" }
if (-not (Test-Path -LiteralPath $python)) { throw "Python not found: $python" }

$cases = @(
    @{ Id='01'; Dir='01_basic_entry_timeout'; Test='tb_basic_entry_timeout'; Title='01 基础功能：输入、退格、开锁与超时'; Signals='scenario,rst,init_done,sw1,key_valid,key_code,state,entry_digits,entry_count,unlocked,error_count' },
    @{ Id='02'; Dir='02_admin_password_save'; Test='tb_basic_admin_save'; Title='02 基础功能：管理员改密与保存结果'; Signals='scenario,rst,admin,key_valid,key_code,state,entry_digits,save_request,save_password,save_done,save_success,display_fault' },
    @{ Id='03'; Dir='03_error_alarm_policy'; Test='tb_basic_alarm_policy'; Title='03 基础功能：四次错误、报警与 KEY2 解除'; Signals='scenario,rst,sw1,admin,clear,temp_event,key_valid,key_code,state,error_count,alarm_active,capture_start,capture_pulses' },
    @{ Id='04'; Dir='04_matrix_keypad'; Test='tb_keypad_scanner'; Title='04 基础功能：矩阵键盘全映射、消抖与多键屏蔽'; Signals='scenario,rst,pressed_keys,col_n,row_n,event_valid,event_code,expected_code,events' },
    @{ Id='05'; Dir='05_seven_segment'; Test='tb_sevenseg_display'; Title='05 基础功能：全部状态字形与动态扫描'; Signals='scenario,rst,state,entry_digits,entry_count,error_count,temporary_password,display_fault,digit_sel,seg_n' },
    @{ Id='06'; Dir='06_alarm_buzzer'; Test='tb_alarm_buzzer'; Title='06 基础功能：报警蜂鸣器与指示灯节拍'; Signals='rst,alarm_active,indicator,buzzer_n' },
    @{ Id='07'; Dir='07_flash_default_failure'; Test='tb_flash_default_fail'; Title='07 基础功能：Flash 空记录默认密码与写失败保护'; Signals='rst,save,password,init_done,save_done,save_ok,fault,cs,sclk,mosi' },
    @{ Id='08'; Dir='08_flash_dual_journal'; Test='tb_flash_journal'; Title='08 基础功能：Flash 双扇区保存、版本选择与损坏恢复'; Signals='rst,save,new_password,password,init_done,save_done,save_ok,fault,cs,sclk,mosi,miso' },
    @{ Id='09'; Dir='09_extra_random_password'; Test='tb_temporary_password_generator'; Title='09 附加功能：四位随机临时密码生成与替换'; Signals='rst,generate_event,stored_password,temporary_password,temporary_valid,previous_password' },
    @{ Id='10'; Dir='10_extra_camera_uart'; Test='tb_rpi_camera_link'; Title='10 附加功能：报警拍摄 UART 触发、ACK 与重发'; Signals='rst,photo_trigger,uart_tx,uart_rx,link_waiting,message_active,message_index,rx_valid,rx_data,tx_starts' },
    @{ Id='11'; Dir='11_integrated_controller_regression'; Test='tb_lock_controller'; Title='11 集成回归：固定密码、临时密码、改密与报警'; Signals='rst,init_done,sw1,admin,clear,temp_event,key_valid,key_code,state,entry_digits,error_count,unlocked,alarm_active,capture_start,display_fault' }
)

if ($CaseIds.Count -gt 0) {
    $cases = @($cases | Where-Object { $_.Id -in $CaseIds })
    if ($cases.Count -eq 0) { throw 'No waveform cases matched CaseIds' }
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$summaryLog = Join-Path $OutputRoot 'vivado_waveform_run.log'
if (-not $AppendLog) {
    Remove-Item -LiteralPath $summaryLog -Force -ErrorAction SilentlyContinue
}

Push-Location $projectRoot
try {
    $previousVivadoProjectDir = $env:VIVADO_PROJECT_DIR
    foreach ($case in $cases) {
        $caseDir = Join-Path $OutputRoot $case.Dir
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        $caseLog = Join-Path $caseDir ($case.Test + '.log')
        $env:VIVADO_PROJECT_DIR = Join-Path $repoRoot ("tmp\waveform_projects\" + $case.Test)
        "=== $($case.Id) $($case.Test) ===" | Tee-Object -FilePath $summaryLog -Append
        & $vivado -mode batch -nolog -nojournal -source scripts/run_waveform.tcl -tclargs $case.Test $caseDir 2>&1 |
            Tee-Object -FilePath $caseLog |
            Tee-Object -FilePath $summaryLog -Append
        if ($LASTEXITCODE -ne 0) { throw "Vivado waveform simulation failed: $($case.Test)" }
        $vcd = Join-Path $caseDir ($case.Test + '.vcd')
        $png = Join-Path $caseDir ($case.Test + '.png')
        & $python scripts/render_vcd.py $vcd $png --title $case.Title --signals $case.Signals
        if ($LASTEXITCODE -ne 0) { throw "VCD rendering failed: $($case.Test)" }
        Start-Sleep -Milliseconds 500
    }
} finally {
    $env:VIVADO_PROJECT_DIR = $previousVivadoProjectDir
    Pop-Location
}

"PASS: generated $($cases.Count) Vivado waveform packages at $OutputRoot" | Tee-Object -FilePath $summaryLog -Append
