param(
  [string]$CompanyId = "comp_1771754418259",
  [string]$ExportKey = "observability-export-20260329"
)

$ErrorActionPreference = 'Stop'

$dateFolder = Get-Date -Format "yyyy-MM-dd"
$timeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$baseDir = Join-Path $PSScriptRoot "..\docs\diagnosticos\observabilidade\$dateFolder"
$resolvedDir = (Resolve-Path $baseDir -ErrorAction SilentlyContinue)
if (-not $resolvedDir) {
  New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
}

$jsonPath = Join-Path $baseDir "observabilidade_$timeStamp.json"
$mdPath = Join-Path $baseDir "observabilidade_$timeStamp.md"
$uri = "https://us-central1-pontocerto-e1dab.cloudfunctions.net/observabilityExportSupremeEphemeral?key=$ExportKey&companyId=$CompanyId"

$payload = Invoke-RestMethod -Uri $uri -Method Get
$payload | ConvertTo-Json -Depth 20 | Set-Content -Path $jsonPath -Encoding UTF8

$lines = @()
$lines += "# Snapshot De Observabilidade"
$lines += ""
$lines += "- exportado em: $($payload.exportedAt)"
$lines += "- companyId: $($payload.companyId)"
$lines += "- incidentes: $($payload.incidents.Count)"
$lines += "- problemas: $($payload.issues.Count)"
$lines += ""
$lines += "## Incidentes"
$lines += ""

foreach ($incident in $payload.incidents) {
  $lines += "### $($incident.id)"
  $lines += "- status: $($incident.status)"
  $lines += "- source: $($incident.source)"
  $lines += "- category: $($incident.category)"
  $lines += "- severity: $($incident.severity)"
  $lines += "- screenLabel: $($incident.screenLabel)"
  $lines += "- message: $($incident.message)"
  if ($incident.assistantSummary) {
    $lines += "- assistantSummary: $($incident.assistantSummary)"
  }
  if ($incident.recommendedAction) {
    $lines += "- recommendedAction: $($incident.recommendedAction)"
  }
  $lines += ""
}

$lines += "## Problemas Confirmados"
$lines += ""

foreach ($issue in $payload.issues) {
  $lines += "### $($issue.id)"
  $lines += "- status: $($issue.status)"
  $lines += "- fixStatus: $($issue.fixStatus)"
  $lines += "- module: $($issue.module)"
  $lines += "- source: $($issue.source)"
  $lines += "- title: $($issue.title)"
  $lines += "- description: $($issue.description)"
  if ($issue.recommendedAction) {
    $lines += "- recommendedAction: $($issue.recommendedAction)"
  }
  $lines += ""
}

$lines | Set-Content -Path $mdPath -Encoding UTF8

Write-Output "JSON: $jsonPath"
Write-Output "MD: $mdPath"
