param(
  [switch]$SkipFirebaseLoginConfirm,
  [string]$ProjectId = 'pontocerto-e1dab'
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Firebase: confirmar login antes do deploy (projeto: $ProjectId) ===" -ForegroundColor Yellow
firebase login:list
if ($LASTEXITCODE -ne 0) {
  throw "firebase login:list falhou - execute firebase login se necessario (codigo $LASTEXITCODE)"
}

if (!$SkipFirebaseLoginConfirm) {
  Read-Host "Confira a conta acima. Enter para continuar o deploy ou Ctrl+C para cancelar (projeto $ProjectId)"
}
