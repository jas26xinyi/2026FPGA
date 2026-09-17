param([string]$Vivado='D:\Xilinx\Vivado\2023.2\bin\vivado.bat')
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Vivado)) { throw "Vivado not found: $Vivado" }
Push-Location $PSScriptRoot
try {
    & $Vivado -mode batch -nolog -nojournal -source (Join-Path $PSScriptRoot 'run_fsm.tcl')
    if ($LASTEXITCODE -ne 0) { throw 'FSM simulation failed' }
} finally { Pop-Location }
