# Manual Operacao Interna

Data: 22/03/2026

## Objetivo

Orientar a operacao minima do sistema sem depender de memoria informal.

## Fluxos centrais

### 1. Cliente e tarefa

- cadastrar ou reaproveitar cliente pelo documento
- abrir tarefa com cliente vinculado
- registrar itens, materiais e anexos
- acompanhar execucao ate aprovacao ou finalizacao

### 2. Fiscal

- usar a mesma base de cliente/tomador por documento
- vincular `tarefa de origem` sempre que a nota nascer de execucao real
- revisar readiness da empresa antes de homologacao ou producao
- emitir `NFS-e` oficial apenas com checklist e configuracao validos
- usar reconsulta ou conciliacao quando a nota ficar em `PROCESSING`

### 3. Financeiro

- acompanhar `finance_movements` como visao consolidada
- confirmar se a receita da nota fiscal nasceu automaticamente
- revisar pagamentos, dividas e movimentos por competencia
- evitar lancamento manual duplicado de receita quando a nota ja estiver vinculada

### 4. Workforce

- selecionar competencia e colaborador antes de qualquer lancamento
- conferir base automatica da competencia
- revisar aprovacoes e historicos antes de fechar
- usar documentos e operacoes complementares dentro da competencia correta

## Configuracoes sensiveis por empresa

- `company_settings`
- readiness fiscal real
- checklist de homologacao fiscal
- permissoes de gerente em financeiro e workforce
- clausulas contratuais e textos completos

## Rotina recomendada por rodada

1. atualizar ou revisar `CONTINUIDADE_ATUAL.md`
2. rodar `powershell -ExecutionPolicy Bypass -File .\scripts\guard_flutter_cycle.ps1 -Mode validate-only` antes de abrir nova frente grande ou fechar refatoracao estrutural
3. usar `powershell -ExecutionPolicy Bypass -File .\scripts\guard_flutter_cycle.ps1 -Mode web-fast` para build web rapido e `-Mode appbundle-fast` para Android rapido quando a validacao ja estiver limpa
4. se algo falhar, corrigir na mesma rodada e rerodar a guarda; nao empilhar avisos, erros de analise ou quebras estruturais para depois
5. usar `scripts/check_core_consistency.ps1` apenas como apoio quando o ambiente estiver instavel ou como fallback textual
6. revisar os arquivos centrais alterados
7. atualizar documentos de continuidade se a arquitetura mudou

## Regra permanente de saude tecnica

- toda rodada relevante deve terminar com validacao automatica real ou com registro explicito do bloqueio operacional
- nao deixar `dart analyze`, `dart format` ou build quebrados acumularem entre ciclos
- quando aparecer erro operacional de SDK, permissao, cache ou processo travado, tratar como incidente imediato e corrigir antes de continuar a mexer em modulo funcional
- preferir os scripts diretos em `scripts\` com `PowerShell -ExecutionPolicy Bypass` para evitar falso negativo do sandbox
- considerar `web-fast`, `appbundle-fast` e `apk-fast` como os caminhos padrao de build rapido

## Evitar

- duplicar cadastro de cliente/tomador fora do fluxo compartilhado
- gerar receita manual quando a nota ja criou movimento automaticamente
- abrir novas frentes grandes sem revisar `Fiscal`, `Financeiro` e `Workforce`
- apagar registros correntes de continuidade
