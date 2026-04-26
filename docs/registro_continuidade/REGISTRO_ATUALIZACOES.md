# Registro de atualizacoes (nao se perder)

Fonte de backup e rastreio: **Git** (este ficheiro e `docs/` no repositório).  
Regra de projeto: `.cursor/rules/documentacao-git-e-registro.mdc`.

Este arquivo e o log operacional resumido do que foi publicado (web/functions/app).  
Atualize sempre que entrar qualquer mudanca em producao.

## 2026-04-26

- **Play Store (Android)**: publicada **`1.0.82+1053`** (versionName `1.0.82`, versionCode `1053`); ficheiro de arquivo canónico: `pontocerto-1.0.82-1053.aab` (regra: `pontocerto-<versionName>-<versionCode>.aab`).
- **Play Store / processo / repo**: regra e script em `docs/PLAY_STORE_AAB_NAMING.md`, `docs/PLAY_STORE_RELEASE_NOTES.md`, `docs/registro_continuidade/CHECKLIST_RELEASE_ROLLBACK.md`, `scripts/build_android_release.ps1` (`-CopyToDesktop`); regra Cursor `.cursor/rules/aab-play-store-nome.mdc`. O `pubspec` deve sempre crescer face à última publicada.
- **Cloud Functions** (`functions/src/index.ts`, `functions/lib/*`): `buildRecommendedFiscalSetup` passa a expor `usesPlatformFocusToken`; **não** se persiste o token global da plataforma no documento de integração da empresa; emissão real continua permitida com token da empresa **ou** uso do token de plataforma nos callables, conforme a configuração.
- **Fiscal (Web)**: refatoração da página de prontidão e acções de integração real (menos duplicação, diálogos alinhados); leitores de prontidão e secções ajustados (`fiscal_readiness_page.dart`, `fiscal_readiness_integration_actions.dart`, `fiscal_readiness_sections.dart`, `focus_official_issue_readiness.dart`).
- **Plataforma / contador**: `platform_admin_page.dart` (fluxo de token alinhado à política de não expor token global de produção nesse ecrã); `accountant_companies_page.dart` (indicação quando a empresa usa token da plataforma).
- **Marketing (Web)**: `/vendas` e páginas públicas (tipografia, copy, prereg) — `sales_page.dart`, `sales_preregistration_page.dart`, `accounting_office_signup_page.dart`, `public_sales_config_service.dart`.
- **Meta Pixel (Web)**: carregamento condicional a partir de config pública e eventos (ficheiros `public_meta_pixel_bootstrap*.dart`, `meta_fbq_events*.dart`); `main.dart` agenda bootstrap em web com Firebase OK.
- **Observabilidade + Firestore**: `runtime_incident_reporter.dart` afinado; `firestore.rules` — leitura de `runtime_incidents` corrigida para `transaction.get()` em documento ainda inexistente (permitir `get` em doc novo antes de `sameCompany`, conforme comentário na regra).
- **Regra de documentação** (commit + push no mesmo fecho): `.cursor/rules/documentacao-git-e-registro.mdc`.
- **Util**: `lib/core/utils/replace_trailing_paste_text_input_formatter.dart`.
- **Código** sincronizado com **Git** (`origin/master`) no encerramento desta rodada.

## 2026-04-16

- **Fiscal (Web)**: UI passou a **exigir automaticamente CNO** quando o codigo de servico exigir “grupo de obra” na Focus/NFSe Nacional (ex.: `07.02.02` -> `070202`).
  - **Comportamento**: checklist mostra pendencia do CNO, “Salvar e emitir” bloqueia sem CNO, e “Dados da obra” aparece apenas quando necessario (ou quando ja houver dado preenchido).
  - **Arquivos**: `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`
- **Fiscal (Web)**: servicos fiscais salvos agora tem **validacao/normalizacao** para NFSe Nacional:
  - **Regra**: no modo Focus `national`, o `Codigo do servico` deve conter o **subitem completo** (min. 6 digitos, ex.: `07.02.02` -> `070202`).
  - **UX**: botao **Normalizar** nos “Servicos fiscais” para corrigir cadastros antigos (limpa caracteres, marca `[REVISAR CODIGO]` e desativa quando invalido).
  - **Auto-fix (alta confianca)**: quando encontrar codigos incompletos (ex.: `702`/`705`) + `CNAE 4321500` + palavras-chave no nome:
    - `instal*` -> `07.02.02`
    - `manut*` -> `14.01.01`
    - se nao houver confianca, apenas marca `[REVISAR CODIGO]` e desativa.
  - **Arquivos**: `lib/features/fiscal/presentation/pages/fiscal_readiness_operational_actions.dart`, `lib/features/fiscal/presentation/pages/fiscal_readiness_dashboard_sections.dart`
- **Functions**: correcao de build (TypeScript) no `buildFocusNationalInvoicePayload` para declarar `workSite` antes do uso.
  - **Arquivo**: `functions/src/index.ts`
- **Functions**: melhora na derivacao do **codigo de tributacao nacional do ISS**:
  - **Regra**: aceita o subitem diretamente de `service.serviceCode`/`service.municipalServiceCode` (ex.: `07.02.02` ou `7.02.02` -> `070202`), alem do fallback por CNAE+descricao.
  - **Arquivo**: `functions/src/index.ts`
- **Fiscal (Web) + Functions**: adicionado diagnostico e correcao via tela (sem depender de comando CLI):
  - **Callable**: `fiscalDiagnoseServiceCatalog` (dry-run e applyFix)
  - **UI**: botoes **Diagnostico** e **Corrigir agora** em “Servicos fiscais”
  - **Arquivos**: `functions/src/index.ts`, `lib/features/fiscal/presentation/pages/fiscal_readiness_dashboard_sections.dart`
- **Versao app**: bump de `pubspec.yaml` para `1.0.73+1043` (Play Store: versionName/versionCode).

## 2026-04-17

- **Fiscal (NFSe Nacional / Focus)**: emissao real estabilizada com correcoes de payload/validacoes (evitar rejeicoes por schema).
  - **Correcoes**:
    - exige `cno_obra` quando codigo nacional exige grupo de obra (E0370)
    - valida municipio IBGE (7 digitos) para emitente/tomador/prestacao (evita `cMun` vazio)
    - exige **numero** do tomador quando endereco existe (evita erro `xBairro` antes de `nro`)
    - endereco da obra: so envia quando completo o suficiente (ou bloqueia com mensagem clara)
  - **Arquivo**: `functions/src/index.ts`
- **Fiscal (Web)**: melhorias operacionais para nao perder notas e acelerar preenchimento:
  - loading + resubscribe do stream de notas (evita “sumir e voltar”)
  - botao **Excluir (com erro)** para rascunhos sem numero oficial
  - dropdown de servico fiscal nao trava quando item ficou inativo (mostra “(inativo)”)
  - “servicos fixos” nao ressuscitam codigos antigos; so aparecem quando nao existe catalogo salvo
  - CNO: salva rapido + obras recentes + buscar CEP (preenche endereco e salva rascunho)
  - **Arquivos**: `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`, `lib/features/fiscal/presentation/pages/fiscal_readiness_invoice_sections.dart`, `lib/features/fiscal/presentation/pages/fiscal_readiness_support.dart`, `lib/features/fiscal/presentation/widgets/invoice_dialog_sections.dart`
- **Versao app**: bump de `pubspec.yaml` para `1.0.74+1044` (proxima publicacao na Play Store).

- **Plataforma + Cadastro**: modulo de **convite de teste gratuito por 30 dias** (empresa + contador) + fluxo do contador parceiro.
  - **Plataforma (UI)**: novo card em `Plataforma` para informar emails e disparar convite (copia link do cadastro).
  - **Functions**:
    - `platformIssueTrial90DayInvite` (nome historico): gera token (valido 30 dias), grava em `trial_invites` e envia emails para empresa e contador.
    - `publicRegisterCompanyDirectSignup`: aceita `trialInviteToken` e libera a empresa com `lifecycleStatus=trial`, `billingStatus=trialing`, `graceUntil=+30d`, sem exigir pagamento.
    - `platformTrial90DayFollowup` (agendado diario; nome historico): ao expirar `graceUntil`, envia email de follow-up e bloqueia login automaticamente.
    - `accountantRegisterCompanyTrial30d`: contador logado cadastra empresa e marca como trial 30 dias; owner recebe email para definir senha; contador ja fica vinculado.
  - **Rotas**:
    - `/cadastro-empresa?trialToken=...` (empresa)
    - `/cadastro-empresa-contador?trialToken=...` (contador faz o cadastro completo)
    - `/accountant-register-company` (contador logado cadastrar novas empresas)
  - **Arquivos**: `functions/src/index.ts`, `lib/features/platform_admin/presentation/pages/platform_admin_page.dart`, `lib/features/platform_admin/presentation/services/platform_admin_service.dart`, `lib/features/auth/presentation/pages/cadastro_empresa_page.dart`, `lib/core/router/app_router.dart`, `lib/features/auth/presentation/pages/login_contador_page.dart`

## 2026-04-18

- **Governanca (Plataforma)**: cards de trial/convites reorganizados em formato de “pastas” (abre/fecha) para reduzir poluicao na tela de governanca.
  - Convites enviados agora suportam: exclusao individual, selecao multipla e secao “Excluidos”.
  - **Arquivos**: `lib/features/platform_admin/presentation/pages/platform_admin_page.dart`
- **Functions (trials)**:
  - `platformDeleteTrialInvites`: soft delete em `trial_invites` (status `deleted` + `deletedAt/deletedBy*` + auditoria).
  - `platformListTrialInvites`: retorna `deletedAtIso` e `deletedByName`.
  - **Arquivo**: `functions/src/index.ts`
- **Email (sem noreply do Firebase Auth)**:
  - `publicRequestPasswordResetEmail`: envia email de redefinicao com remetente oficial via SMTP Titan.
  - Telas de login passaram a chamar essa Function no “Esqueci minha senha”.
  - **Arquivos**: `functions/src/index.ts`, `lib/features/auth/presentation/pages/login_*_page.dart`
- **Contador (acesso liberado)**:
  - Removidos redirecionos globais que bloqueavam o contador por falta de perfil fiscal ou readiness fiscal.
  - **Arquivos**: `lib/core/router/app_router.dart`, `lib/features/auth/presentation/pages/login_contador_page.dart`
- **Fiscal (servicos salvos)**:
  - Fluxo ajustado: empresa cadastra servico fiscal **inativo** e contador valida/ativa.
  - `firestore.rules` atualizadas para esse controle e UI ajustada no dialogo.
  - **Arquivos**: `firestore.rules`, `lib/features/fiscal/presentation/pages/fiscal_readiness_operational_actions.dart`

## 2026-04-20

- **Convites trial (Plataforma + Functions)**: fluxo ajustado para deixar **apenas o email do contador como obrigatorio**.
  - `platformIssueTrial90DayInvite` passou a aceitar `companyEmail` opcional.
  - O disparo principal do convite passou a ser feito para o contador, com `inviteUrl` principal retornando o link do contador.
  - O card manual na `Plataforma` foi alinhado para deixar o email da empresa como opcional.
  - O envio em massa tambem foi alinhado para aceitar linhas com apenas `contador@dominio.com;Nome Contador`.
  - **Arquivos**: `functions/src/index.ts`, `lib/features/platform_admin/presentation/pages/platform_admin_page.dart`, `lib/features/platform_admin/presentation/services/platform_admin_service.dart`, `lib/core/utils/trial_invite_bulk_parser.dart`

- **Email comercial do contador**: copy reescrita para abordagem mais **institucional, formal e segura para envio em massa**.
  - Removida a ideia de indicacao direta.
  - O texto agora assume contato institucional/frio, apresenta a plataforma, explica o trial e fecha com saida elegante para nao soar invasivo/spam.
  - **Arquivo**: `functions/src/index.ts`

- **Landing comercial / parceria com contador**: precificacao alinhada na frente publica e na pagina interna do contador parceiro.
  - Regra comercial consolidada:
    - uso do contador: **gratuito**
    - empresa cadastrada: **R$ 97,90/mes**
    - acesso adicional no app Play Store: **R$ 19,90/mes**
  - A landing `vendas` foi ajustada para refletir essa regra nos blocos comerciais.
  - A pagina `Seja nosso parceiro` do contador tambem foi ajustada para mostrar a mesma regra comercial, sem faixas antigas por pacote.
  - A origem do config publico foi endurecida no backend para devolver essa regra como base operacional.
  - **Arquivos**: `functions/src/index.ts`, `lib/features/marketing/presentation/pages/sales_page.dart`, `lib/features/accountant_links/presentation/pages/accountant_partner_page.dart`, `lib/features/marketing/presentation/services/public_sales_config_service.dart`

- **Validacao e publicacao**:
  - `dart analyze` passou limpo na frente de convites/plataforma.
  - `npm run build` das Functions passou limpo.
  - `flutter build web --release` concluiu com sucesso.
  - `firebase deploy --only "functions,hosting" --project pontocerto-e1dab` concluiu com sucesso.
  - **Hosting publicado**: `https://pontocerto-e1dab.web.app`

## 2026-04-23

- **Contexto operacional**: **Antes de 23/04** tudo estava **ok** operacionalmente. A **data da burrada** (alteracao nao intencional: codigo, deploy ou ambiente) e **so** **23/04/2026**. Em **21/04/2026** houve emissao **normal** em producao e sistema **redondo**; **evidencia** (resumo, sem anexar XML/cert no repo): `cStat=100`, `cTribNac`/nacional **070501**, DPS `nDPS=10`, nota `nNFSe=36`, competencia e emissao em 21/04/2026. Os itens tecnicos abaixo sao correcao no repositorio; **redeploy** ainda a confirmar.
- **Fiscal (NFSe Nacional / Focus) — emissao normalizada (app + functions)**:
  - **Regra unica para o item LC 116**: 4/5/6+ digitos resolvem para 6 digitos nacionais; exibicao `XX.XX.XX`; 1–3 digitos sozinhos nao sao completados de forma fidedigna (mesma filosofia do app).
  - **Backend**: antes de montar o payload nacional, `buildFocusNationalInvoicePayload` chama `alignNationalServiceCodesOnInvoiceService` em `data.service`, alinhando `serviceCode` e `municipalServiceCode` quando der para resolver a partir de qualquer um dos campos ou de codigo nacional salvo (campos `codigoTributacaoNacionalIss` / `nationalTaxCode` / etc. com >= 6 digitos). Helpers: `tryParseNationalLc116SixDigits`, `formatNationalLc116Dotted`.
  - **Arquivo**: `functions/src/index.ts`
- **Fiscal (Web)** — estabilidade Firestore e UX alinhada ao nacional:
  - listas e dashboard fiscal na web: `get` + chave de epoca (`_webFiscalListEpoch`) e invalidacao apos gravação, em vez de `StreamBuilder` competindo com writes (mitiga `INTERNAL ASSERTION` b815)
  - catalogo `fiscal_service_catalog` na web: sem listener continuo; refresh apos save/delete
  - **Arquivos**: `fiscal_readiness_page.dart`, `fiscal_readiness_invoice_sections.dart`, `fiscal_readiness_dashboard_sections.dart`, `fiscal_readiness_operational_actions.dart`, `fiscal_service_catalog_provider.dart`, `national_service_code_format.dart`
- **Validacao local**: `npm run build` em `functions` apos a alteracao do payload nacional.

