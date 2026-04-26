$ErrorActionPreference = 'Stop'

param(
  [switch]$CleanBuildArtifacts
)

$repoRoot = Split-Path -Parent $PSScriptRoot

function Stop-OrphanProcessByName {
  param([string]$Name)

  $processes = Get-Process -Name $Name -ErrorAction SilentlyContinue
  if (!$processes) {
    Write-Host "Nenhum processo $Name encontrado." -ForegroundColor DarkGray
    return
  }

  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction Stop
      Write-Host "Encerrado $Name PID=$($process.Id)" -ForegroundColor Yellow
    } catch {
      Write-Warning "Nao foi possivel encerrar $Name PID=$($process.Id): $($_.Exception.Message)"
    }
  }
}

Write-Host 'Encerrando processos Flutter/Dart/Java orfaos...' -ForegroundColor Cyan
Stop-OrphanProcessByName -Name 'dart'
Stop-OrphanProcessByName -Name 'flutter'
Stop-OrphanProcessByName -Name 'java'

if ($CleanBuildArtifacts) {
  $targets = @(
    (Join-Path $repoRoot 'build'),
    (Join-Path $repoRoot '.dart_tool')
  )

  foreach ($target in $targets) {
    if (Test-Path $target) {
      Write-Host "Removendo $target" -ForegroundColor Cyan
      Remove-Item -LiteralPath $target -Recurse -Force
    } else {
      Write-Host "Nao encontrado: $target" -ForegroundColor DarkGray
    }
  }
}

Write-Host 'Ambiente Flutter resetado.' -ForegroundColor Green
