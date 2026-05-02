# Memoria e Registro Atual Oficial do Sistema

Data base: 29/04/2026
Projeto: Ponto Certo

**Registo recente (29/04/2026):** ver `registro_continuidade/REGISTRO_ATUALIZACOES.md` (**2026-04-29**): marketing WhatsApp comercial (Meta + `sales_whatsapp_comercial`), carteira contador com todos os vinculos, Functions (email interno → `fromEmail`), sessao contador em Trabalhista + inativar funcionarios, regras Firestore para patch `ativo`/`updatedAt`, protecao **suprema** (sem AAB nesta rodada). **Planeamento apenas (sem codigo de certificadora nem IBS/CBS):** [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md).

**Registo anterior (27–28/04/2026):** a governanca **Focus** (integracao, homologacao, matriz, automacao) concentra-se na **empresa suprema** na UI fiscal; as empresas concentram-se em **documentacao de provisionamento**, **cadastro**, **sincronizacao** e **emissao** — ver `registro_continuidade/REGISTRO_ATUALIZACOES.md` (secoes 2026-04-27 e 2026-04-28) e `PROMPT_ASSISTENTE_PONTO_CERTO.md`. Ultima versao Play referida no registo: **`1.0.84+1055`** (rodada 28/04); **29/04** nao gerou novo AAB.

**Complemento desta continuidade (Trabalhista/contador):** a rota do contador passou a refletir melhor a empresa **ativa** da carteira no `Trabalhista`, com apoio operacional em `Tarefas` e `Ordens de servico` apenas para itens **finalizados** e em **somente leitura**. O modulo trabalhista ganhou dossie do colaborador, checklist por competencia em `workforce_competence_obligations`, trilha de eventos em `workforce_employee_events` e snapshot com memoria de calculo por colaborador/competencia em `workforce_employee_competence_snapshots`. Essas estruturas sao apenas de conferencia/trilha e **nao** substituem as fontes de verdade ja validadas: `users`, `employee_registration_documents` e `payments`.

**Complemento adicional (fechamento trabalhista da competencia):** o modulo passou a salvar tambem um fechamento trabalhista consolidado dentro de `payroll_closures`, usando `laborClosure` e `laborLines` por competencia. Essa consolidacao deriva de snapshots do colaborador, eventos trabalhistas e checklist da competencia, com estados `pending_review`, `ready_for_close` e `closed`, sem abrir uma nova fonte de verdade separada para folha ou cadastro.

**Complemento final desta frente (workflow real):** foram ligados workflows operacionais de **ferias**, **`13o`** e **rescisao** por colaborador, ainda dentro da mesma trilha de eventos/documentos ja existente. Tambem entrou a fila de **servicos prontos para NF** dentro do trabalhista, e o fechamento da folha passou a validar o estado do fechamento trabalhista salvo antes de permitir encerrar a competencia.

## Objetivo

Este documento define onde o estado atual do sistema deve ser registrado e como manter essa memoria viva sem perder contexto.

## Estado real (verificavel) e "tempo real"

Documentos em Markdown **nao** se actualizam sozinhos. Para manter **sempre** um espelho frio e verificavel do que o repositorio diz agora (versao, projecto, URL de hosting, runtime das functions), use o ficheiro unico:

- [ESTADO_SISTEMA_VERIFICAVEL_GERADO.md](ESTADO_SISTEMA_VERIFICAVEL_GERADO.md) — tabela e regra de regeneracao; comando: `dart run tool/estado_sistema.dart` na raiz (actualiza a partir de `pubspec.yaml`, `.firebaserc`, `firebase.json` e git, quando existir).

O estado completo (produto, modulos, deploy narrado) continua no registo de continuidade e no `ESTADO_ATUAL` abaixo; o ficheiro verificavel evita desvio entre versao publicada no codigo e o que a equipa pensa que esta "no ar".

## Regra oficial

Tudo que mudar de forma relevante no sistema deve deixar rastro aqui e nos arquivos de continuidade relacionados.

Registrar sempre:

- o que mudou
- por que mudou
- onde mudou
- quando mudou
- qual risco foi eliminado ou criado

## Fontes oficiais de memoria viva

### 1. Estado operacional consolidado

- [ESTADO_ATUAL_DO_SISTEMA.md](registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md)

### 2. Memoria viva do sistema

- [MEMORIA_VIVA_SISTEMA.md](registro_continuidade/MEMORIA_VIVA_SISTEMA.md)

### 3. Registro de continuidade da rodada atual

- [CONTINUIDADE_ATUAL.md](registro_continuidade/CONTINUIDADE_ATUAL.md)

### 4. Alinhamento de modulos e permissoes

- [ALINHAMENTO_MODULOS_E_PERMISSOES.md](registro_continuidade/ALINHAMENTO_MODULOS_E_PERMISSOES.md)

### 5. Matriz de acesso

- [MATRIZ_ACESSO_PONTO_CERTO.txt](registro_continuidade/MATRIZ_ACESSO_PONTO_CERTO.txt)

## O que deve ser registrado obrigatoriamente

### Mudanca de escopo funcional

Exemplo:

- contador deixou de usar `Relatorios`
- contador ganhou leitura coerente de `Contratos` e `Documentos`

### Mudanca de fluxo fiscal real

Exemplo:

- erro `E0621` resolvido com `pAliq`
- erro `E0314` resolvido ao parar de enviar `cTribMun` automatico

### Mudanca de promessa comercial

Exemplo:

- vitrine do contador alinhada ao sistema real

### Mudanca de acesso ou rota

Exemplo:

- rota foi liberada
- CTA foi removido
- regra do Firestore foi ajustada

## Ordem de manutencao da memoria

Quando uma rodada fechar:

1. atualizar `CONTINUIDADE_ATUAL.md`
2. atualizar `MEMORIA_VIVA_SISTEMA.md` se mudou o entendimento do sistema
3. atualizar `ESTADO_ATUAL_DO_SISTEMA.md` se mudou o estado consolidado
4. atualizar `ALINHAMENTO_MODULOS_E_PERMISSOES.md` e `MATRIZ_ACESSO_PONTO_CERTO.txt` se houve mudanca de acesso
5. atualizar a documentacao comercial ou tecnica afetada

## Regra obrigatoria de execucao

Toda rodada relevante deve seguir esta sequencia:

1. descrever antes a parte visual no `OFICIAL_01`
2. descrever antes a parte funcional no `OFICIAL_02`
3. descrever antes a parte arquitetural no `OFICIAL_03`
4. implementar no codigo
5. salvar o resultado aqui e em `CONTINUIDADE_ATUAL.md`

## Regra do assistente

O assistente deve usar como base **(para alinhamento humano e de copy, e para evoluir o prompt em `PROMPT_ASSISTENTE_PONTO_CERTO.md` e as strings do backend)`**:

- `OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md`
- `OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md`
- `OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md`
- `OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md`

Em **tempo de execucao**, a resposta e gerada com instrucoes em `functions/src/index.ts` e dados do Firestore na chamada — **ver secao no `OFICIAL_02`**. Nao se assume ingestao automatica destes ficheiros Markdown pela API.

Ele nao deve responder com base em promessa antiga, vitrine antiga ou modulo ainda nao liberado.

## Regra oficial de entrega operacional

Fica registrado como regra oficial desta documentacao:

- quando houver pedido de `build`, `deploy`, `AAB`, limpeza de cache ou publicacao
- a resposta operacional final deve vir em um unico comando completo
- esse comando deve ser entregue em sequencia corrida
- nao deve haver varias opcoes para o usuario escolher
- o comando deve incluir todas as etapas necessarias do fluxo pedido

Sequencia padrao quando aplicavel:

1. `flutter clean`
2. `flutter pub get`
3. `flutter build web --release`
4. `firebase deploy --only "functions,hosting" --project pontocerto-e1dab`
5. `flutter build appbundle --release` com versao maior que a ultima
6. copia final do `.aab` para a area de trabalho

Motivo do registro:

- reduzir erro humano por quebra de linha no terminal
- evitar execucao parcial
- manter consistencia operacional entre web, backend e Android

## Estado oficial atual resumido

- **Publicacao / deploy (23/04/2026)**: executado `flutter build web --release` e `firebase deploy --only hosting --project pontocerto-e1dab`; site: `https://pontocerto-e1dab.web.app` — apos ver alteracoes, usar hard refresh (Ctrl+F5) ou janela anonima. **Functions** nao foram redeployadas nesta sequencia (alteracoes foram sobretudo front + docs); se mudar logica do assistente no `index.ts`, incluir `firebase deploy --only functions`

## Registro de rodada: login e governanca (26/04/2026)

Foi fechado ajuste de fluxo para impedir que o usuario autentique, veja erro/rota antiga e precise atualizar o navegador para entrar:

- empresa, contador, funcionario e rota legada `/login` passam a atualizar o `GoRouter` apos definir `sessionProvider`
- o redirect central evita mandar usuario ja autenticado para `/inicio` por erro transitorio de sincronizacao Firebase/sessao
- validacao executada: `flutter analyze` nos arquivos de login e roteador, sem issues

Tambem foi fechado o primeiro bloco de governanca real da plataforma:

- `platformListSalesPipeline` passou a retornar `governanceIssues`
- o painel mostra alertas de webhook Asaas sem cadastro financeiro vinculado
- o painel mostra cobranca pendente/vencida/falha do escritorio contabil
- o painel mostra empresa aguardando vinculo feito pelo contador
- o painel mostra falha automatica de cobranca de implantacao
- o ciclo do onboarding aparece como rastreio operacional: lead -> cobranca/pagamento -> onboarding -> empresa criada -> contador/escritorio informado -> cobranca recorrente

Regra registrada: o contador e quem vincula empresa ao escritorio dele; a plataforma evidencia pendencia, mas nao deve tratar isso como se fosse criacao automatica obrigatoria pela administracao.

## Registro de rodada: documentos do contador multiempresa (26/04/2026)

Foi ajustado o modulo `Documentos` para o contador operar de forma independente e segura por empresa:

- `Solicitar documento` continua criando pedido para empresa ou funcionarios especificos
- `Enviar documento` passa a ser independente e pode criar envio avulso com anexos, sem depender de solicitacao anterior
- os dois fluxos usam sempre `session.companyId`, ou seja, a empresa ativa escolhida na carteira do contador
- os funcionarios exibidos nos dialogos sao carregados somente da empresa ativa
- o upload valida que o documento pertence a empresa ativa antes de gravar arquivos
- validacao executada: `flutter analyze lib/features/document_drafts/presentation/pages/document_drafts_page.dart`, sem issues

## Registo alinhado ao dialogo de continuidade (23/04/2026)

O que foi feito no codigo e esta **reflectido** nos `OFICIAL_01` a `OFICIAL_04` (visao, funcional, arquitectura, memoria):

1. **Navegacao do painel**: `ShellRoute` + `AppRouteShell`; rotas publicas/login/marketing **fora** do shell; rotas do painel **dentro** — menu lateral estavel.
2. **Chrome por pagina**: `shellPageChromeProvider` / `ShellPageChrome` (titulo opcional, header, accoes, `beforeLogout`); titulo por omissao via `AppShellScaffold.titleForPath`.
3. **Paginas**: remocao do padrao `return AppShellScaffold(...)` nas ecras do painel; definicao de chrome + retorno so do conteudo que era `body`.
4. **Avisos globais**: `ValueNotifier` + `OverlayEntry` no `Navigator` raiz (`appRootNavigatorKey`); remocao do `Stack` com barra no `builder` do `MaterialApp` em `app.dart`.
5. **Menu (scroll)**: `ScrollController` por instancia do menu; `shell_menu_scroll.dart` mantem offset global entre rotas; sem `PageStorageKey` antigo no `ListView` do menu (conflito com a restauracao).
6. **Correccoes de sintaxe**: fechamento de parentesis apos refactor em varios ecras (ex.: fiscal, plataforma, catalogo, empresa, feedback) — manutencao interna, sem promessa de produto novo.
7. **Assistente (verdade tecnica)**: documentado que a resposta **nao** le os ficheiros `OFICIAL_*.md` por request; instrucoes em `functions/src/index.ts` + Firestore na chamada.

O que **nao** entra como “funcionalidade nova” nos OFICIAL: pormenores de refactor file-a-file (dezenas de `lib/features/**`) — a regra consolidada e a do item 3; listagem de ficheiros centrais esta no `OFICIAL_03`.

### Resumo de rodada (lista continua)

- **23/04/2026**: navegacao do painel migrada para `ShellRoute` + `AppRouteShell`; avisos globais do utilizador passam por `Overlay` no `Navigator` raiz; `shellPageChromeProvider` define cabecalhos/accao por pagina
- auditoria de coerencia de rotas, menu, CTAs, promessa comercial e Firestore foi fechada
- escopo do contador esta alinhado ao sistema real
- fluxo NFSe Nacional com Focus esta operacional no caso validado
- fluxo NFSe Nacional com `Simples Nacional` passou a distinguir corretamente envio de aliquota com e sem retencao de ISS
- resumo fiscal da competencia foi alinhado para refletir apenas notas oficiais ativas no valor bruto e nos tomadores
- observer fiscal passou a reconstruir o agregado da empresa a partir de `service_invoices`, ignorando notas canceladas mesmo quando ainda existe `officialNumber`
- o modulo fiscal ganhou limpeza em lote para notas canceladas, rascunhos e erros de emissao sem financeiro vinculado
- foram criados arquivos separados de referencia rapida para `Focus` e `Asaas` em `docs/INTEGRACAO_FOCUS.txt` e `docs/INTEGRACAO_ASAAS.txt`
- os emails voltados para escritorio contabil passaram a carregar assinatura institucional unica com apresentacao real do fundador e origem pratica do sistema
- a frente comercial publica passou a priorizar escritorio contabil como contato principal do convite e do onboarding
- a entrada publica foi reforcada para cadastrar primeiro o escritorio de contabilidade, deixando o cadastro da empresa para o modulo interno do escritorio
- a leitura do resumo fiscal deve considerar apenas notas oficialmente emitidas e ativas no valor bruto agregado
- o modulo `Documentos` foi convertido em canal de solicitacoes entre contador, empresa e funcionarios, com pedidos separados por solicitacao
- o app do funcionario passou a poder receber pedidos de documentos encaminhados pela empresa ou enviados diretamente pelo contador
- o contador passou a poder anexar documentos dentro do pedido para assinatura, preenchimento ou devolucao pela empresa/funcionario
- o modulo `Documentos` passou a exigir padrao de envio com botao explicito de `Enviar documento` ao lado do fluxo de solicitacao quando o perfil comporta as duas acoes
- o formulario de `Servicos fiscais` entrou em ajuste para normalizacao automatica de formato antes de salvar, reduzindo erro operacional de preenchimento
- notificacoes administrativas de cadastro passaram a ser parte obrigatoria do fluxo de escritorio, empresa e vinculo de contador
- a entrada comercial publica passou a operar com teste real gratis de 30 dias no sistema inteiro, sem cobranca de implantacao, exigindo contador indicado pela empresa; o fluxo correto agora e: primeiro cadastro do escritorio contabil e depois cadastro da empresa indicada
- o escritorio contabil passou a ter assinatura base prevista de R$ 97,90 por mes, com opcao de isencao comercial por parceria aprovada
- versao local atual de referencia: `1.0.78+1048`
- esta secao da rodada foi consolidada documentalmente e tecnicamente ate 23/04/2026
- documentacao oficial do assistente (OFICIAL) distingue **fonte humana** (Markdown) de **fonte em runtime** (strings + Firestore no `index.ts`); ver `OFICIAL_02`

## Registro de continuidade da rodada fiscal e mensagens (25/04/2026)

Esta rodada consolida ajustes que devem ser considerados pelo assistente e por futuras manutencoes:

1. **Avisos globais**: mensagens operacionais de sucesso/erro usam `AppUserMessage` em `OverlayEntry` no `Navigator` raiz (`appRootNavigatorKey`). A mensagem deve aparecer no topo, por cima de telas e dialogos, e sair apenas no `OK`. Nao reintroduzir `Stack` externo envolvendo `MaterialApp.router`, pois isso ja causou travamento de navegacao.
2. **Servicos fiscais**: o cadastro/edicao de servico fiscal precisa exibir retorno claro ao usuario. O seletor de servico na emissao usa somente itens salvos e ativos no catalogo da empresa; nao misturar servicos fixos/hardcoded no dropdown quando o usuario esta conferindo o que salvou.
3. **Notas Focus autorizadas**: o status oficial consolidado para nota autorizada passa a ser `APPROVED`. O status `EMITTED` fica como legado/compatibilidade de leitura. Resumos e relatorios devem usar `approvedInvoicesCount` para quantidade e somar valor bruto apenas de notas autorizadas/registradas e nao canceladas.
4. **Numero oficial Focus**: a leitura do numero da NFS-e deve considerar `officialNumber` e a resposta oficial aninhada (`officialResponse`), pois a Focus pode retornar o numero em chaves e objetos diferentes.
5. **Redundancia fiscal**: evitar reabrir separacao funcional entre `emitida` e `aprovada/autorizada`. Para o usuario, o registro oficial bem-sucedido deve aparecer como `Aprovada / autorizada`.
6. **Pagina de vendas**: a proxima alteracao de copy/imagens deve manter `/vendas` responsiva/adaptativa para celular e computador. A pagina deve reorganizar blocos por largura/plataforma sem criar promessa comercial fora do sistema real.

## Registro de rodada: documentacao segura certificadora + IBS/CBS (29/04/2026)

Foi **registado** (sem implementar) o plano em [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md): fluxo futuro de certificadora no perfil contador com ponte para `fiscalCertificate`/Focus; e fases **F1–F7** para preparacao **IBS/CBS** com campos opcionais, logs, simulador isolado e **flags desligadas** — **proibicao** de alterar payload de emissao real ate decisao. A execucao sera passo a passo apos alinhar `OFICIAL_01`–`03`. Detalhe operacional da rodada (marketing, carteira, Functions, Trabalhista, suprema, deploy web, **sem AAB**): `registro_continuidade/REGISTRO_ATUALIZACOES.md` **2026-04-29**.

**Correcao subsequente — WhatsApp nas landings (Web):** o **`Link`** do `url_launcher` no Flutter Web pode falhar com botoes so no canvas quando os dois sinais (`followLink` + evento DOM no `<a>` da platform-view) nao batem (**`preventDefault`** -> navegacao abortada sem erro visivel). Meta Pixel/`fbq`/microtasks a seguir ao clique podem agravar. **Implementacao atual:** **`AnchorElement`** + **`click()`** no mesmo stack do **`onPressed`** (`vendas_whatsapp_web_anchor_web.dart`), com abertura **na mesma aba** (`target: _self`) para evitar bloqueio silencioso de nova aba; Pixel e `sales_whatsapp_comercial` apenas apos **`Timer`(400 ms)** (`scheduleWhatsappComercialSignals` em `vendas_whatsapp_button.dart`).

## Documentos relacionados

- [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md) — planeamento **nao implementado**
- [ESTADO_SISTEMA_VERIFICAVEL_GERADO.md](ESTADO_SISTEMA_VERIFICAVEL_GERADO.md)
- [OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md](OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md)
- [OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md](OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md)
- [OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md](OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md)
