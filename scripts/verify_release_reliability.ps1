param(
  [string]$FirebaseProject = 'pontocerto-e1dab',
  [switch]$Deploy,
  [switch]$SkipDomainChecks
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$functionsDir = Join-Path $repoRoot 'functions'
$buildScript = Join-Path $PSScriptRoot 'build_flutter_direct.ps1'
$firebaseCli = 'C:\Users\hp\AppData\Roaming\npm\firebase.cmd'

if (!(Test-Path $buildScript)) {
  throw "Script de build direto nao encontrado em $buildScript"
}
if (!(Test-Path $firebaseCli)) {
  throw "Firebase CLI nao encontrado em $firebaseCli"
}

function Invoke-Step {
  param(
    [string]$Label,
    [scriptblock]$Action
  )

  Write-Host "==> $Label" -ForegroundColor Cyan
  & $Action
  Write-Host "OK: $Label" -ForegroundColor Green
}

function Get-PageSummary {
  param(
    [string]$Url
  )

  $response = Invoke-WebRequest -Uri $Url -MaximumRedirection 5
  $titleMatch = [regex]::Match($response.Content, '<title>(.*?)</title>', 'IgnoreCase')
  [pscustomobject]@{
    Url = $Url
    StatusCode = [int]$response.StatusCode
    FinalUri = $response.BaseResponse.ResponseUri.AbsoluteUri
    Title = $titleMatch.Groups[1].Value
  }
}

Push-Location $repoRoot
try {
  Invoke-Step 'Build das Cloud Functions' {
    Push-Location $functionsDir
    try {
      npm run build
      if ($LASTEXITCODE -ne 0) {
        throw "npm run build falhou com codigo $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }

  Invoke-Step 'Build web pelo Flutter tools direto' {
    & $buildScript -Target web
    if ($LASTEXITCODE -ne 0) {
      throw "Build web direto falhou com codigo $LASTEXITCODE"
    }
  }

  if ($Deploy) {
    Invoke-Step "Deploy functions + hosting em $FirebaseProject" {
      & $firebaseCli deploy --only functions,hosting --project $FirebaseProject
      if ($LASTEXITCODE -ne 0) {
        throw "firebase deploy falhou com codigo $LASTEXITCODE"
      }
    }
  }

  if (!$SkipDomainChecks) {
    Invoke-Step 'Verificacao HTTP dos dominios publico e web.app' {
      $custom = Get-PageSummary -Url 'https://gestao-ponto-certo.com'
      $webApp = Get-PageSummary -Url 'https://pontocerto-e1dab.web.app'

      $custom | Format-List | Out-Host
      $webApp | Format-List | Out-Host

      if ($custom.StatusCode -ne 200) {
        throw "Dominio personalizado retornou status $($custom.StatusCode)"
      }
      if ($webApp.StatusCode -ne 200) {
        throw "Dominio web.app retornou status $($webApp.StatusCode)"
      }
      if ($custom.Title -ne 'Ponto Certo' -or $webApp.Title -ne 'Ponto Certo') {
        throw 'Um dos dominios nao retornou o titulo esperado do app.'
      }
    }
  }
} finally {
  Pop-Location
}

Write-Host 'Confiabilidade web verificada com sucesso.' -ForegroundColor Green
