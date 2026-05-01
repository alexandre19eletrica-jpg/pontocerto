# Arquitetura Tecnica Completa do Sistema

Data base: 23/04/2026
Projeto: Ponto Certo

## Objetivo

Este documento consolida a arquitetura tecnica oficial do sistema para desenvolvimento, auditoria e continuidade.

## Camadas principais

### 1. Frontend

- Flutter
- operacao web-first para empresa, gestor e contador
- app Android para funcionario e acessos moveis
- abertura de **WhatsApp** (`wa.me`) em landings marketing: no **Web** usa implementacao especifica com **import condicional** (`dart.library.html`) e `window.open` na mesma virada do clique (`vendas_whatsapp_web_open_web.dart` vs stub); fora do Web continua `url_launcher` com `LaunchMode.externalApplication` — **nao** anteceder a abertura Web com `await canLaunchUrl` no fluxo deste botao (bloqueava pop-ups)

## 2. Backend

- Firebase Functions
- integracoes operacionais e fiscais
- regras finas de autorizacao por papel e contexto

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
- o assistente **nao** le os ficheiros `docs/OFICIAL_*.md` em cada pedido: o sistema e construido em `buildAssistantInstructions` + dados Firestore (ver `OFICIAL_02`); actualizar o produto exige alinhar codigo e documentacao

Versao local atual de referencia:

- `1.0.78+1048`

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
- no web, `MaterialApp.router` aplica `SelectionArea` ao filho; os avisos nao passam a depender de `Stack` no `builder` do `MaterialApp` para ficarem acima
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
| `lib/app/app.dart` | `MaterialApp.router` sem `Stack` de aviso no `builder` (web: `SelectionArea` apenas no conteudo) |
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

## Referencias tecnicas centrais

- [firestore.rules](/C:/Users/hp/pontocerto/firestore.rules)
- [app_router.dart](/C:/Users/hp/pontocerto/lib/core/router/app_router.dart)
- [session.dart](/C:/Users/hp/pontocerto/lib/core/auth/session.dart)
- [index.ts](/C:/Users/hp/pontocerto/functions/src/index.ts)
- [FISCAL_READINESS.md](/C:/Users/hp/pontocerto/docs/FISCAL_READINESS.md)
- [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)
