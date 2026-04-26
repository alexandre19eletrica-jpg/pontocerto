# Memoria viva do sistema (operacional)

Data (ultima edicao): 23/04/2026

Este documento consolida o que o sistema **promete**, como ele **funciona hoje**, e onde existem **desalinhamentos**/riscos. Ele complementa (nao substitui) `ESTADO_ATUAL_DO_SISTEMA.md` e deve ser atualizado quando mudancas relevantes entrarem.

**Nota operacional:** **Ate 22/04 inclusive** o cenario operacional estava **ok**; a **unica** data de **erro nao intencional** (deploy, host, dado ou codigo) e **23/04/2026** — nesse dia ocorreu a “burrada” que reintroduziu sintomas (tela em branco, b815, inconsistencia de codigo, etc.). **21/04/2026** foi dia de **emissao normal** e de **sistema redondo** (notas em producao, retorno de autorizacao). O bloco **«Correcoes no repositorio (23/04)»** abaixo e trabalho de codigo para **recuperar** a mesma disciplina; nao apaga a evidencia de 21/04.

**Evidencia resumida (21/04/2026, producao) — sem payload/XML/certs no repo:** emissao NFSe Nacional com `ambiente=producao`, `cStat=100`, `cTribNac` / codigo nacional **070501** (item **07.05.01**), DPS `nDPS=10`, nota `nNFSe=36`, `data_emissao` 21/04/2026 ~18:58-03:00, grupo de obra com CNO preenchido (exigencia atendida). Detalhe completo fica fora do git (dados fiscais e assinaturas nao se publicam aqui).

## Referencia: 21/04/2026 (ultima janela com emissao estavel)

- a memoria oficial do projeto foi realinhada ao estado atual depois da auditoria de coerencia entre `rotas`, `menu`, `CTAs`, `promessas comerciais` e `regras do Firestore`
- escopo atual do `accountant`:
  - usa `Home`, `Assistente`, `Ideias`, `Faturamento`, `Fiscal`
  - usa `Empresas do contador`, `Perfil fiscal do contador`, `Cadastrar empresa` e `Seja nosso parceiro`
  - acessa `Contratos` e `Documentos` em modo leitura coerente com as telas implementadas
  - nao usa `Relatorios` nem `Trabalhista` no estado atual
- `Ideias` continua disponivel para contador, mas `Abrir observabilidade` permanece restrito a acesso supremo
- o Firestore foi alinhado para permitir ao contador a leitura de `runtime_incidents` e `system_issues` no mesmo tenant, sustentando o modulo `Ideias` sem abrir observabilidade direta
- o fluxo `Focus / NFSe Nacional` com `Simples Nacional + ISS retido` ficou operacional em producao:
  - `pAliq` corrigido no XML
  - `cTribMun` automatico indevido removido do fluxo nacional
  - emissao real autorizada confirmada
- **registro operacional**: em **21/04/2026** o operador **emitiu notas normalmente** e deixou o **sistema redondo**; a **ultima nota** desse corte de referencia segue a evidencia resumida no paragrafo acima (**ate** 23/04 nada disso estava “quebrado” por essa frente).

## Correcoes no repositorio (23/04/2026) — apos alteracao local

Trabalho no codigo para **alinhar** item LC 116 e leituras fiscais na web ao que ja era esperado em 21/04; publicar `functions`/`hosting` depois disso volta a fechar o ciclo.

- no **modo Focus / NFSe Nacional**, a **mesma regra no app e no backend**: 4/5/6+ digitos viram 6 digitos nacionais e exibicao `XX.XX.XX`; o payload de emissao alinha in-memory `serviceCode` e `municipalServiceCode` (via `alignNationalServiceCodesOnInvoiceService` e `tryParseNationalLc116SixDigits` em `functions/src/index.ts` antes de `focusNationalTaxCode` e do corpo da nota)
- o Flutter: `lib/features/fiscal/utils/national_service_code_format.dart` (botoes **Normalizar**, dialogo e catalogo em modo `national`); o backend **espelha** para a emissao oficial
- **web fiscal**: listas/notas, tomadores e resumo com leitura pontual + `_webFiscalListEpoch` apos gravação (em vez de listener competindo com write), reduzindo `INTERNAL ASSERTION` b815; catalogo de servicos fiscais na web sem listener continuo

## Visao do produto (o que o sistema promete)

O **Ponto Certo** e uma plataforma SaaS multiempresa, **web-first**, para operacao do negocio (administrativo, financeiro, fiscal, trabalhista) com um **ambiente de contador** (carteira + rotina) e rastreabilidade/auditoria.

Promessa central (segundo `docs/registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md` e `docs/FISCAL_READINESS.md`):

- **Operacao simples** para empresa pequena (dono/gerente no dia a dia).
- **Conferencia e governanca** para contador (carteira, perfil fiscal, faturamento, fiscal, ideias e leitura operacional coerente).
- Integracoes sensiveis (ex.: emissao fiscal oficial) passam por **Cloud Functions**.
- Dados multi-tenant e RBAC por papel (owner/manager/accountant/employee).

## Arquitetura e entradas principais

- **Frontend**: Flutter + Riverpod + GoRouter
- **Backend**: Firebase (Auth/Firestore/Storage/Hosting) + Cloud Functions (`functions/src/index.ts`)
- **Colecoes relevantes**:
  - `service_invoices` (notas fiscais / NFS-e)
  - `invoice_customers` (tomadores/clientes compartilhados)
  - `finance_movements` (movimentos financeiros, receita ligada a nota)
  - `company_settings` / `fiscal_secure/{companyId}` (config + segredos fiscais)
  - `audit_logs` (trilha de auditoria)

## Regra de versao (Play Store / releases)

- **Regra**: sempre que gerar um novo AAB para publicar, a versao do `pubspec.yaml` deve ser **sempre maior** que a anterior.
  - Ex.: se ja subiu `1.0.73+1043`, a proxima deve ser `1.0.74+1044` (ou maior).
- **Fonte de verdade**: `pubspec.yaml` (`versionName`/`versionCode` do Android vem daqui).

## Convites e trials (30 dias) + onboarding do contador

Objetivo operacional desta rodada:

- Permitir que a plataforma (admin) e/ou o contador parceiro convidem novas empresas para um **teste gratuito de 30 dias**.
- Garantir onboarding consistente:
  - contador completa o **perfil do escritorio** (uma vez)
  - contador prepara o **fiscal** da empresa (base minima da integracao)
  - owner recebe email para **definir senha** e acessar
  - ao expirar, o sistema envia follow-up e bloqueia o acesso automaticamente

### Colecoes novas / relevantes

- `trial_invites`: tokens de convite (hash + expiracao + status)
- `accountant_links`: vinculo contador <-> empresa (carteira)
- `users/{uid}.accountantFiscalProfile`: perfil fiscal do escritorio (aplicado a toda carteira)

### Rotas publicas adicionadas ao fluxo

- `/cadastro-empresa?trialToken=...` (empresa faz o cadastro)
- `/cadastro-empresa-contador?trialToken=...` (contador faz o cadastro completo sem login previo)

### Functions / automacoes

- `platformIssueTrial90DayInvite` (nome historico; comportamento atual = 30 dias):
  - emite token + expira em 30 dias
  - envia email para empresa e para contador com links adequados
- `publicRegisterCompanyDirectSignup`:
  - aceita `trialInviteToken` e cria empresa como `trial` por 30 dias (graceUntil)
- `accountantRegisterCompanyTrial30d`:
  - contador logado cria empresa em trial 30 dias
  - owner recebe email para definir senha (sem senha no formulario)
  - contador ja fica vinculado na carteira (`accountant_links`)
- `platformTrial90DayFollowup` (nome historico; comportamento atual = 30 dias):
  - job diario: ao expirar graceUntil, envia email e bloqueia allowLogin

### Governanca (plataforma) - convites e exclusoes

- A pagina `Plataforma` passou a organizar os cards de governanca como â€œpastasâ€ (abre/fecha) para evitar poluicao visual.
- Convites (`trial_invites`) agora tem suporte a **soft delete** (exclusao logica), para manter a lista ativa limpa sem perder auditoria:
  - `platformDeleteTrialInvites`: marca `status='deleted'` e grava `deletedAt/deletedBy*`
  - `platformListTrialInvites`: retorna `deletedAtIso` e `deletedByName` para exibir na UI (secao â€œExcluidosâ€)

### Email personalizado (sem noreply do Firebase Auth)

Objetivo: todos os emails operacionais sairem com `MAIL_FROM` (ex.: `acesso@tudo-certo.com`) via SMTP Titan.

- `publicRequestPasswordResetEmail`: gera link de redefinicao via Admin SDK e envia email via SMTP (substitui o email automatico do Firebase Auth que usa `noreply@...`).
- Telas de login (empresa/contador/funcionario) foram ajustadas para chamar essa Function no â€œEsqueci minha senhaâ€.
- SMTP Titan exige **ativar acesso para apps de terceiros** (IMAP/POP/SMTP) no painel Titan/HostGator; sem isso, retorna erro `535 5.7.8`.

### Gate do contador (acesso liberado)

- O acesso do contador foi liberado: nao existe mais redireciono/bloqueio global por falta de perfil fiscal do escritorio ou readiness fiscal.
- Os dados do perfil fiscal do contador continuam necessarios, mas passam a ser exigidos apenas quando a operacao especifica precisar (telas/acoes correspondentes).

## Perfis e permissoes (como esta hoje)

Papeis existentes: `owner`, `manager`, `accountant`, `employee` (`lib/core/auth/session.dart`).

Rotas permitidas para **contador** (estado atual do app):

- `/home`, `/assistant`, `/improvements`, `/billing`, `/fiscal`, `/contracts`, `/documents`
- rotas do ambiente do contador: `/accountant-companies`, `/accountant-fiscal-profile`, `/accountant-register-company`, `/accountant-partner`

Observacao:

- `Relatorios` deixaram de fazer parte do escopo do contador nesta rodada, porque a tela dependia de colecoes ainda nao coerentes com as regras de dados desse perfil.
- `Trabalhista` continua fora do escopo atual do contador.

Observacao importante (impacto direto na sua solicitacao):

- A tela fiscal possui **gates de permissao** para operacoes (emitir/cancelar/consultar), incluindo um controle via `company_settings.accountantPermissions` (ex.: `allowIssueServiceInvoices`).
- Portanto, o â€œcontador com poderes quase iguaisâ€ depende de como `company_settings` esta configurado para cada empresa (e do que o backend valida em `assertCanOperateFiscalInvoices`).

## Fiscal (promessa x realidade)

O backend ja tem funcoes reais para operacao oficial:

- `fiscalIssueServiceInvoice`
- `fiscalCancelServiceInvoice`
- `fiscalRefreshServiceInvoiceStatus`
- `fiscalReconcileProcessingInvoices`
- `fiscalSyncFocusCompany`

E a UI fiscal (`lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`) oferece:

- CRUD de notas (rascunho)
- Emissao/cancelamento/consulta oficial via functions
- â€œReadinessâ€/checklist por competencia
- Vinculo opcional com tarefa de origem e geracao de financeiro

### Status oficial (ponto critico atual)

Na operacao real, a integracao Focus pode retornar estados intermediarios (ex.: **`processando_autorizacao`**), que o sistema precisa tratar como â€œem processamentoâ€ ate a autorizacao e o numero oficial.

### Regras nacionais (NFSe Nacional) vs â€œsimplicidadeâ€

Nem tudo e simplificavel no produto: algumas exigencias sao do **Emissor Nacional**/municipio/Focus.

Exemplo real desta rodada (empresa BONFIM):

- `codigo_tributacao_nacional_iss = 070202` (subitem 07.02.02)
- A Focus retornou erro **E0370**: â€œgrupo de obra obrigatorioâ€.

Conclusao operacional:

- A UI pode ser â€œsimplesâ€, mas o sistema precisa **exigir dados adicionais somente quando obrigatorio** (ex.: CNO/obra) para manter â€œseguro e funcionalâ€.

## Fluxo compartilhado (Clientes -> Tarefas -> Fiscal -> Financeiro)

Estado atual (segundo `AUDITORIA_FLUXO_COMPARTILHADO_2026-03-22.md`):

- `invoice_customers` virou base compartilhada de tomadores
- `service_invoices` guarda `customerId` e opcionalmente `sourceTask`
- nota pode gerar `finance_movements` e gravar `financeMovementId`

Risco atual:

- o fluxo ja existe, mas depende de disciplina operacional (ex.: nao criar notas duplicadas para o mesmo servico) e de telas grandes/densas.

## Modulos: leitura rapida de maturidade (resumo)

Baseado em `AUDITORIA_MODULOS_2026-03-22.md` e `ESTADO_ATUAL_DO_SISTEMA.md`:

- **Financeiro**: avancado, risco medio
- **Fiscal**: avancado, risco alto (frente estrategica)
- **Trabalhista**: avancado, risco alto (muito denso)
- **Clientes/Tarefas/Catalogo**: em consolidacao
- **Auditoria/Rules/Functions**: pilares criticos

## Principais desalinhamentos (o que revisar)

1. **â€œContador com poderes quase iguaisâ€ vs gates atuais**
   - hoje existe controle por rota + controles finos em `company_settings.accountantPermissions`.
   - precisa ficar explicitado na UI/Docs quais permissoes o contador deve ter por padrao para â€œoperar igualâ€.

2. **Fiscal â€œsimplesâ€ vs regras reais**
   - simplificacao precisa ser condicional: pedir/validar somente o necessario para cada caso (municipio, codigo nacional, retencoes).

3. **Estados intermediarios e erros acionaveis**
   - o sistema precisa padronizar status (processing/emitted/canceled/rejected/error) e sempre trazer mensagem operacional (ex.: E0370).

## Checklist de alinhamento (o que garantir antes de dizer â€œfuncionalâ€)

- owner/manager/accountant conseguem:
  - criar/editar nota
  - emitir/cancelar/consultar (quando permitido)
  - ver status intermediario + erro com causa
  - conciliar notas em processamento
  - evitar duplicidade (mesmo servico/mesmo tomador)
- contador consegue:
  - operar a mesma tela fiscal com o mesmo entendimento de estados
  - auditar/relatar para a empresa (reports)
  - ter visao de carteira e trocar empresa (`session.trocarEmpresa`)

## Como manter esta â€œmemoria vivaâ€ atualizada

- Leia primeiro `docs/registro_continuidade/CONTINUIDADE_ATUAL.md` e `ESTADO_ATUAL_DO_SISTEMA.md`.
- Atualize este arquivo quando mudar:
  - permissoes do contador
  - regras de emissao fiscal oficial (Focus/NFSe Nacional)
  - colecoes/chaves principais
  - estado de maturidade dos modulos

## Contratos validados (nao quebrar sem pedido explicito)

### 1) Web-first administrativo x App do funcionario (Play Store)

Contrato atual do produto (estado real):

- **Web**: destinado a operacao administrativa de **owner/manager/accountant**.
- **Funcionario na web**: deve permanecer **bloqueado** (redireciono + sign-out), evitando operacao administrativa pelo navegador.
- **App Android (Play Store)**: destinado a operacao leve do funcionario/testadores (ponto, justificativas, acoes rapidas), com escopo e consentimentos proprios.

Evidencias no codigo/documentacao:

- `lib/core/router/app_router.dart`: bloqueio de funcionario na web e redireciono com `employee-web-denied=1`.
- `docs/registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md`: frente Play Store/testadores, empresa publica isolada e passos de liberacao.
- `functions/src/index.ts`: funcoes `publicCreateEmployeeTesterLead`, `platformMarkEmployeeTesterPlayStoreIncluded`, `platformReleaseEmployeeTesterAccess`, `platformReleaseEmployeeTesterRealAccess`, `platformGetEmployeeTesterUsageSummary` e colecao `employee_tester_leads`.

### 2) Fiscal oficial via backend

- Emissao/cancelamento/consulta/conciliacao oficial devem continuar passando por Cloud Functions.
- O cliente Flutter nao deve incorporar segredos nem chamar diretamente endpoints sensiveis.

Evidencias:

- `functions/src/index.ts`: `fiscalIssueServiceInvoice`, `fiscalCancelServiceInvoice`, `fiscalRefreshServiceInvoiceStatus`, `fiscalReconcileProcessingInvoices`.
- `firestore.rules`: `fiscal_secure` e caches/assistente protegidos; escrita de assistente via backend.

## Pontos cegos a confirmar (nao e mudanca; e checklist de auditoria)

Algumas colecoes/subcolecoes aparecem no Flutter mas podem nao ter `match` explicito em `firestore.rules` do repo (com catch-all deny no final). Isto pode significar:

- a funcionalidade depende de Cloud Functions (sem leitura direta do cliente), ou
- as regras em producao divergem do arquivo no repo, ou
- existe um bug (reads negados) que so aparece em certos perfis/ambientes.

Itens a confirmar com cuidado antes de alterar:

- `material_catalog` (usado no app) vs regras no repo.
- `employee_registration_documents` (usado no workforce) vs regras no repo.
- subcolecoes sob `company_settings/*/implementation_records` (lidas no ambiente do contador) vs regras no repo.

## Servicos fiscais salvos (controle de empresa x validacao do contador)

Objetivo operacional:

- **Empresa** pode cadastrar servico fiscal manualmente, mas o item fica **inativo** (pendente) ate o contador validar.
- **Contador** valida e ativa o item para uso na emissao.

Implementacao:

- `firestore.rules` (match `fiscal_service_catalog`):
  - create: exige `active == false` para empresa
  - update: empresa edita apenas enquanto `active` continuar `false`; contador (permissao fiscal) pode ativar
- UI do dialogo de servico fiscal:
  - empresa ve o switch travado e o texto â€œAguardando validacao do contadorâ€
  - contador pode marcar â€œAtivo no emissorâ€

