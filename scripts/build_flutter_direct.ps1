param(
  [ValidateSet('web', 'appbundle', 'apk')]
  [string]$Target = 'web',
  [switch]$NoPub,
  [switch]$NoWasmDryRun,
  [switch]$PublishHosting,
  [string]$FirebaseProject = 'pontocerto-e1dab'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$dartExe = 'C:\Users\hp\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe'
$packageConfig = 'C:\Users\hp\flutter\flutter\packages\flutter_tools\.dart_tool\package_config.json'
$flutterSnapshot = 'C:\Users\hp\flutter\flutter\bin\cache\flutter_tools.snapshot'

if (!(Test-Path $dartExe)) {
  throw "Dart nao encontrado em $dartExe"
}
if (!(Test-Path $packageConfig)) {
  throw "package_config do flutter_tools nao encontrado em $packageConfig"
}
if (!(Test-Path $flutterSnapshot)) {
  throw "flutter_tools.snapshot nao encontrado em $flutterSnapshot"
}

$commonArgs = @(
  "--packages=$packageConfig",
  $flutterSnapshot,
  'build'
)

switch ($Target) {
  'web' {
    $buildArgs = @('web', '--release', '--no-source-maps')
    if ($NoWasmDryRun) {
      $buildArgs += '--no-wasm-dry-run'
    }
  }
  'appbundle' {
    $buildArgs = @('appbundle', '--release')
  }
  'apk' {
    $buildArgs = @('apk', '--release')
  }
}

if ($NoPub) {
  $buildArgs += '--no-pub'
}

Write-Host "Executando build Flutter direto: $Target" -ForegroundColor Cyan
& $dartExe @commonArgs @buildArgs

if ($LASTEXITCODE -ne 0) {
  throw "Build $Target falhou com codigo $LASTEXITCODE"
}

if ($PublishHosting) {
  if ($Target -ne 'web') {
    throw 'PublishHosting so pode ser usado com Target=web'
  }
  Write-Host "Publicando hosting em $FirebaseProject" -ForegroundColor Cyan
  firebase deploy --only hosting --project $FirebaseProject
  if ($LASTEXITCODE -ne 0) {
    throw "Deploy hosting falhou com codigo $LASTEXITCODE"
  }
}

Write-Host "Concluido: $Target" -ForegroundColor Green
