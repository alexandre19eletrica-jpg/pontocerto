param(
  [ValidateSet('analyze', 'format', 'check')]
  [string]$Mode = 'check',
  [string[]]$Paths = @(
    'lib/features/fiscal/presentation/pages',
    'lib/features/workforce/presentation/pages'
  ),
  [switch]$UseFallbackConsistency
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$dartExe = 'C:\Users\hp\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe'
$consistencyScript = Join-Path $PSScriptRoot 'check_core_consistency.ps1'

if (!(Test-Path $dartExe)) {
  throw "Dart nao encontrado em $dartExe"
}

$resolvedPaths = @()
foreach ($path in $Paths) {
  $fullPath = Join-Path $repoRoot $path
  if (!(Test-Path $fullPath)) {
    throw "Caminho nao encontrado: $path"
  }
  $resolvedPaths += $fullPath
}

function Invoke-DartAnalyze {
  param([string[]]$TargetPaths)

  Write-Host 'Executando dart analyze direcionado...' -ForegroundColor Cyan
  & $dartExe analyze @TargetPaths
  if ($LASTEXITCODE -ne 0) {
    throw "dart analyze falhou com codigo $LASTEXITCODE"
  }
}

function Invoke-DartFormatCheck {
  param([string[]]$TargetPaths)

  Write-Host 'Executando dart format -o none...' -ForegroundColor Cyan
  & $dartExe format -o none @TargetPaths
  if ($LASTEXITCODE -ne 0) {
    throw "dart format -o none falhou com codigo $LASTEXITCODE"
  }
}

switch ($Mode) {
  'analyze' {
    Invoke-DartAnalyze -TargetPaths $resolvedPaths
  }
  'format' {
    Invoke-DartFormatCheck -TargetPaths $resolvedPaths
  }
  'check' {
    Invoke-DartAnalyze -TargetPaths $resolvedPaths
    Invoke-DartFormatCheck -TargetPaths $resolvedPaths
  }
}

if ($UseFallbackConsistency) {
  if (!(Test-Path $consistencyScript)) {
    throw "Script de consistencia nao encontrado em $consistencyScript"
  }
  Write-Host 'Executando fallback estrutural...' -ForegroundColor Cyan
  & $consistencyScript
  if ($LASTEXITCODE -ne 0) {
    throw "check_core_consistency.ps1 falhou com codigo $LASTEXITCODE"
  }
}

Write-Host 'Validacao Flutter direcionada concluida.' -ForegroundColor Green
