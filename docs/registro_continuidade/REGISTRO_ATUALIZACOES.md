# Registro de atualizacoes (nao se perder)

Fonte de backup e rastreio: **Git** (este ficheiro e `docs/` no repositório).  
Regra de projeto: `.cursor/rules/documentacao-git-e-registro.mdc`.

Este arquivo e o log operacional resumido do que foi publicado (web/functions/app).  
Atualize sempre que entrar qualquer mudanca em producao.

## 2026-04-29

- **Trabalhista / contador / empresa ativa**: o contador passou a operar `Tarefas` e `Ordens de servico` da **empresa ativa da carteira** em modo **somente leitura** e focado em itens **finalizados**, para apoiar a conferencia antes da emissao fiscal sem abrir gestao operacional indevida. Rotas liberadas em `session.dart`; telas ajustadas em `tasks_page.dart`, `task_details_page.dart`, `task_details_sections.dart` e `service_orders_page.dart`.
- **Trabalhista (base real por competencia, sem redundancia de cadastro)**: o modulo ganhou painel por **empresa ativa** e **competencia** com indicadores de `13o`, ferias, admissoes a revisar e cadastro incompleto; o colaborador selecionado passou a exibir leitura formal do vinculo (avos de `13o`, periodo aquisitivo de ferias, projecao de dias e sinal de rescisao) derivada do cadastro existente, sem criar nova fonte de verdade para funcionario.
- **Trabalhista / dossie e eventos**: o cadastro trabalhista passou a mostrar **dossie do colaborador** com faltas de dados/documentos obrigatorios (`RG/CPF`, `CTPS`, residencia, bancario) a partir do que ja existe em `users` + `employee_registration_documents`. Tambem foi criada a trilha `workforce_employee_events` para registrar, por colaborador e competencia, eventos como revisao de admissao, aviso/inicio de ferias, `13o` e rescisao, sem duplicar o cadastro-base.
- **Trabalhista / checklist e snapshot da competencia**: foi criada a colecao `workforce_competence_obligations` para checklist por empresa/competencia (admissao, folha, ferias, `13o`, rescisao, FGTS, eSocial) e a colecao `workforce_employee_competence_snapshots` para **snapshot trabalhista** por colaborador/competencia, com memoria de calculo de `13o`, ferias e rescisao dentro do proprio snapshot. O snapshot e derivado de `users`, `payments`, eventos e competencia ativa; nao substitui cadastro, folha nem documentos.
- **Trabalhista / fechamento operacional da competencia**: o fechamento mensal passou a comportar tambem um **fechamento trabalhista consolidado** dentro do proprio `payroll_closures`, sem abrir nova colecao. A competencia agora pode salvar `laborClosure` (status `pending_review` / `ready_for_close` / `closed`) e `laborLines` por colaborador, consolidando snapshots salvos, eventos, checklist, projecoes de `13o`, ferias + `1/3` e rescisao. O PDF do fechamento mensal passou a incluir essa parte trabalhista quando existir.
- **Marketing / Meta Pixel (Web)**: clique no **WhatsApp comercial** dispara rastreio `Contact` (fbq) e `SalesAnalyticsService` / `publicTrackMarketingEvent` com `sales_whatsapp_comercial`; `marketingEventScore` inclui o evento. Arquivos: `vendas_whatsapp_button.dart`, `meta_fbq_events*.dart`, integracao em `sales_page`, `vendas_contador_page`, `inicio_page`, `login_contador_page`.
- **Carteira contador**: `accountant_company_links_provider` passa a considerar **todos** os estados de vinculo (nao so ativos), com **ativos primeiro**; `accountant_companies_page` ganha chips, resumo no cabecalho e indicacao de vinculo ativo/inativo no tile.
- **Cloud Functions**: `enviarNotificacaoInternaNovoCadastro` envia notificacao interna para **`fromEmail`** quando valido, senao fallback `acesso@tudo-certo.com` (`functions/src/index.ts`).
- **Sessao / Trabalhista (contador)**: `session.dart` libera rotas `/workforce` e `/employees` para contador; `workforce_management_page` bloqueia apenas **funcionario** (nao contador); UI **inativar** funcionarios em `employees_page` e `employee_review_page`.
- **Firestore rules**: contador com vinculo pode atualizar em `users` apenas **`ativo`** e **`updatedAt`** (governanca; sem ampliar campos arbitrarios).
- **Empresa suprema**: protecao contra inativacao/remocao indevida — alinhamento `comp_1771754418259` em `platform_access.dart`; `firestore.rules` (`isSupremePlatformCompanyId`, `supremePlatformUserMustRemainActive`, sem delete de users supreme onde aplicavel); `employees_provider` e callables `companyCancelBillingSubscription` / `setEmployeeActiveStatus` rejeitam desativar suprema; `employees_page` reflete chip e oculta accoes de inativar onde nao se aplica.
- **Deploy (esta rodada)**: `flutter build web --release`; `firebase deploy` (hosting + rules; **functions** com possivel **retry** apos timeout de analise do CLI). **Nenhum AAB foi gerado** nesta rodada (`flutter build appbundle` **nao** executado; Play **sem** novo artefacto desta sessao).
- **Documentacao / planeamento (sem implementacao de produto para certificadora ou IBS/CBS)**: criado [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](../PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md) — **so registo** para execucao futura em fases; **nao** altera emissao Focus nem payload ate decisao oficial.
- **Correccao (Web) — WhatsApp landings (`motivo real`)**: o **`Link`** do `url_launcher` no Web depende de dois sinais (DOM + **`followLink`**) alinhados ao **mesmo platform view**; com botão **Material no canvas** isso falha **silenciosamente** (**`preventDefault`**). **Meta Pixel** antes do fim do ciclo de navegação agravava. Solução final: **`AnchorElement.click()`** síncrono no clique, com abertura **na mesma aba** (`target: _self`) para evitar bloqueio silencioso de nova aba, + **`Timer` 400 ms** para FBQ/`publicTrackMarketingEvent` (`vendas_whatsapp_web_anchor_web.dart`, `vendas_whatsapp_button.dart`). `VendasLandingHero`/`Footer` sem parâmetros especiais de Link. OFICIAL 01–04 e continuidade actualizados nesta rodada.
- **Pendencias proxima edicao**: gerar **AAB** (`flutter build appbundle --release`) com `pubspec` acima da ultima Play publicada **se** for necessario subir app ou funcionalidade dependente de build Android; se `firebase deploy --only functions` falhar por timeout ao carregar codigo, repetir ou deploy fraccionado; qualquer subida que exija validacao extra no Play fica **apos** o AAB.

## 2026-04-28

- **UX / Fiscal (pendencia 27/04)**: mensagens do **Token API Focus** alinhadas para **todas** as empresas: texto fala em **plataforma / infra (Functions)** em vez de sugerir exclusividade da «empresa suprema» para a credencial. Arquivos: `fiscal_readiness_page.dart` (`_tokenApiStatusLine`), `fiscal_readiness_integration_actions.dart`, `platform_admin_page.dart`, comentario em `focus_official_issue_readiness.dart`.
- **Assistente**: subtitulo na `assistant_page` indica que a **credencial do modelo** fica no **backend da plataforma** (sem chave na UI).
- **Web (mobile)**: `app_shell` — nome do utilizador retirado do `AppBar` em modo gaveta; titulo com ellipsis. **Fiscal**: notas em tres cartoes (rascunho, aprovadas, canceladas), conteudo em **menu expansivel** (`ExpansionTile`, fechado por defeito); linhas de nota em layout de coluna (evita nome do cliente «vertical»). Cartao **Recebimento na NFS-e** (`fiscalPaymentBankInfo` no cadastro e no texto da discriminacao). Auditoria Focus: `docs/registro_continuidade/AUDITORIA_FOCUS_PROVISIONAMENTO_2026-04.md`.
- **Publicacao**: script `scripts/publish_all.ps1` (web release, `npm run build` em `functions`, `firebase deploy`; opcional `-Android`; define `NODE_OPTIONS=--dns-result-order=ipv4first` antes do deploy quando ainda nao esta na variavel, para evitar timeout do CLI ao analisar Functions). Alvo Play: **`1.0.84+1055`** (`pontocerto-1.0.84-1055.aab`).
- **Deploy (Firebase)**: em **28/04/2026**, `firebase deploy` para `pontocerto-e1dab` concluido (apos retry com `NODE_OPTIONS=--dns-result-order=ipv4first`). Hosting atualizado: `https://pontocerto-e1dab.web.app`. Pacote de Functions inalterado face ao ja publicado (deploy skip nas funcoes).
- **Auditoria «sistema unico»**: **concluida em documento** — `docs/registro_continuidade/AUDITORIA_SISTEMA_UNICO_FINAL_2026-04.md` (um so codebase; suprema = governanca; motor fiscal/emissao partilhado; contador = mesmo sistema com `companyId` ativo via links). **Sem alteracao de fluxo validado** na suprema nesta rodada.
- **Assistente / chave unica na UI**: permanece **evolucao planeada** (backend ja usa `OPENAI_API_KEY` com fallback antes de `assistant_secure`).

## 2026-04-27

- **Observacao (UX) — tratada em 28/04**: mensagens do **Token API** Focus unificadas (plataforma / infra) para **todas** as empresas; ver entrada **2026-04-28**.
- **Proxima etapa (planeado)**: **auditoria** para deixar o **sistema um so**: a **base de funcionamento** e a **regra** devem partir do que **ja esta a funcionar e validado na empresa suprema**; as outras empresas **recebem o mesmo comportamento** (mesmas regras, mesma logica, mesma experiencia alinhada), variando so o **acesso** (papel, claims, permissoes, dados daquela empresa) — nao manter explicacoes ou fluxos divergentes por tenant sem necessidade. Cruzar tela a tela, assistente, fiscal e notificacoes. Amarra com a unificacao do **token** Focus e, abaixo, com o **Assistente** via suprema.
- **Proxima etapa (planeado)**: o **token / credencial do Assistente** (integracao de modelo ou API) deve ser **carregado da empresa suprema** (ou da mesma camada de configuracao de plataforma), no mesmo espirito do **token Focus** global — sem um segredo distinto por empresa cliente na UI; implementar e documentar na rodada em que o Assistente for ligado a essa chave unificada.

- **A conferir (revisitar em rotas fora de Fiscal)**: ainda pode aparecer pedido de **token API** nalgum fluxo legado; base tecnica: `focusFiscalSetupUsesPlatformToken`, `FOCUS_API_TOKEN` nas Functions, `fiscalRealIntegration` no Firestore.

- **Memoria do assistente / continuidade**: `CONTINUIDADE_ATUAL.md`, `MEMORIA_VIVA_SISTEMA.md`, `OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md` e `PROMPT_ASSISTENTE_PONTO_CERTO.md` alinhados a **27/04/2026**; **fonte de verdade** para o assistente = `docs/` (complementar a `OFICIAL_01`…`04`). **Git**: produto fiscal `9ebfc14`; doc/memoria `b1e5847`.
- **Play / app**: alvo de publicacao **`1.0.83+1054`** (`pontocerto-1.0.83-1054.aab`); ajuste fiscal: token Focus por plataforma (`focusFiscalSetupUsesPlatformToken`); `buildFiscalOperationalPendingItems` nao exige `apiToken` no doc se existir `FOCUS_API_TOKEN` (Focus) como em `validateInvoiceReadinessForOfficialIssue`.
- **Fiscal (Web)**: governo **empresa suprema** em integracao (dialog «Configurar emissao real»), matriz, preparar CNPJ, reprocessar automacao, homologacao e chip «Integracao real (Focus)»; empresas: «NFS-e oficial», subir **certificado** (provisionamento), **Sincronizar Focus** e emissao; limpeza de part duplicado em `fiscal_readiness_sections.dart`.
- **Deploy**: apos push, `firebase deploy --only functions` (e hosting se publiquem web); Android: build e Play Console com o AAB canónico; se o `firebase deploy` local falhar com timeout, repetir ou seguir a documentacao de timeouts.

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
