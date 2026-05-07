# Um unico ponto de entrada: delega para o script oficial do repo (nao duplicar comandos aqui).
# Oficial: scripts/publish_all.ps1 — mesma sequencia documentada em docs/README_OFICIAL_DOCUMENTACAO.md
param(
  [switch]$Android,
  [switch]$AndroidCopyToDesktop,
  [switch]$SkipAnalyze,
  [switch]$SkipFirebaseLoginConfirm
)
$here = $PSScriptRoot
& (Join-Path $here 'scripts\publish_all.ps1') `
  -Android:$Android `
  -AndroidCopyToDesktop:$AndroidCopyToDesktop `
  -SkipAnalyze:$SkipAnalyze `
  -SkipFirebaseLoginConfirm:$SkipFirebaseLoginConfirm
