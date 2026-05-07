# Automacao opcional (analyze, icons, NODE_OPTIONS, login:list). Comando oficial do projeto:
# Set-Location c:\Users\hp\pontocerto; flutter pub get; flutter build web --release; Set-Location functions; npm run build; Set-Location c:\Users\hp\pontocerto; firebase deploy --only functions,hosting
# Ver docs/README_OFICIAL_DOCUMENTACAO.md
param(
  [switch]$Android,
  [switch]$AndroidCopyToDesktop,
  [switch]$SkipAnalyze,
  [switch]$SkipFirebaseLoginConfirm
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$firebaseProject = 'pontocerto-e1dab'
$flutterBat = 'C:\Users\hp\flutter\flutter\bin\flutter.bat'
if (!(Test-Path $flutterBat)) {
  $flutterBat = 'flutter'
}

Push-Location $repoRoot
try {
  Write-Host '=== flutter pub get ===' -ForegroundColor Cyan
  & $flutterBat pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get falhou ($LASTEXITCODE)"
  }

  if (!$SkipAnalyze) {
    # Sem --no-fatal-* o analyze falha com exit 1 por warnings/infos; bloqueia deploy sem erro Dart real.
    Write-Host '=== flutter analyze --no-pub (fatal so errors) ===' -ForegroundColor Cyan
    & $flutterBat analyze --no-pub --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE -ne 0) {
      throw "flutter analyze falhou ($LASTEXITCODE)"
    }
  }

  Write-Host '=== flutter build web --release (icons completos) ===' -ForegroundColor Cyan
  & $flutterBat build web --release --no-tree-shake-icons
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build web falhou ($LASTEXITCODE)"
  }

  Write-Host '=== functions: npm run build ===' -ForegroundColor Cyan
  Push-Location (Join-Path $repoRoot 'functions')
  try {
    npm run build
    if ($LASTEXITCODE -ne 0) {
      throw "npm run build (functions) falhou ($LASTEXITCODE)"
    }
  } finally {
    Pop-Location
  }

  & (Join-Path $PSScriptRoot 'firebase_confirm_login_before_deploy.ps1') -SkipFirebaseLoginConfirm:$SkipFirebaseLoginConfirm -ProjectId $firebaseProject

  Write-Host "=== firebase deploy (functions + hosting) projeto $firebaseProject ===" -ForegroundColor Cyan
  # Reduz timeouts "Cannot determine backend specification" em redes Windows (Node prefere IPv4).
  $existingNodeOpts = [string]$env:NODE_OPTIONS
  if ($existingNodeOpts -notmatch 'dns-result-order=ipv4first') {
    $env:NODE_OPTIONS = if ([string]::IsNullOrWhiteSpace($existingNodeOpts)) {
      '--dns-result-order=ipv4first'
    } else {
      "--dns-result-order=ipv4first $existingNodeOpts"
    }
  }
  firebase deploy --only "functions,hosting" --project $firebaseProject
  if ($LASTEXITCODE -ne 0) {
    throw "firebase deploy falhou ($LASTEXITCODE)"
  }

  if ($Android) {
    Write-Host '=== Android app bundle (build_android_release.ps1) ===' -ForegroundColor Cyan
    & "$PSScriptRoot\build_android_release.ps1" -CopyToDesktop:$AndroidCopyToDesktop
  }

  Write-Host 'Concluido: web build, functions build, firebase deploy' -ForegroundColor Green
  if (!$Android) {
    Write-Host 'Dica: use -Android para gerar o .aab no fim (e -AndroidCopyToDesktop).' -ForegroundColor DarkGray
  }
} finally {
  Pop-Location
}
