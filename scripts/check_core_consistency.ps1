$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$docsDir = Join-Path $root 'docs\registro_continuidade'
$outputPath = Join-Path $docsDir 'ULTIMA_VALIDACAO_TECNICA.md'
$generatedAt = Get-Date

if (-not (Test-Path $docsDir)) {
  New-Item -ItemType Directory -Path $docsDir | Out-Null
}

function Test-Pattern {
  param(
    [string]$RelativePath,
    [string]$Pattern,
    [string]$Label
  )

  $fullPath = Join-Path $root $RelativePath
  if (-not (Test-Path $fullPath)) {
    return [pscustomobject]@{
      Label = $Label
      Status = 'FALHOU'
      Detail = "Arquivo ausente: $RelativePath"
    }
  }

  $match = Select-String -Path $fullPath -Pattern $Pattern -SimpleMatch
  if ($match) {
    return [pscustomobject]@{
      Label = $Label
      Status = 'OK'
      Detail = $RelativePath
    }
  }

  return [pscustomobject]@{
    Label = $Label
    Status = 'FALHOU'
    Detail = "Padrao nao encontrado em $RelativePath"
  }
}

$checks = @(
  (Test-Pattern 'functions\src\index.ts' 'ensureFinanceMovementForInvoice' 'Backend gera receita fiscal vinculada'),
  (Test-Pattern 'functions\src\index.ts' 'fiscalRefreshServiceInvoiceStatus' 'Backend consulta status oficial'),
  (Test-Pattern 'functions\src\index.ts' 'fiscalReconcileProcessingInvoices' 'Backend reconcilia notas em processamento'),
  (Test-Pattern 'functions\src\index.ts' 'persistInvoiceAttemptFailure' 'Backend audita falhas fiscais oficiais'),
  (Test-Pattern 'lib\features\fiscal\presentation\pages\fiscal_readiness_invoice_sections.dart' 'financeMovementId' 'Fiscal exibe vinculo com financeiro'),
  (Test-Pattern 'lib\features\fiscal\presentation\pages\fiscal_readiness_operational_actions.dart' 'sourceTaskId' 'Fiscal persiste tarefa de origem'),
  (Test-Pattern 'lib\features\fiscal\presentation\pages\fiscal_readiness_dashboard_sections.dart' '_buildFiscalSettingsRequestTile' 'Fiscal modularizou solicitacoes sensiveis'),
  (Test-Pattern 'lib\features\workforce\presentation\pages\workforce_management_payroll_sections.dart' '_buildApprovalsCard' 'Workforce modularizou aprovacoes'),
  (Test-Pattern 'lib\features\workforce\presentation\pages\workforce_management_payroll_sections.dart' '_buildCompetenceActionButtons' 'Workforce modularizou acoes da competencia'),
  (Test-Pattern 'lib\features\workforce\presentation\pages\workforce_management_payroll_sections.dart' '_buildCompetenceEmployeeSelectorCard' 'Workforce modularizou seletor principal'),
  (Test-Pattern 'lib\features\finance\presentation\pages\finance_company_page.dart' '_movementFiscalSourceLabel' 'Financeiro centralizou origem fiscal'),
  (Test-Pattern 'lib\features\finance\presentation\providers\finance_streams_provider.dart' 'sourceInvoiceId:' 'Provider le origem fiscal da movimentacao'),
  (Test-Pattern 'lib\features\finance\domain\entities\movement.dart' 'final String? sourceInvoiceId;' 'Entidade financeira carrega rastreabilidade fiscal'),
  (Test-Pattern 'lib\features\tasks\presentation\pages\tasks_page.dart' '_buildTaskListTile' 'Tasks modularizou a lista principal'),
  (Test-Pattern 'lib\features\employees\presentation\pages\employee_review_page.dart' '_buildTaskReviewTile' 'Employee review modularizou listas internas'),
  (Test-Pattern 'lib\features\reports\presentation\pages\reports_page.dart' '_buildExecutiveOverview' 'Reports ganhou panorama executivo'),
  (Test-Pattern 'docs\registro_continuidade\MANUAL_OPERACAO_INTERNA.md' '## Fluxos centrais' 'Manual interno de operacao criado'),
  (Test-Pattern 'docs\registro_continuidade\CHECKLIST_RELEASE_ROLLBACK.md' '## Antes do release' 'Checklist de release e rollback criado'),
  (Test-Pattern 'firestore.rules' 'fiscalRealIntegration' 'Rules protegem integracao fiscal sensivel'),
  (Test-Pattern 'firestore.rules' 'fiscalCertificate' 'Rules protegem certificado fiscal'),
  (Test-Pattern 'firestore.rules' 'match /fiscal_secure/{docId}' 'Rules mantem cofre fiscal dedicado')
)

$criticalFiles = @(
  'functions\src\index.ts',
  'lib\features\fiscal\presentation\pages\fiscal_readiness_page.dart',
  'lib\features\fiscal\presentation\pages\fiscal_readiness_invoice_sections.dart',
  'lib\features\fiscal\presentation\pages\fiscal_readiness_operational_actions.dart',
  'lib\features\workforce\presentation\pages\workforce_management_page.dart',
  'lib\features\workforce\presentation\pages\workforce_management_payroll_sections.dart',
  'lib\features\workforce\presentation\pages\workforce_management_governance_actions.dart',
  'lib\features\finance\presentation\pages\finance_company_page.dart',
  'lib\features\tasks\presentation\pages\tasks_page.dart',
  'lib\features\employees\presentation\pages\employee_review_page.dart',
  'lib\features\reports\presentation\pages\reports_page.dart',
  'firestore.rules',
  'docs\registro_continuidade\CONTINUIDADE_ATUAL.md',
  'docs\registro_continuidade\MANUAL_OPERACAO_INTERNA.md',
  'docs\registro_continuidade\CHECKLIST_RELEASE_ROLLBACK.md',
  'docs\registro_continuidade\AUDITORIA_GOVERNANCA_TECNICA_2026-03-22.md'
)

$fileLines = foreach ($relativePath in $criticalFiles) {
  $fullPath = Join-Path $root $relativePath
  if (Test-Path $fullPath) {
    $item = Get-Item $fullPath
    "- ``$relativePath`` | $($item.Length) bytes | $($item.LastWriteTime.ToString('dd/MM/yyyy HH:mm:ss'))"
  } else {
    "- ``$relativePath`` | ausente"
  }
}

$checkLines = foreach ($check in $checks) {
  "- [$($check.Status)] $($check.Label): $($check.Detail)"
}

$hasFailures = $checks.Status -contains 'FALHOU'
$summary = if ($hasFailures) {
  'Validacao leve concluiu com pendencias textuais.'
} else {
  'Validacao leve concluiu sem pendencias textuais nos pontos criticos verificados.'
}

$content = @(
  '# Ultima Validacao Tecnica'
  ''
  "Data: $($generatedAt.ToString('dd/MM/yyyy HH:mm:ss'))"
  ''
  '## Resultado'
  ''
  "- $summary"
  '- Esta rotina nao substitui `dart analyze` ou testes; ela existe para quando o ambiente estiver com timeout.'
  ''
  '## Checagens estruturais'
  ''
  $checkLines
  ''
  '## Arquivos auditados'
  ''
  $fileLines
  ''
  '## Observacao'
  ''
  '- Quando o ambiente permitir, a proxima etapa continua sendo rodar validacao real (`analyze` e testes).'
) -join "`r`n"

Set-Content -Path $outputPath -Value $content -Encoding UTF8
Write-Output "Validacao salva em $outputPath"
