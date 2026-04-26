param(
  [switch]$SkipCleanup,
  [int]$KeepSnapshots = 20
)

$ErrorActionPreference = 'Stop'

function Write-AtomicFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Content
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $tempPath = Join-Path $directory ([System.IO.Path]::GetRandomFileName())
  try {
    Set-Content -Path $tempPath -Value $Content -Encoding UTF8
    Move-Item -Path $tempPath -Destination $Path -Force
  } finally {
    if (Test-Path $tempPath) {
      Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-ExecutionLog {
  param(
    [string]$Message,
    [string]$Status = 'INFO'
  )

  $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Add-Content -Path $executionLogFile -Value "[$timestamp] [$Status] $Message" -Encoding UTF8
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$continuityDir = Join-Path $projectRoot 'docs\registro_continuidade'
$currentFile = Join-Path $continuityDir 'CONTINUIDADE_ATUAL.md'
$stateFile = Join-Path $continuityDir 'continuity_state.json'
$historyFile = Join-Path $continuityDir 'HISTORICO_EXECUCOES_CONTINUIDADE.log'
$snapshotDir = Join-Path $continuityDir 'snapshots'
$executionLogFile = Join-Path $continuityDir 'save_continuity.log'

New-Item -ItemType Directory -Force -Path $continuityDir | Out-Null
New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
if (-not (Test-Path $executionLogFile)) {
  New-Item -ItemType File -Path $executionLogFile -Force | Out-Null
}
if (-not (Test-Path $historyFile)) {
  New-Item -ItemType File -Path $historyFile -Force | Out-Null
}

$mutexName = 'Global\PontoCertoContinuitySave'
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$lockTaken = $false

try {
  $lockTaken = $mutex.WaitOne([TimeSpan]::FromSeconds(30))
  if (-not $lockTaken) {
    throw 'Nao foi possivel obter o lock de continuidade em 30 segundos.'
  }

  $trackedRoots = @(
    (Join-Path $projectRoot 'lib'),
    (Join-Path $projectRoot 'functions\src'),
    (Join-Path $projectRoot 'docs')
  ) | Where-Object { Test-Path $_ }

  $recentFiles = foreach ($root in $trackedRoots) {
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $_.FullName -notmatch '\\node_modules\\' -and
        $_.FullName -notmatch '\\build\\' -and
        $_.FullName -notmatch '\\.dart_tool\\' -and
        $_.FullName -notmatch '\\docs\\registro_continuidade\\snapshots\\' -and
        $_.FullName -notmatch '\\docs\\registro_continuidade\\(save_continuity\.log|watcher_continuity\.log|HISTORICO_EXECUCOES_CONTINUIDADE\.log|continuity_state\.json|CONTINUIDADE_ATUAL\.md)$'
      } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 18
  }

  $recentFiles = $recentFiles |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Unique FullName, LastWriteTime |
    Select-Object -First 18

  $generatedAt = Get-Date
  $generatedLabel = $generatedAt.ToString('dd/MM/yyyy HH:mm:ss')
  $todayLabel = $generatedAt.ToString('dd/MM/yyyy')

  $recentFileLines = if ($recentFiles.Count -gt 0) {
    ($recentFiles | ForEach-Object {
      $relative = $_.FullName.Replace($projectRoot + '\', '')
      $normalized = $relative -replace '\\','/'
      ('- `{0}` | {1}' -f $normalized, $_.LastWriteTime.ToString('dd/MM/yyyy HH:mm:ss'))
    }) -join "`r`n"
  } else {
    "- Nenhum arquivo recente identificado."
  }

  $content = @"
# Continuidade Atual

Data: $todayLabel

## Situacao

- Registro atualizado automaticamente em $generatedLabel.
- O retrato consolidado do projeto continua em `ESTADO_ATUAL_DO_SISTEMA.md`.
- Este arquivo deve refletir o ponto atual de continuidade e os arquivos tocados mais recentemente.

## Onde paramos

- O sistema segue na consolidacao do shell `web-first`.
- As frentes mais sensiveis continuam sendo:
  - `Financeiro`
  - `Fiscal`
  - `Trabalhista`
  - base compartilhada de `Clientes` e `Tarefas`

## Arquivos mais recentes

$recentFileLines

## Proximo passo seguro

- validar consistencia das telas e fluxos alterados por ultimo
- evitar abrir novas frentes antes de consolidar modulos centrais
- manter `ESTADO_ATUAL_DO_SISTEMA.md` alinhado quando a arquitetura mudar
"@

  Write-AtomicFile -Path $currentFile -Content $content

  $state = [ordered]@{
    lastGeneratedAt = $generatedAt.ToString('o')
    generator = 'scripts/save_continuity.ps1'
    keepSnapshots = $KeepSnapshots
    recentFiles = @($recentFiles | ForEach-Object {
      [ordered]@{
        path = $_.FullName.Replace($projectRoot + '\', '') -replace '\\','/'
        lastWriteTime = $_.LastWriteTime.ToString('o')
      }
    })
  }

  $stateJson = $state | ConvertTo-Json -Depth 5
  Write-AtomicFile -Path $stateFile -Content $stateJson

  $snapshotStamp = $generatedAt.ToString('yyyyMMdd-HHmmss')
  $snapshotMarkdown = Join-Path $snapshotDir "CONTINUIDADE_ATUAL-$snapshotStamp.md"
  $snapshotJson = Join-Path $snapshotDir "continuity_state-$snapshotStamp.json"
  Write-AtomicFile -Path $snapshotMarkdown -Content $content
  Write-AtomicFile -Path $snapshotJson -Content $stateJson

  $historyLine = "$($generatedAt.ToString('o')) | recentFiles=$($recentFiles.Count) | snapshot=$snapshotStamp"
  Add-Content -Path $historyFile -Value $historyLine -Encoding UTF8

  $oldSnapshots = Get-ChildItem -Path $snapshotDir -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
  if ($oldSnapshots.Count -gt ($KeepSnapshots * 2)) {
    $oldSnapshots | Select-Object -Skip ($KeepSnapshots * 2) | Remove-Item -Force -ErrorAction SilentlyContinue
  }

  if (-not $SkipCleanup) {
    Get-ChildItem $projectRoot -File -Filter 'CONTINUAR_AMANHA_*.md' -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue

    Get-ChildItem $projectRoot -File -Filter 'NOTAS_VERSAO_*.txt' -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue

    $webBuildLog = Join-Path $projectRoot 'web_build.log'
    if (Test-Path $webBuildLog) {
      Remove-Item $webBuildLog -Force -ErrorAction SilentlyContinue
    }

    $backupDir = Join-Path $projectRoot 'backup'
    if (Test-Path $backupDir) {
      Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $buildDir = Join-Path $projectRoot 'build'
    if (Test-Path $buildDir) {
      $buildLogs = Get-ChildItem $buildDir -Recurse -File -Include *.log -ErrorAction SilentlyContinue
      foreach ($item in $buildLogs) {
        Remove-Item $item.FullName -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Write-ExecutionLog -Message "Continuidade salva com sucesso. snapshot=$snapshotStamp recentFiles=$($recentFiles.Count)"
  Write-Output "Continuidade atualizada em $currentFile"
} catch {
  Write-ExecutionLog -Message $_.Exception.Message -Status 'ERROR'
  throw
} finally {
  if ($lockTaken) {
    $mutex.ReleaseMutex() | Out-Null
  }
  $mutex.Dispose()
}
