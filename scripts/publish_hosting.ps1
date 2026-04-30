# Build web com fonte Material Icons completa (evita ícones em branco no hosting)
# e publica só o Hosting (sem functions/appcheck).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterBat = 'C:\Users\hp\flutter\flutter\bin\flutter.bat'
if (!(Test-Path $flutterBat)) {
  $flutterBat = 'flutter'
}

Push-Location $repoRoot
try {
  Write-Host '=== flutter build web --release --no-tree-shake-icons ===' -ForegroundColor Cyan
  & $flutterBat build web --release --no-tree-shake-icons
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build web falhou ($LASTEXITCODE)"
  }

  $existingNodeOpts = [string]$env:NODE_OPTIONS
  if ($existingNodeOpts -notmatch 'dns-result-order=ipv4first') {
    $env:NODE_OPTIONS = if ([string]::IsNullOrWhiteSpace($existingNodeOpts)) {
      '--dns-result-order=ipv4first'
    } else {
      "--dns-result-order=ipv4first $existingNodeOpts"
    }
  }

  Write-Host '=== firebase deploy --only hosting ===' -ForegroundColor Cyan
  firebase deploy --only hosting
  if ($LASTEXITCODE -ne 0) {
    throw "firebase deploy falhou ($LASTEXITCODE)"
  }
  Write-Host 'Hosting publicado.' -ForegroundColor Green
} finally {
  Pop-Location
}
