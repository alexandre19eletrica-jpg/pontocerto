# Arquitetura Tecnica Completa do Sistema

Data base: 08/05/2026
Projeto: Ponto Certo

## Objetivo

Este documento consolida a arquitetura tecnica oficial do sistema para desenvolvimento, auditoria e continuidade.

## Divisao oficial dos quatro documentos (ligacao entre si)

| Documento | Conteudo |
|-----------|----------|
| **OFICIAL_01** | **Visual**. |
| **OFICIAL_02** | **Funcional** — referencia de comportamento. |
| **OFICIAL_03** (este) | **Arquitectura** — como o codigo e os servicos realizam o funcional. |
| **OFICIAL_04** | **Memoria** — decisoes e cronologia; consultar quando houver duvida entre «o que dizia o doc» e «o que ficou decidido». |

**Codigo neste repositorio (`lib/`, `functions/`, etc.)** implementa o **Ponto Certo**. O **Studio Ponto Certo** (desktop IDE, repo separado) **nao** esta na arvore Flutter deste mono-repo, mas **consome** os mesmos callables **`engineeringAgent*`** (regiao **`us-central1`**) expostos pelo backend acordado para o agente; configuracao Firebase **do Studio** e projecto **`studiopontocerto`**, distinto do **`pontocerto-e1dab`** do ERP — ver **`firebase_options`** em cada produto. Ciclo de vida e docs detalhadas do Studio: **`C:\StudioPontoCerto`** e os seus **`docs/OFICIAL_*`**.

## Camadas principais

### 1. Frontend

- Flutter
- operacao web-first para empresa, gestor e contador
- **`SessionBootstrap`** usa **`loadRiverpodSessionForAuthUser`** (`session_hydrate_from_auth.dart`) igual ao fluxo demo apos token (evitar duplicar logica).
- app Android para funcionario e acessos moveis; **versão Play** em `pubspec.yaml` (`version` = `versionName`+`versionCode`); último bump documentado nesta rodada: **1.0.88+1059** (anterior **1.0.87+1058**).
- abertura de **WhatsApp** (`wa.me`) em landings marketing no **Web**: clique síncrono com `<a>` invisível — **`AnchorElement`** + **`click()`** na mesma stack do **`onPressed`** (`vendas_whatsapp_web_anchor_web.dart` vs stub), com navegação **na mesma aba** (`target: _self`) para evitar bloqueio silencioso de nova aba/pop-up; **FBQ / `sales_whatsapp_comercial`** apenas após **`Timer`(400 ms)** (`scheduleWhatsappComercialSignals` em `vendas_whatsapp_button.dart`), fora da stack do gesto, para não disputar com o browser nem com corrida Pixel/DOM. Nativo: `launchUrl`. O widget **`Link`** do `url_launcher` foi **descontinuado aqui**: no canvas Flutter pode falhar a sincronização entre sinal **`followLink`** e evento DOM (`viewId` / **`preventDefault`**), pelo que **não** aparecia navegação.
- **`web/index.html`**: **`preconnect`/`dns-prefetch`** (`fonts.gstatic.com`, `www.gstatic.com`, `firebase.googleapis.com`, `connect.facebook.net`); Pixel base **defer** até **`window.load`** para nao disputar bootstrap Flutter.
- **Web navegacao**: `PageTransitionsTheme` nativa (**`FadeUpwardsPageTransitionsBuilder`**) substitui **fade+slide** custom apenas em **`kIsWeb`** (menus internos menos trabalho GPU).
- **Arranque `main.dart`**: `Firebase.initializeApp` e leitura leve **`lerNomeEmpresaCache`** iniciam **em paralelo** (antes em serie). **`usePathUrlStrategy()`** apenas quando **`kIsWeb`** (evita APIs de URL strategy no desktop).
- **Firebase desktop Windows**: `firebase_options.dart` define **`DefaultFirebaseOptions.windows`** (conjunto alinhado ao Web até haver app Windows dedicado no console Firebase / FlutterFire CLI).
- **Firestore**: apos init, persistência local **activa** onde o SDK a suporta de forma estável; em **Windows** (exe) **`persistenceEnabled: false`** em `firebase_init.dart` para reduzir bloqueios ou stalls no arranque.


- Firebase Functions
- integracoes operacionais e fiscais
- regras finas de autorizacao por papel e contexto

### Publico: demo, pre-cadastro e entrada leve (03/05/2026)

**URLs canonicas (03/05/2026 — campanhas):** lib/core/constants/public_campaign_routes.dart define **/pre-cadastro-empresa** e **/pre-cadastro-escritorio**; aliases /cadastro-empresa, /cadastro-escritorio-contabil e **/contratar** (empresa) redireccionam com query/UTM. Formularios leves exigem **UF**, **cidade** e **CEP**. Governanca (Convidar/Funil) deixou de listar métricas de "planos clicados"/	opPlans na UX comercial atual.


#### `publicOpenDemoAccess`

- Workspace fixo `public_demo_workspace`; UIDs fixos `public_demo_owner` / `public_demo_accountant` (ignora IDs legados em `demo_access_config`).
- Gravacao em `platform_public/demo_access` com docId `dv1_*` (hash de IP + UA + dimensoes + idioma + tipo de dispositivo); campos `clientVisitorId`, `dedupeVersion`.

#### Plataforma admin (governanca — 03/05/2026)

- Rotas: `/platform-admin/governanca` com visão **hub** por omissão; sub-paineis via **`?v=`** (`funil`, `precadastro_empresas`, `precadastro_escritorios`, `cadastro_completo`, `demo`, `links`, `email_massa`). **`/platform-admin/agente-engenharia`**: Agente de Engenharia (empresa suprema), integrado em **`PlatformAdminPage`** (`PlatformAdminSection.engineeringAgent`); widget **`EngineeringAgentPage`** em `lib/features/governance_engineering/...`; redirect **`governanca?v=engineering_agent`** → `/platform-admin/agente-engenharia`. Shell lateral: **`_PlatformAdminShellGroup`** lista **Agente Engenharia** antes de **Escritorios** quando suprema (`lib/core/navigation/app_shell.dart`).
- Callables plataforma (existentes): `platformListStandaloneLightweightCompanies` (acrescenta `standaloneDeletionAllowed`/`standaloneDeletionBlockedReason` segundo `evaluateStandaloneLightweightTestDeletionGate`; devolve também **`leadOriginEstado`**, **`leadOriginCidade`**, **`leadOriginCep`** quando existirem em `directSignup.leadOrigin`), `platformListPublicDemoAccessLedger` (devolve apenas contagens, perfis demo e datas de primeiro/ultimo acesso; **nao** expoe IP, hash, user-agent, visitorId ou dimensoes — dedupe continua no Firestore), `platformListGovernanceRealRegistrations` (**enriquecido** com resumo ciclo billing + subscription Asaas quando existente + flag freeze administrativo quando existente nos mesmos filtros empresa/escritorio), `platformListCompanies`, `platformListLightweightTestOffices`, `platformDeleteLightweightTestCompany`, `platformDeleteLightweightTestOffice`, **`platformGovernanceCompanyCancelAsaasBilling`**, **`platformGovernanceCompanyCancelPendingAsaasPayments`**, **`platformGovernanceCompanySetSuspended`** (boolean `suspend`).
- **Agente de Engenharia** (**assertSupremePlatformAccess**): `engineeringAgentListProjects`, `engineeringAgentCreateProject`, `engineeringAgentSelectProject`, `engineeringAgentListSessions` (payload `projectId`), `engineeringAgentGetSession`, `engineeringAgentSendMessage`, `engineeringAgentGenerateCommand` (runtime pesado `HEAVY_RUNTIME`), `engineeringAgentApprovePatch`, `engineeringAgentRegisterContinuity`, **`engineeringAgentWorkerEnqueueJob`**, **`engineeringAgentWorkerApproveJob`** (fila local via worker Node `pontocerto-ai-worker/`). OpenAI via `obterConfigAssistantRuntime`; prompts **Ponto Certo** vs **externo**; sem segredo no Flutter.
- Firestore (cliente **sem** read/write nas rules): `engineering_agent_sessions` + `messages`; `engineering_agent_projects`; `engineering_agent_project_contexts`; `engineering_agent_patches`; `engineering_agent_operator_prefs`; **`engineering_agent_worker_jobs`** (fila para worker local); `engineering_agent_tasks`; `engineering_agent_audit`; `engineering_agent_messages` (reservada). Indices `engineering_agent_sessions` (`ownerUid`+`updatedAt`), `engineering_agent_projects` (`ownerUid`+`lastUsedAt`), `engineering_agent_patches` (`sessionId`+`createdAt`), **`engineering_agent_worker_jobs`** (`ownerUid`+`status`+`createdAt`).
- Métricas marketing agregadas: `platformGetMarketingDashboard` inclui **`companyLightPreregistrationViews`** e **`companyLightPreregistrationSubmits`** (eventos `company_light_preregistration_view` / `company_light_preregistration_submit` via `publicTrackMarketingEvent`).
- Indice composto Firestore: `users` — `role` + `lightweightProfilePending` (`firestore.indexes.json`).

#### `platformUpdateDemoAccessConfig`

- Deixou de exigir que `company_settings` exista para IDs customizados ao gravar a configuracao administrativa.

#### `publicCreateSalesPreRegistration`

- Lead gravado antes dos envios; e-mails encapsulados em `try/catch` com `logger.warn` quando credenciais SMTP/SendGrid/`MAIL_FROM` faltam.
- Resposta opcional: `precadastroEmpresaEmailOk`, `conviteParceiroEmailOk`.

#### Entrada leve

- `publicCreateCompanyWorkspaceAccess` e `publicCreateAccountantWorkspaceAccess` aceitam senha vazia no payload; o servidor gera senha interna e usa `generatePasswordResetLink` no fluxo de boas-vindas quando o correio envia.
- `publicCreateCompanyWorkspaceAccess` aceita opcionalmente **`leadOrigin`** (`estado`/`uf`, `cidade`, `cep`); persiste em `company_settings.directSignup.leadOrigin` (merge com `directSignup` existente).
- `provisionLightweightOfficeAccess` sanitiza payloads Firestore (`omitUndefinedForFirestore`) em paralelo ao fluxo da empresa e regista falha de e-mail nos logs (`missingInviteConfig` + mensagem).

#### IAM / Auth Admin (`signBlob`)

- `createCustomToken` (demo: `publicOpenDemoAccess`) e `generatePasswordResetLink` falham quando a conta das Cloud Functions nao pode assinar em nome da conta **firebase-adminsdk**. Em `pontocerto-e1dab`, o runtime padrao (Compute default `{num}-compute@developer.gserviceaccount.com` e App Engine default `{project-id}@appspot.gserviceaccount.com`) deve ter **`roles/iam.serviceAccountTokenCreator`** (e habitualmente **`roles/iam.serviceAccountUser`**) concedidos sobre `firebase-adminsdk-fbsvc@pontocerto-e1dab.iam.gserviceaccount.com`. Mensagem utilizador: `HttpsError` `failed-precondition`.
- **`publicOpenDemoAccess`** usa **`runWith({ serviceAccount: firebase-adminsdk-fbsvc@pontocerto-e1dab.iam.gserviceaccount.com })`** (sem `secrets` Firebase): o runtime e a conta **Firebase Admin SDK** ja com papel **`roles/firebaseauth.admin`**, o que robustece `createCustomToken` face a falhas **`signBlob`** da cadeia `appspot` → `firebase-adminsdk`. `resolveAuthForCustomTokens()` continua compativel com `ADMIN_SDK_AUTH_CERT_JSON` no ambiente apenas se definido manualmente no runtime (excepcional).
- Deteccao de falha IAM percorre tambem texto aninhado do erro SDK (`collectErrorTextDeep`).
- Web: `PublicDemoAccessPage` deixa de manter spinner apos erro; oferece links para a documentacao de custom tokens e para a lista de contas IAM do projeto (via `firebase_options`).

## 3. Dados

- Cloud Firestore
- colecoes multiempresa organizadas por `companyId`
- regras de acesso por perfil em `firestore.rules`

## 4. Integracoes externas

- Focus NFe / NFSe Nacional
- Firebase Auth
- Firebase Hosting
- Google Play para distribuicao do app
- OpenAI no assistente, quando configurado
- o assistente **nao** ingere o texto completo dos ficheiros `docs/OFICIAL_*.md` em cada pedido; **`buildAssistantInstructions`** inclui **referencia explicita** aos quatro caminhos dos `OFICIAL_01`…`04` no repositorio e combina **inventarios e guias fixos** (`buildAssistantFeatureInventory`, rota, FAQ) com **dados reais** no Firestore na chamada (ver `OFICIAL_02`). Manter codigo e Markdown alinhados quando o produto mudar.

Versao local atual de referencia:

- `1.0.88+1059` (`pubspec.yaml`; builds podem sobrescrever com `--build-name` / `--build-number`)

## Estrutura tecnica de acesso

### Sessao e papeis

Base principal:

- `lib/core/auth/session.dart`
- `lib/core/router/app_router.dart`
- `firestore.rules`

Esses 3 pontos precisam permanecer coerentes.

## Navegacao

Arquitetura de navegacao:

- GoRouter
- `navigatorKey: appRootNavigatorKey` — `GlobalKey<NavigatorState>` partilhada (Overlay de avisos e ordem de pintura)
- `ShellRoute` a envolver as rotas do **painel** autenticado: `AppRouteShell` (Consumer) aplica `AppShellScaffold` com `body: child` (outlet); o menu lateral e o mesmo eixo por sessao de shell, nao recriado por cada `GoRoute` filha
- `shellPageChromeProvider` (Riverpod) define `ShellPageChrome` (titulo opcional, header, accoes) por pagina; titulo por omissao: `AppShellScaffold.titleForPath(matchedLocation)`
- **Mensagens globais** (`app_user_message.dart`): `ValueNotifier` + entrada unica de `Overlay` inserida no `Navigator` raiz, com “bump” para o fim do stack de Overlays ao mostrar
- no web, `MaterialApp.router` aplica `SelectionArea` sobre o filho das rotas; o `builder` empilha um `Stack` com **`StackFit.expand`** (conteudo + `GlobalWhatsappSupportFab`); os **avisos globais** continuam no `Overlay` do `navigatorKey`
- rotas filtradas por papel

### Login, sessao e redirecionamento

O fluxo de login usa Firebase Auth + Firestore + Riverpod:

- as telas de login chamam `signInWithEmailAndPassword`
- `syncClaimsForCurrentUser` tenta sincronizar claims sem bloquear o login quando a callable ainda nao estiver disponivel
- `sessionProvider` recebe a sessao antes da navegacao final
- apos definir a sessao, o `GoRouter` deve ser atualizado para reler o estado antes do `go(...)`
- o `redirect` nao deve mandar usuario autenticado de volta para `/inicio` por erro transitorio durante sincronizacao Firebase/sessao

Essa regra vale para empresa, contador, funcionario e rota legada `/login`.

### Governanca de plataforma

`platformListSalesPipeline` agrega tambem alertas de governanca para o painel:

- `billing_webhook_events` com `status == unmatched`
- `accounting_offices` com `officeBillingStatus` pendente, vencido ou falho
- `company_settings.accountantOnboardingPending.status == pending_accountant_link`
- `sales_onboarding` com `implementationChargeAutomationError`

O retorno e lido em `PlatformSalesPipelineSnapshot.governanceIssues` e exibido no `Pipeline comercial`.
O vinculo empresa-escritorio continua nas maos do contador, via fluxo de cadastro/vinculo dele; a plataforma apenas evidencia pendencias.

### Ficheiros centrais desta arquitectura (referencia rapida)

| Ficheiro | Papel |
|----------|--------|
| `lib/core/navigation/app_root_navigator_key.dart` | `appRootNavigatorKey` para `Overlay` de avisos |
| `lib/core/navigation/app_route_shell.dart` | `AppRouteShell` — `AppShellScaffold` + `body: child` |
| `lib/core/navigation/shell_page_chrome.dart` | `ShellPageChrome`, `shellPageChromeProvider` |
| `lib/core/navigation/app_shell.dart` | `AppShellScaffold`, `_ShellMenu`, `titleForPath`, `AppWorkspaceHeader`, etc. |
| `lib/core/navigation/shell_menu_scroll.dart` | `appShellMenuLastScrollOffset`, `appShellMenuCaptureOffsetFrom` — offset do menu entre rotas (com `ScrollController` por instancia do menu) |
| `lib/core/router/app_router.dart` | `GoRouter(navigatorKey: appRootNavigatorKey)`, `ShellRoute` com rotas do painel |
| `lib/core/ui/app_user_message.dart` | `appUserMessageNotifier`, insercao no `Overlay`, extensoes `showUserMessage` |
| `lib/app/app.dart` | `MaterialApp.router`; `builder` com `Stack` (**`StackFit.expand`**) + conteudo + FAB WhatsApp global |
| `lib/core/widgets/global_whatsapp_support_fab.dart` | Botao fixo inferior-direito: `wa.me` suporte (`abrirWhatsappVendas`) em todas as rotas |
| `lib/core/constants/whatsapp_support.dart` | `kWhatsappSupportNumberE164` (DDI 55) — numero unico de suporte/leads WhatsApp |
| `lib/core/utils/callable_response_map.dart` | `mapFromCallableData` — parse seguro do retorno de Callables (web/interop) |
| `functions/src/index.ts` | Assistente: `buildAssistantInstructions`, OpenAI, Firestore auxiliar |

As paginas do painel deixam de envolver `AppShellScaffold`: definem `shellPageChromeProvider` e devolvem so o `body` (lista alargada de ecras em `lib/features/**`).

Regra tecnica:

- rota liberada sem tela coerente e bug de produto
- tela pronta sem rota coerente e promessa quebrada
- regra de dados sem rota/tela coerente e bloqueio operacional

## Estrutura de dados multiempresa

Principio:

- a empresa opera dentro do proprio tenant
- plataforma suprema opera separada
- contador opera dentro das empresas vinculadas ao seu contexto

## Arquitetura fiscal

### Funcoes principais

- emissao
- cancelamento
- consulta
- conciliacao

Base:

- `functions/src/index.ts`

### Regras fiscais recentes consolidadas

- `NFSe Nacional` exige `pAliq` quando o caso real assim demandar
- `cTribMun` nao deve ser inferido automaticamente no fluxo nacional sem validacao municipal real
- em `Simples Nacional` sem retencao de ISS no caso nacional aplicavel, a alíquota pode existir na UI, mas nao deve ser enviada no payload real
- os erros do provedor devem virar mensagem acionavel de sistema

### Resumo fiscal e leitura consolidada

- os cards de resumo fiscal devem usar status derivado da nota, e nao apenas o campo bruto de status salvo
- notas canceladas precisam sair da soma financeira e dos indicadores operacionais em tempo real
- valor bruto e tomadores da competencia devem refletir apenas notas oficialmente emitidas e ativas
- observadores e agregadores de `service_invoices` nao podem classificar nota cancelada como emitida so porque existe `officialNumber`
- a exclusao em lote no fiscal deve reutilizar a mesma regra de elegibilidade da exclusao individual, evitando drift entre UI e operacao
- nota com `financeMovementId`, nota oficialmente emitida e nota ainda em processamento nao pode entrar na limpeza em lote

### Entrada comercial publica

- o backend comercial publico trata o escritorio contabil como contato principal do pre-cadastro
- no fluxo `accountant-first`, nome/email do escritorio alimentam o onboarding inicial e a empresa entra como dado operacional posterior
- o cadastro da empresa por convite aceita ausencia inicial de email da empresa, com fallback para o email do responsavel quando necessario
- os templates de email voltados a escritorio e contador devem compartilhar uma mesma assinatura institucional centralizada no backend, para evitar divergencia de narrativa entre convites, acessos e onboarding
- o cadastro do escritorio contabil passa a gravar metadados comerciais proprios de assinatura base e isencao por parceria
- a entrada publica comercial deve operar com trial real de 30 dias, sem cobranca de implantacao, exigindo indicacao de contador para conduzir o cadastro inicial da empresa
- landing `/vendas` (Flutter `SalesPage`): CTAs duplos empresa/escritorio; eventos Meta distintos `metaFbqTrackStartTrialEmpresa` vs `metaFbqTrackStartTrialEscritorio`
- `publicOpenDemoAccess` + `ensurePublicDemoAuthUser`: resiliente a remocao de utilizadores demo no Firebase Auth (recriacao ou reutilizacao por e-mail; tratamento de colisoes no `createUser`)
- `buildDefaultCommercialSettings`: objeto final passa por `omitUndefinedForFirestore` antes da persistencia nas rotas que o consomem, para nunca enviar `undefined` ao Firestore
- `findSalesLeadDocByCustomerEmailAndPlan` / `findSalesOnboardingDocByRecipientEmailAndPlan`: leitura por e-mail apenas e filtro de `planCode` em aplicacao onde antes havia dois `where` combinados (`sales_public_leads`, `sales_onboarding_requests`)

## Arquitetura oficial do modulo Documentos

- colecao principal: `document_requests`
- o provider de documentos consulta por `companyId == session.companyId` para owner, manager e contador
- o provider de funcionarios tambem consulta `users` por `companyId == session.companyId`; por isso os dialogos do contador usam apenas funcionarios da empresa atualmente selecionada
- cada documento da colecao precisa sustentar:
  - itens pedidos
  - anexos do proprio pedido, enviados por contador, empresa ou funcionario
  - destinatario original (`empresa` ou funcionarios especificos)
  - destinatario atual responsavel pelo envio
  - rastreio de encaminhamento interno pela empresa
- o app do funcionario precisa ler apenas solicitacoes em que o proprio funcionario esteja atribuido
- as regras de Firestore precisam permitir:
  - leitura ampla para owner, manager e contador no tenant correto
  - leitura restrita para funcionario somente quando ele estiver atribuido na solicitacao
  - update restrito do funcionario apenas para envio de anexos e atualizacao operacional do proprio pedido
- o Storage de `document_requests` precisa manter acesso compartilhado autenticado para contador, empresa e funcionario dentro do tenant
- uploads devem gravar em `companies/{companyId}/document_requests/{requestId}/...`, mantendo isolamento por empresa mesmo quando o contador alterna a carteira

## Arquitetura de documentos e continuidade

Fontes oficiais de continuidade:

- memoria viva
- estado atual
- alinhamento de modulos e permissoes
- continuidade atual

Este documento nao substitui o registro vivo.
Ele descreve a arquitetura.

## Principios de engenharia obrigatorios

1. nao prometer na UI o que a rota nao libera
2. nao prometer na venda o que o backend nao sustenta
3. nao liberar no backend o que a memoria do sistema nao entende
4. nao deixar erro tecnico relevante para depois
5. manter web, app, backend e documentacao coerentes

## Regra obrigatoria antes de implementar

Toda mudanca relevante deve obedecer esta ordem:

1. documentar visual no `OFICIAL_01`
2. documentar funcional no `OFICIAL_02`
3. documentar ou confirmar impacto arquitetural aqui no `OFICIAL_03`
4. implementar no frontend/backend
5. registrar o resultado no `OFICIAL_04` e na continuidade

## Publicacao

Frentes tecnicas de publicacao:

- `hosting`
- `firestore rules`
- `functions`
- `appbundle` quando houver impacto no app

## Evolucao fiscal futura (so documentada; nao implementada)

Certificadora (orquestracao AC + estados + ponte para `fiscalCertificate` / Focus) e preparacao **IBS/CBS** (campos opcionais, flags desligadas, sem alteracao de payload real ate decisao) estao descritas **somente** em [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md). Qualquer implementacao deve obedecer a ordem `OFICIAL_01` → `02` → `03` → codigo → `OFICIAL_04` e continuidade.

## Camada de copy do integrador fiscal (05/05/2026)

- `lib/core/fiscal/fiscal_integration_ui_copy.dart`: mensagens de integracao NFS-e/NF-e nas rotas empresa, fiscal, contador e declaracoes — **sem nome comercial do fornecedor tecnico** para quem nao e dono na empresa suprema (`hasSupremePlatformAccess` / `showFiscalVendorName`).
- `lib/features/company/presentation/pages/company_page.dart`: cadastro da empresa no painel com **Buscar CNPJ** (`lookupBrazilCnpjForSignup`) gravando em `users.companyData`.
- `functions/src/index.ts` (`buildAssistantInstructions`, `buildAssistantFeatureInventory`, guia `/fiscal`): referencias explicitas aos quatro `docs/OFICIAL_*.md` e linguagem **integrador fiscal** em lugar de marca de terceiro no inventario textual do modelo.

## Referencias tecnicas centrais

- [firestore.rules](/C:/Users/hp/pontocerto/firestore.rules)
- [app_router.dart](/C:/Users/hp/pontocerto/lib/core/router/app_router.dart)
- [session.dart](/C:/Users/hp/pontocerto/lib/core/auth/session.dart)
- [fiscal_integration_ui_copy.dart](/C:/Users/hp/pontocerto/lib/core/fiscal/fiscal_integration_ui_copy.dart)
- [index.ts](/C:/Users/hp/pontocerto/functions/src/index.ts)
- [FISCAL_READINESS.md](/C:/Users/hp/pontocerto/docs/FISCAL_READINESS.md)
- [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)
