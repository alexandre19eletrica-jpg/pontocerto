param(
  [ValidateSet('validate-only', 'web-fast', 'appbundle-fast', 'apk-fast')]
  [string]$Mode = 'validate-only'
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
$validateScript = Join-Path $scriptRoot 'validate_flutter_direct.ps1'
$buildScript = Join-Path $scriptRoot 'build_flutter_direct.ps1'

if (!(Test-Path $validateScript)) {
  throw "Script nao encontrado: $validateScript"
}

if (!(Test-Path $buildScript)) {
  throw "Script nao encontrado: $buildScript"
}

Write-Host "Iniciando guarda tecnica Flutter: $Mode" -ForegroundColor Cyan

& $validateScript -Mode check -UseFallbackConsistency
if ($LASTEXITCODE -ne 0) {
  throw "Validacao falhou com codigo $LASTEXITCODE"
}

switch ($Mode) {
  'validate-only' {
    Write-Host 'Guarda tecnica concluida sem build.' -ForegroundColor Green
  }
  'web-fast' {
    & $buildScript -Target web -NoPub -NoWasmDryRun
  }
  'appbundle-fast' {
    & $buildScript -Target appbundle -NoPub
  }
  'apk-fast' {
    & $buildScript -Target apk -NoPub
  }
}

if ($LASTEXITCODE -ne 0) {
  throw "Build do modo $Mode falhou com codigo $LASTEXITCODE"
}

Write-Host "Guarda tecnica Flutter concluida: $Mode" -ForegroundColor Green
