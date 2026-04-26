param(
  [switch]$CleanFirst
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterBat = 'C:\Users\hp\flutter\flutter\bin\flutter.bat'
$javaHome = 'C:\Program Files\Android\Android Studio\jbr'
$gradleUserHome = 'C:\Users\hp\.gradle'

if (!(Test-Path $flutterBat)) {
  throw "Flutter nao encontrado em $flutterBat"
}
if (!(Test-Path $javaHome)) {
  throw "JAVA_HOME nao encontrado em $javaHome"
}

$env:JAVA_HOME = $javaHome
$env:GRADLE_USER_HOME = $gradleUserHome

Write-Host "JAVA_HOME=$env:JAVA_HOME" -ForegroundColor Cyan
Write-Host "GRADLE_USER_HOME=$env:GRADLE_USER_HOME" -ForegroundColor Cyan

Push-Location $repoRoot
try {
  if ($CleanFirst) {
    Write-Host 'Executando flutter clean' -ForegroundColor Cyan
    & $flutterBat clean
    if ($LASTEXITCODE -ne 0) {
      throw "flutter clean falhou com codigo $LASTEXITCODE"
    }
  }

  Write-Host 'Gerando appbundle release' -ForegroundColor Cyan
  & $flutterBat build appbundle --release
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build appbundle falhou com codigo $LASTEXITCODE"
  }

  $artifact = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
  if (!(Test-Path $artifact)) {
    throw "AAB nao encontrado em $artifact"
  }

  Get-Item $artifact | Select-Object FullName, Length, LastWriteTime
} finally {
  Pop-Location
}
