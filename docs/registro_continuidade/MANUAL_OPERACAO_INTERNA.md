# Manual Operacao Interna

Data: 22/03/2026

## Objetivo

Orientar a operacao minima do sistema sem depender de memoria informal.

## Regra suprema

- Esta e a **regra suprema** do fluxo operacional atual.
- O **Codex** edita o codigo, as rules e a documentacao tecnica.
- O **operador** executa no proprio terminal os comandos finais da rodada.
- Esses comandos devem ser entregues pelo Codex **sem ambiguidade, sem depender de ajuste manual desnecessario e ja revisados para evitar erro na execucao**.
- Neste ambiente, `flutter analyze` e `flutter build appbundle` devem sair com `--no-pub` por padrao para evitar falha externa do `pub.dev` ao decodificar advisories.
- A sequencia final deve **parar no primeiro erro** e **nao continuar** para `deploy`, copia de artefacto ou limpeza dependente quando uma etapa anterior falhar.
- `Copy-Item` so deve rodar se o `.aab` existir.
- Linhas com `Copy-Item` e comandos longos do PowerShell devem ser entregues em **uma unica linha fisica**, sem quebra manual no meio dos parametros.
- Quando houver demo publico no fluxo, a saida para o acesso real deve ser tratada como rota publica e nao pode depender de logout manual do operador.
- Se a rodada mexer em interface Flutter (`lib/`, landings, rotas, shell, paginas, copy), e obrigatorio publicar `hosting`. `firebase deploy --only functions` sozinho nao sobe a atualizacao visual.
- Caso confirmado em `03/05/2026`: `firebase deploy --only functions` pode concluir com sucesso e ainda assim deixar a web antiga no ar. Esse comando sobe backend; para publicar interface Flutter web e preciso `build web` + `firebase deploy --only hosting` (ou `hosting,functions`).
- O pacote operacional minimo a entregar ao final de cada rodada e:
  - `analyze`
  - `build`
  - `deploy`
  - `AAB`
  - `copiar artefacto`

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
2. o Codex edita o codigo e, ao fim da rodada, entrega os comandos prontos para o operador executar no outro terminal
3. rodar `analyze`, `build`, `deploy`, `AAB` e `copia do artefacto` conforme a necessidade da rodada
4. usar `powershell -ExecutionPolicy Bypass -File .\scripts\guard_flutter_cycle.ps1 -Mode validate-only` antes de abrir nova frente grande ou fechar refatoracao estrutural
5. usar `powershell -ExecutionPolicy Bypass -File .\scripts\guard_flutter_cycle.ps1 -Mode web-fast` para build web rapido e `-Mode appbundle-fast` para Android rapido quando a validacao ja estiver limpa
6. se algo falhar, corrigir na mesma rodada e rerodar a guarda; nao empilhar avisos, erros de analise ou quebras estruturais para depois
7. usar `scripts/check_core_consistency.ps1` apenas como apoio quando o ambiente estiver instavel ou como fallback textual
8. revisar os arquivos centrais alterados
9. atualizar documentos de continuidade se a arquitetura mudou

## Comandos padrao para o operador

- `C:\Users\hp\flutter\flutter\bin\flutter.bat pub get` quando `.dart_tool` tiver sido limpo ou a rodada anterior tiver executado `flutter clean`
- `C:\Users\hp\flutter\flutter\bin\flutter.bat analyze --no-pub`
- `powershell -ExecutionPolicy Bypass -File .\scripts\build_flutter_direct.ps1 -Target web -NoPub`
- `cmd /c npm.cmd --prefix functions run build`
- `firebase deploy --only hosting,functions,firestore:rules,storage --project pontocerto-e1dab`
- `C:\Users\hp\flutter\flutter\bin\flutter.bat build appbundle --release --no-pub`
- `Copy-Item` apenas se `build\app\outputs\bundle\release\app-release.aab` existir

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
- Regra suprema operacional:
  - o Codex cuida apenas de codigo, rules e documentacao tecnica
  - analyze, build, deploy, AAB e copia de artefacto ficam com o operador no terminal dele
  - o Codex nao deve executar tarefas pesadas como fluxo padrao
  - ao final de cada rodada, os comandos devem ser entregues em uma unica sequencia pronta para copiar e colar no PowerShell
  - a sequencia deve parar no primeiro erro e evitar publicar artefato antigo por acidente
  - comandos sensiveis do PowerShell nao devem vir quebrados em duas linhas
