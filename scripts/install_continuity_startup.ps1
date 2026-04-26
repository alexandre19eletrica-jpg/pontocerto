param(
  [string]$TaskName = 'PontoCertoContinuityWatcher'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
$watcherScript = Join-Path $scriptRoot 'start_continuity_watcher.ps1'

if (-not (Test-Path $watcherScript)) {
  throw "Watcher nao encontrado: $watcherScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$watcherScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Output "Tarefa agendada criada: $TaskName"
