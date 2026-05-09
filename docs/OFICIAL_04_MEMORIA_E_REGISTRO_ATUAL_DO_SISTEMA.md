# Memoria e Registro Atual Oficial do Sistema

Data base: 08/05/2026
Projeto: Ponto Certo

## Divisao oficial dos quatro documentos (ligacao entre si)

| Documento | Papel |
|-----------|--------|
| **OFICIAL_01** | Visual do **Ponto Certo** (este repo). |
| **OFICIAL_02** | Funcional do **Ponto Certo**. |
| **OFICIAL_03** | Arquitectura tecnica do **Ponto Certo** (+ backend **`engineeringAgent*`** partilhado com ferramentas externas ao mono-repo). |
| **OFICIAL_04** (este) | **Memoria**: decisoes, datas, versao; ponte quando algo (ex.: **Studio** desktop) **nao** esta no codigo deste repo mas afecta continuidade ou operadores. |

Este ficheiro **nao** substitui 01–03 em visual/funcional/arquitectura; regista *o que foi acordado* para nao ficarem «desligados» uns dos outros.

**Registo (09/05/2026 — Doc ERP vs Studio):** um commit anterior (**649eaa1**) tinha **removido** referencias ao **Studio Ponto Certo** nos OFICIAL deste repo («ambito so Ponto Certo»), o que gerou confusao operacional (parecia que o Studio «voltou» a ser so ERP). **Repoe-se** aqui e nos outros OFICIAL a distincao: **`pontocerto.exe`** + **`pontocerto-e1dab`** versus **`StudioPontoCerto`** + **`studiopontocerto`** + mesmo pipeline **`engineeringAgent*`**.

**Registo (08/05/2026 — Windows exe ERP vs Studio):** o cenario «executavel no PC a nao responder» ou diferencas de **login** podem referir-se ao **Studio** (repo **`StudioPontoCerto`**, Firebase **`studiopontocerto`**, Callable **`studioWindowsEmailPasswordExchange`**, IAM **`serviceAccountTokenCreator`** na conta adminsdk do Studio) ou ao **Ponto Certo** (**`pontocerto.exe`**, **`pontocerto-e1dab`**). No **Ponto Certo** mantem-se melhorias de arranque Windows (Firebase **`windows`**, **`usePathUrlStrategy`** so Web, Firestore sem persistencia local no Windows). No Studio aplicam-se ajustes na copia local (frames antes de **`Firebase.initializeApp`**, worker **`node src/index.js`**, etc.) — ver docs OFICIAL **dentro** de **`C:\StudioPontoCerto`**.

**Registo (07/05/2026 — Agente de Engenharia: Plataforma + publicacao web):** UI **fora da Governanca** — rota **`/platform-admin/agente-engenharia`**, primeiro item do submenu **Plataforma > Agente Engenharia** (apenas **OWNER empresa suprema**); cartao removido do hub Governanca; link antigo `?v=engineering_agent` redireciona para a nova rota. Layout orientado a chat: barra compacta (projeto, modo, novo projeto, menu **Entrega e acoes**); lista de sessoes em coluna (desktop) ou folha inferior (ecra estreito); area de mensagens em altura flexivel; campo de escrita multilinha. Publicacao confirmada pelo operador: build web + deploy **`functions` + `hosting`**. Prompt OpenAI e janela de historico nas Functions **sem mudanca funcional nesta rodada** (continua `buildEngineeringAgentSystemPromptPontocerto` / `buildEngineeringAgentSystemPromptExternal`, ultimas **16** mensagens por pedido, `temperature` **0.2**).

**Registo (06/05/2026 — Agente de Engenharia v2 modos + projetos):** UI com seletor de projeto, badges Modo PontoCerto / externo / novo, cadastro `engineering_agent_projects`, prompts isolados para externo, marcadores RISCOS/IMPACTO/PATCH_PREVIEW, callables `engineeringAgentListProjects`, `CreateProject`, `SelectProject`, `GenerateCommand`, `RegisterContinuity`, drafts em `engineering_agent_patches`, prefs `engineering_agent_operator_prefs`, contextos `engineering_agent_project_contexts`. Worker local especificado em `docs/engineering_agent_worker/README.md`. Sem `REGISTRO_ATUALIZACOES` ate publicacao.

**Registo (06/05/2026 — Governanca Agente de Engenharia — rota UI sobrescrita em 07/05):** o modulo passou da entrada **`/platform-admin/governanca?v=engineering_agent`** para **`/platform-admin/agente-engenharia`** (mantendo `EngineeringAgentPage`, feature `lib/features/governance_engineering/`): sessoes, chat, slots estruturados extraidos da resposta (marcadores), acoes via menu **Entrega**. Backend inalterado: callables `engineeringAgent*`; autorizacao **apenas empresa suprema** (`assertSupremePlatformAccess`); OpenAI **mesma configuracao do assistente** no servidor; Firestore `engineering_agent_sessions` + `messages`, patches/tasks/audit sem acesso cliente nas rules.

**Registo (06/05/2026 — PDF tarefas cliente, lista vertical + totais utilizados + UI totais materiais):** PDF de tarefa (`task_details_media_pdf.dart`): servicos e materiais em **cartao unico** cada, **numeracao um item por linha**, texto sem pontuacao tipografica problematica; totais fora do cartao; **Valor total** no topo e total geral no resumo = **servicos + apenas materiais utilizados**; materiais no corpo com `_resolverMateriaisPdf` (fallback ao previsto se finalizado sem utilizados). Na UI do detalhe da tarefa: **Valor total - materiais previstos** e **Valor total - materiais utilizados**. Publicacao web validada: `flutter build web --release` + `firebase deploy --only hosting`. Ver `REGISTRO_ATUALIZACOES.md` (**2026-05-06**).

**Registo (06/05/2026 — governanca e-mail em massa + shell colar + precos em materiais):** painel **E-mail em massa** na governanca (`platformGovernanceCollectAudienceEmails`, `platformGovernanceSendAudienceEmail`, `GovernanceBulkEmailPanel`). `app_shell`: listeners com **HitTestBehavior.deferToChild** para nao roubar foco ao colar em campos. **MaterialTarefa** com valor unitario e total de linha. O PDF final do cliente segue o registo imediatamente acima (lista vertical, totais utilizados no topo).

**Registo (06/05/2026 — pre-cadastro leve empresa/escritorio: falso erro apos sucesso):** o cliente fazia parse com `response.data as Map`, o que pode falhar em web/interop mesmo com Callable OK; falhas subsequentes em analytics/Meta faziam cair no `catch` genérico "Erro ao criar acesso" após o servidor já ter criado conta e disparado e-mail (`mapFromCallableData`, analytics em try/catch, `GoRouterState` capturado antes do await). Backend: `notificarNovoCadastroAdministrativo` em `publicCreateCompanyWorkspaceAccess` e `publicCreateAccountantWorkspaceAccess` envolvido em try/log para não derrubar a resposta mesmo se algo escapasse. Serviço `AccountingOfficeSignupService` usa o mesmo parser em todas as callables públicas relacionadas.

**Registo (06/05/2026 — layout web + formularios leves UF/cidade/CEP):** `MaterialApp` `Stack` com **`fit: StackFit.expand`** para corrigir viewport em desktop/web com FAB WhatsApp. Pre-cadastro empresa leve (`PaginaCadastroEmpresa` lightweight) e escritorio leve (`AccountingOfficeSignupPage`): bloco geografico com **`ExternalLabeledField`**, hints sem label interno e **coluna** em ecrans \< ~560 px. Ver `OFICIAL_01` e `OFICIAL_03`.

**Registo (05/05/2026 — build Android Play / AAB 1.0.88+1059):** geração de bundle de release (**`versionName` 1.0.88**, **`versionCode` 1059**), anterior **`pontocerto-1.0.87+1058.aab`**. Inclui todas as alterações já em `master` até esta rodada incluindo FAB WhatsApp suporte global (`GlobalWhatsappSupportFab`, `kWhatsappSupportNumberE164`), documentação oficial alinhada e incremento de versão (`pubspec.yaml`) para evitar conflito com upload anterior na Play Console. Artefacto Gradle: `build/app/outputs/bundle/release/app-release.aab`; cópia recomendada na área de trabalho como **`pontocerto-1.0.88-1059.aab`**.

**Registo (05/05/2026 — FAB WhatsApp suporte global):** `MaterialApp.router` (`lib/app/app.dart`) passou a usar `Stack` no `builder` com `GlobalWhatsappSupportFab` (`lib/core/widgets/global_whatsapp_support_fab.dart`); numero E.164 unico em `lib/core/constants/whatsapp_support.dart` (`kWhatsappSupportNumberE164`), reaproveitado por `buildVendasWhatsappUri`; abertura igual ao comercial (`abrirWhatsappVendas` + mensagem inicial de duvida/informacao). Ver `OFICIAL_01`, `OFICIAL_02`, `OFICIAL_03`.

**Registo (03/05/2026 — auditoria Focus XML contador/empresa):** painel de importacao NF-e/NFS-e nacional extraido para `FocusIncomingXmlSection` (servico `FocusIncomingXmlService`); aparece em `/fiscal` e em `/accountant-declarations`; ambiente registado pelo backend em `xml_sync_state.*.environment`. Callables `fiscalSyncFocusIncomingDocuments` e `fiscalDownloadImportedXml` passam por `assertNotDemoReadOnly`. Ver `OFICIAL_02`.

**Registo (03/05/2026 — URLs `pre-cadastro-*`, formularios e governanca comercial):** CTAs (`/inicio`, `/login-empresa`, `/login-contador`, `/vendas`, `/vendas-empresa`, `/vendas-contador`) passam a abrir **`/pre-cadastro-empresa`** e **`/pre-cadastro-escritorio`**; governanca (**Funil**, **Links**, secao **Convidar**) usa os mesmos paths nas legendas e remove destaque legado de "planos clicados" / `topPlans`. Pre-cadastro contador leve ganha linha **UF · cidade · CEP** na UI + copy mais curta. `platform_admin_page` import de `sessionProvider` para gate de acesso. Correcçao menor: `cadastro_empresa_page` BrandLogo ja nao e `const` com tamanho condicional.

**Registo (03/05/2026 — governanca modular + funil + origem de lead):** `/platform-admin/governanca` passou a hub com cartões e sub-paineis por query `?v=` (`funil`, `precadastro_empresas`, `precadastro_escritorios`, `cadastro_completo`, `demo`, `links`). O painel **Funil** usa `platformGetMarketingDashboard` com eventos dedicados de page view e lead do pré-cadastro empresa leve. O pré-cadastro empresa (`/cadastro-empresa`) pode levar `uf`/`estado`, `cidade`, `cep` na query: o servidor grava em `company_settings.directSignup.leadOrigin` e a governança mostra a origem na lista leve. Meta Pixel na web: `ViewContent` + `Lead` no fluxo leve. Ver `OFICIAL_02` e `OFICIAL_03`.

**Registo (03/05/2026 — performance web cargas):** `main.dart` paraleliza `initFirebase()` com `lerNomeEmpresaCache()`; Firestore **`persistenceEnabled: true`** apos init; `web/index.html` preconnect+dns-prefetch + Meta Pixel apos **`load`**; navegacao interna na web usa **`FadeUpwardsPageTransitionsBuilder`**; Hosting long-cache **`*.wasm`** e **`canvaskit/**`** (`firebase.json`).

**Registo (06/05/2026 — governanca SaaS: apagar teste alinhado + Asaas por empresa):** funcao partilhada `evaluateStandaloneLightweightTestDeletionGate`, campos `standaloneDeletionAllowed` na listagem, callables `platformGovernanceCompanyCancelAsaasBilling`, `platformGovernanceCompanyCancelPendingAsaasPayments`, `platformGovernanceCompanySetSuspended` e reorganizacao visual da pagina `/platform-admin/governanca`. Ver `OFICIAL_02` e `OFICIAL_03`.

**Registo (04/05/2026 — copy `/vendas-empresa` sem redundancia MEI/contador):** removidos da heroi (subhead/badge), modelo atual, passo 3, bloco pre-cadastro e bullets tarifarios os trechos que repetiam "nao obriga contador/MEI/WhatsApp"; esse argumento ficou apenas no paragrafo do cartao **Demonstracao gratuita do sistema** sob orientacao ao demo. Ver `OFICIAL_01` e `OFICIAL_02`.

**Registo (03/05/2026 — copy vendas empresa/contador demo + avaliacao):** `/vendas-empresa` e `/vendas-contador` alinham heroi (subhead e badges) e card **Demonstracao gratuita do sistema** com linguagem institucional unificada (demonstracao antes de adesao; trinta dias avaliativos apos adesao formal). Ver `OFICIAL_01`.




**Registo (03/05/2026 — demo entra direto home/contador):** `PublicDemoAccessPage` e botoes demo em `SalesPage` hidratam **`sessionProvider`** via `session_hydrate_from_auth.dart` (`loadRiverpodSessionForAuthUser`) imediatamente apos token; **`public_demo_workspace`** nao bloqueado por ciclo comercial/`company_settings` no bootstrap nem por activacao `/ativacao-empresa`; `syncClaimsForCurrentUser` + `getIdToken(true)` pos-demo no service.

**Registo (03/05/2026 — demo runtime SA adminsdk):** `publicOpenDemoAccess` volta a `runWith`, desta vez com **`serviceAccount: firebase-adminsdk-fbsvc@pontocerto-e1dab.iam.gserviceaccount.com`** (callable sem Secret). IAM sobre `firebase-adminsdk`: acrescentado binding **Token Creator** do proprio membros adminsdk sobre a mesma conta. Motivo: utilizador continuava bloqueado por permissao mesmo com Token Creator appspot/compute → adminsdk.

**Registo (03/05/2026 — IAM only demo + landing empresa MEI/WhatsApp):** verificacao `gcloud iam service-accounts get-iam-policy firebase-adminsdk-fbsvc@pontocerto-e1dab.iam.gserviceaccount.com`: ja existem `roles/iam.serviceAccountTokenCreator` + `roles/iam.serviceAccountUser` para `1074663509241-compute@developer.gserviceaccount.com` e `pontocerto-e1dab@appspot.gserviceaccount.com`. **`publicOpenDemoAccess`** removeu `runWith({ secrets: [ADMIN_SDK_AUTH_CERT_JSON] })` (`defineSecret` retirado) — deploy deixa de depender do Secret Firebase para essa callable; IAM permanece obrigatorio. `/vendas-empresa`: texto retira atalho "Sou contador" e acrescenta clareza juridico-comercial: MEI/sem contador que domina obrigacoes pode seguir sem contratar; WhatsApp como canal alternativo aos botoes existentes.


**Registo (03/05/2026 — demo custom token fallback Secret, historico — removido do deploy IAM-only):** apesar IAM `Token Creator` + `serviceAccountUser` em `firebase-adminsdk`, producao continuava com `signBlob` negado; `publicOpenDemoAccess` ganhou Secret **`ADMIN_SDK_AUTH_CERT_JSON`** (`defineSecret`), segunda app Admin com cert JSON e criacao local do token; mensagens IAM referenciam esse fallback operacional — chave gerada apenas fora do Git; `firebase functions:secrets:set` + redeploy.


**Registo (03/05/2026 — livro demo governanca sem rede/aparelho):** `platformListPublicDemoAccessLedger` deixa de devolver IP, hash parcial, user-agent, visitorIds, idioma, resolucao e tipo de dispositivo — apenas contagens, papeis demo (empresa/contador) e datas de primeiro/ultimo acesso; dedupe continua no documento `dv1_*` no Firestore. UI Governanca e textos de cabecalho alinhados.

**Registo (03/05/2026 — governanca cadastro real pos-teste + demo erro UX):** callable `platformListGovernanceRealRegistrations` lista empresas/escritorios que completaram perfil pos-entrada leve (excl. demo fixo); UI Governanca ganha cartao **Cadastro real (acompanhamento pos-teste)**. Pagina `/demo-*` (`PublicDemoAccessPage`): remover spinner quando falha, links para Firebase custom tokens + consola de contas de servico GCP do `projectId` actual. IAM em producao permanece obrigatorio: **Token Creator** da SA das Functions sobre **firebase-adminsdk**.

**Registo (03/05/2026 — plataforma governanca):** novo submenu Plataforma > **Governanca** (`/platform-admin/governanca`): empresas com cadastro **leve** pendente (`lightweightProfilePending`) e livro anonimizado dos **acessos demo** (`platformListPublicDemoAccessLedger`). `platformListCompanies` faz **dedupe por `companyId`** (owner mais antigo). Demo publico grava documentos em `demo_access` com id `dv1_*` (hash IP + fingerprint leve navegador) para nao multiplicar unicos quando muda apenas o visitor de marketing. Indice novo `users`: `role` + `lightweightProfilePending`. Flutter: erro `functions/internal` continua a mostrar a mensagem do servidor quando existe (IAM/diagnostico). O **signBlob** em producao resolve-se na mesma obrigatorio com papel Token Creator sobre firebase-adminsdk.


**Registo (03/05/2026 — governanca exclusao teste):** na Governanca, exclusao pontual de empresa e escritorio **apenas cadastro leve** via `platformDeleteLightweightTestCompany` e `platformDeleteLightweightTestOffice`; lista de escritorio leve com `platformListLightweightTestOffices`.

**Registo (03/05/2026 — demo e contador leve):** `publicOpenDemoAccess` e `publicCreateAccountantWorkspaceAccess` mapeiam erros típicos de IAM `signBlob`/`serviceAccountTokenCreator` para `HttpsError` `failed-precondition` em portugues. `provisionLightweightOfficeAccess` passa `omitUndefinedForFirestore` nos documentos escritorio utilizador e trata falha de primeiro e-mail com `logger.warn` + `missingInviteConfig`, alinhado à empresa — o comportamento efectivo da demo/links de redeinicao ainda depende de IAM correcto na conta de servico das Functions sobre firebase-adminsdk.

**Registo recente (03/05/2026 — continuidade tarde):** demo publico sem leitura de `companyId`/UID gravados na configuracao da plataforma (workspace e contas demo fixos). Pre-cadastro comercial nao falha mais quando o envio de e-mail esta mal configurado (`precadastroEmpresaEmailOk` / `conviteParceiroEmailOk` na resposta). Forms de cadastro leve de empresa e de escritorio sem campo de senha — fluxo passa a depender do link no e-mail. Cadastro publico completo de empresa, apos liberacao, redirecciona para login em vez de `signIn` automatico. Copys de `/vendas` e pre-cadastro comercial repactuadas para linguagem mais institucional.

**Registo complementar (03/05/2026 — entrada publico e demo):** na `SalesPage` (`/vendas`) foram separados dois CTAs (empresa `→` `/cadastro-empresa`, escritorio `→` `/cadastro-escritorio-contabil`) corrigindo o helper antigo que, apesar do nome “escritorio”, abria empresa; `/inicio` passa a navegar primeiro e usar `metaFbqTrackStartTrialEmpresa`; `/login-empresa` ganhou link “Criar acesso da empresa”; `/vendas-empresa` atalho texto para escritorio; `vendas_contador_page` navega primeiro e dispara Pixel depois. No backend, `ensurePublicDemoAuthUser` cobre remocao de contas demo no Auth e colisoes `auth/email-already-exists` / `auth/uid-already-exists` ao `createUser`, reduzindo `internal` no `publicOpenDemoAccess`.

**Registo (03/05/2026 — precadastro e Firestore):** corrigiu-se falha interna ao gravar `company_settings` porque o Firestore nao aceita `undefined`; `buildDefaultCommercialSettings` sai sanitizado (`omitUndefinedForFirestore`). Queries de lead/onboarding combinando cliente + planCode passaram a usar um unico filtro equivalente onde aplicavel (`findSalesLeadDocByCustomerEmailAndPlan`). `publicOpenDemoAccess` regista erro nao tratado sob `HttpsError internal` com mensagem detalhada. UI leve empresa e solicitacao comercial comunicam quando o e-mail automatico falhou (dependencia de MAIL_FROM/SMTP ou SendGrid).

**Registo recente (03/05/2026 — manha):** ver `registro_continuidade/REGISTRO_ATUALIZACOES.md` (**2026-05-03**): os CTAs publicos foram reconduzidos para o fluxo correto de cadastro do escritorio (`/cadastro-escritorio-contabil`), o alias `/contratar` voltou a seguir essa mesma regra, o demo publico ganhou blindagem extra contra erro `internal` por reutilizacao de usuario Auth demo, os e-mails de acesso de escritorio/empresa passaram a sair com criacao de senha, link web e aviso de Play Store em teste, e o pre-cadastro comercial passou a criar acesso leve e disparar esse mesmo envio ja na primeira etapa.

**Registo recente (02/05/2026):** ver `registro_continuidade/REGISTRO_ATUALIZACOES.md` (**2026-05-02**): build Android gerada em **`1.0.87+1058`** (`pontocerto-1.0.87-1058.aab`), consolidacao final do fechamento trabalhista por competencia, correcao de build nas telas de governanca/folha/apoio do `Trabalhista`, regeneracao de `ESTADO_SISTEMA_VERIFICAVEL_GERADO.md` e alinhamento dos documentos oficiais para a versao atual.

**Registo anterior (29/04/2026):** ver `registro_continuidade/REGISTRO_ATUALIZACOES.md` (**2026-04-29**): marketing WhatsApp comercial (Meta + `sales_whatsapp_comercial`), carteira contador com todos os vinculos, Functions (email interno → `fromEmail`), sessao contador em Trabalhista + inativar funcionarios, regras Firestore para patch `ativo`/`updatedAt`, protecao **suprema** (sem AAB naquela rodada). **Planeamento apenas (sem codigo de certificadora nem IBS/CBS):** [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md).

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

- **nao reinventar** fluxos operacionais que **ja funcionam**: para publicacao web/backend seguir o comando unico historico em `README_OFICIAL_DOCUMENTACAO.md`; mudar o comando oficial **somente** apos problema real do fluxo atual **e** atualizacao conjunta da documentacao com o novo padrao testado
- quando houver pedido de `build`, `deploy`, `AAB`, limpeza de cache ou publicacao
- antes de `firebase deploy`, sessao Firebase CLI valida (`firebase login` quando necessario)
- a resposta operacional final deve vir em um unico comando completo
- esse comando deve ser entregue em sequencia corrida
- nao deve haver varias opcoes para o usuario escolher
- o comando deve incluir todas as etapas necessarias do fluxo pedido

Sequencia padrao quando aplicavel (equivale ao comando unico em `README_OFICIAL_DOCUMENTACAO.md`):

1. `flutter pub get`
2. `flutter build web --release`
3. `npm run build` na pasta `functions`
4. `firebase deploy --only functions,hosting` (projeto default `pontocerto-e1dab` via `.firebaserc`)

Quando aplicavel noutras rodadas: `flutter clean`; `flutter build appbundle --release`; copia final do `.aab`.

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
- versao local atual de referencia: `1.0.87+1058`
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

## Memoria rodada: cadastro empresa + marca integrador + assistente (05/05/2026)

- Liberada edicao alargada na rota **Empresa** com **Buscar CNPJ** para preencher dados oficiais quando disponiveis.
- Textos fiscais orientados ao utilizador normal e ao contador **omitiram** a marca comercial do integrador tecnico nas telas afectadas; empresa suprema mantem leitura tecnica completa onde aplicavel.
- Cloud Function do assistente (`buildAssistantInstructions`): instrucao de sistema com **caminhos explicitos** dos quatro `OFICIAL_*.md` no repositorio e inventario/guia `/fiscal` neutralizados relativamente a marca do integrador.

## Checkpoint publicacao one-shot e retorno Git (05/05/2026)

**Objetivo:** fixar no registo oficial onde foi parada a linha de código e qual comando publica **Web + Functions + AAB** de seguida, para retorno ou auditoria.

### Versao Android / nome no `pubspec.yaml`

- `version: 1.0.88+1059` (`versionName` 1.0.88, `versionCode` / build 1059)

### Commit Git do codigo funcional desta rodada (empresa/CNPJ, copy integrador, assistant, OFICIAL anteriores)

- `8f8e8cd` — *Liberar edicao empresa com busca CNPJ, texto integrador neutro na UI e prompts do assistente alinhados aos OFICIAL.*

Para inspeccionar apenas esse ponto: `git show 8f8e8cd --stat`

Para **desfazer só essa alteracao** numa branch limpa: `git revert 8f8e8cd` *(gera um commit reverso; resolver conflitos se aparecerem).*

**Registo desta subsecao no GitHub:** commit `15a6bcf` na branch `master` (texto do checkpoint e comando one-shot em `OFICIAL_04`).

### Comando unico de publicacao (PowerShell)

Executa **um** bloco, na ordem: dependencias Flutter, build **web** release, build **app bundle** release, copia do `.aab` para a **Area de trabalho**, compilacao **TypeScript** das Functions, **deploy** Hosting + Functions (*nao* inclui Play Console — o AAB sobe manualmente com o ficheiro gerado*).

```powershell
cd C:\Users\hp\pontocerto; flutter pub get; flutter build web --release --no-wasm-dry-run; flutter build appbundle --release; Copy-Item -Path "C:\Users\hp\pontocerto\build\app\outputs\bundle\release\app-release.aab" -Destination "$env:USERPROFILE\Desktop\app-release.aab" -Force; cd functions; npm run build; cd ..; firebase deploy --only hosting,functions --project pontocerto-e1dab
```

### Artefactos esperados após o comando

- Web: saida em `build/web/` e ficheiros activos no Hosting apos deploy.
- Android: `build\app\outputs\bundle\release\app-release.aab` e copia em `%USERPROFILE%\Desktop\app-release.aab`.
- Functions: `functions\lib\` actualizado pelo `tsc` e codigo em producao apos `firebase deploy`.

## Documentos relacionados

- [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md) — planeamento **nao implementado**
- [ESTADO_SISTEMA_VERIFICAVEL_GERADO.md](ESTADO_SISTEMA_VERIFICAVEL_GERADO.md)
- [OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md](OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md)
- [OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md](OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md)
- [OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md](OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md)
