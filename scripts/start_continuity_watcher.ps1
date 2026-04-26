param(
  [int]$DebounceSeconds = 8,
  [int]$HeartbeatMinutes = 5
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptRoot
$saveScript = Join-Path $scriptRoot 'save_continuity.ps1'
$continuityDir = Join-Path $projectRoot 'docs\registro_continuidade'
$watcherLog = Join-Path $continuityDir 'watcher_continuity.log'

if (-not (Test-Path $saveScript)) {
  throw "Script de salvamento nao encontrado: $saveScript"
}

New-Item -ItemType Directory -Force -Path $continuityDir | Out-Null
if (-not (Test-Path $watcherLog)) {
  New-Item -ItemType File -Path $watcherLog -Force | Out-Null
}

function Write-WatcherLog {
  param(
    [string]$Message,
    [string]$Status = 'INFO'
  )

  $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Add-Content -Path $watcherLog -Value "[$timestamp] [$Status] $Message" -Encoding UTF8
}

function Invoke-ContinuitySave {
  param(
    [string]$Reason
  )

  try {
    Write-WatcherLog -Message "Disparando save_continuity.ps1. motivo=$Reason"
    & powershell -ExecutionPolicy Bypass -File $saveScript | Out-Host
    $script:lastSuccessfulSave = Get-Date
    $script:pendingSave = $false
  } catch {
    $script:pendingSave = $true
    Write-WatcherLog -Message "Falha no save_continuity.ps1. motivo=$Reason erro=$($_.Exception.Message)" -Status 'ERROR'
  }
}

$watchRoots = @(
  (Join-Path $projectRoot 'lib'),
  (Join-Path $projectRoot 'functions\src'),
  (Join-Path $projectRoot 'docs')
) | Where-Object { Test-Path $_ }

$script:lastEventAt = Get-Date '2000-01-01'
$script:lastSuccessfulSave = Get-Date '2000-01-01'
$script:pendingSave = $false

$watchers = @()
$registrations = @()

foreach ($root in $watchRoots) {
  $watcher = New-Object System.IO.FileSystemWatcher
  $watcher.Path = $root
  $watcher.IncludeSubdirectories = $true
  $watcher.EnableRaisingEvents = $true
  $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, Size, CreationTime'
  $watcher.Filter = '*.*'
  $watchers += $watcher

  foreach ($eventName in @('Changed', 'Created', 'Renamed', 'Deleted')) {
    $registrations += Register-ObjectEvent -InputObject $watcher -EventName $eventName -Action {
      $path = $event.SourceEventArgs.FullPath
      if ($path -match '\\docs\\registro_continuidade\\snapshots\\' -or
          $path -match '\\docs\\registro_continuidade\\(CONTINUIDADE_ATUAL\.md|continuity_state\.json|save_continuity\.log|watcher_continuity\.log|HISTORICO_EXECUCOES_CONTINUIDADE\.log)$') {
        return
      }
      $script:lastEventAt = Get-Date
      $script:pendingSave = $true
    }
  }
}

Write-WatcherLog -Message "Watcher iniciado. debounce=${DebounceSeconds}s heartbeat=${HeartbeatMinutes}m"
Write-Host 'Watcher de continuidade ativo. Pressione Ctrl+C para encerrar.'
Invoke-ContinuitySave -Reason 'startup'

try {
  while ($true) {
    Start-Sleep -Seconds 2

    $now = Get-Date
    if ($script:pendingSave -and ($now - $script:lastEventAt).TotalSeconds -ge $DebounceSeconds) {
      Invoke-ContinuitySave -Reason 'file-change'
      continue
    }

    if (($now - $script:lastSuccessfulSave).TotalMinutes -ge $HeartbeatMinutes) {
      Invoke-ContinuitySave -Reason 'heartbeat'
    }
  }
} finally {
  Write-WatcherLog -Message 'Watcher encerrado.'
  foreach ($registration in $registrations) {
    Unregister-Event -SourceIdentifier $registration.Name -ErrorAction SilentlyContinue
    Remove-Job -Id $registration.Id -Force -ErrorAction SilentlyContinue
  }
  foreach ($watcher in $watchers) {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
  }
}
