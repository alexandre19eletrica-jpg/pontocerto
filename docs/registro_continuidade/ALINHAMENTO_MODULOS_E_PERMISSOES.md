# Alinhamento de modulos e permissoes (auditoria operacional)

Data: 23/04/2026

Objetivo:

- Registrar, de forma simples, quais modulos estao OK, Parcial ou Incompleto do ponto de vista do que o sistema promete hoje.
- Definir uma matriz pratica de permissoes por papel com foco em manter o contador alinhado ao escopo real do sistema.

Fonte base:

- `docs/registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md`
- `docs/registro_continuidade/MEMORIA_VIVA_SISTEMA.md`
- `docs/FISCAL_READINESS.md`
- codigo: `lib/core/auth/session.dart`, `lib/core/router/app_router.dart`, `firestore.rules`, `functions/src/index.ts`

## Nota: app do funcionario (Play Store)

O sistema tem uma frente Android para funcionario/testadores, enquanto a operacao administrativa e web-first.

Regra atual:

- Funcionario nao opera no web.
- Funcionario opera no app para ponto, justificativas e rotinas leves.

## Auditoria modulo a modulo (promessa x execucao)

Legenda:

- OK: cumpre o que promete no estado atual, com risco aceitavel.
- Parcial: entrega a base, mas ainda depende de consolidacao operacional ou de UX.
- Incompleto: existe, mas nao e confiavel para o que promete sem retrabalho.

### Shell / Navegacao / Sessao (Web)

- Status: OK
- Evidencia: GoRouter + RBAC, bloqueio do funcionario na web, shell lateral consolidado.
- Risco: medio.

### Ambiente do contador

- Status: OK
- Evidencia: rotas exclusivas (`accountant-companies`, `accountant-fiscal-profile`, `accountant-register-company`) + operacao coerente em `/home`, `/assistant`, `/improvements`, `/billing`, `/fiscal`, `/contracts` e `/documents`.
- Escopo real atual:
  - carteira vinculada do contador
  - perfil fiscal
  - cadastro de empresa
  - faturamento
  - fiscal
  - ideias
  - contratos e documentos em leitura coerente
- Fora do escopo atual:
  - `/reports`
  - `/workforce`
  - observabilidade direta
- Risco: medio.

### Fiscal (NFS-e / NFSe Nacional / Focus)

- Status: Parcial
- Evidencia: functions de emitir/cancelar/consultar/conciliar; UI com rascunho e checklist; emissao nacional validada com `pAliq` e sem `cTribMun` automatico indevido; **item LC 116** com a mesma normalizacao no app (`national_service_code_format.dart`) e no payload (`alignNationalServiceCodesOnInvoiceService` em `buildFocusNationalInvoicePayload`); leitura web com `get` + epoca para reduzir b815. **Referencia 21/04/2026**: emissao producao **ok** (ex. `cStat=100`, `070501`); **erro operacional 23/04** documentado; ver `MEMORIA_VIVA_SISTEMA.md` (resumo, sem anexar XML no repo).
- Gaps principais:
  - mensagens de erro devem continuar acionaveis para o usuario
  - regras sensiveis seguem dependentes de readiness e permissao da empresa
  - ainda exige disciplina para operar a mesma nota ate o numero oficial
- Risco: critico.

### Financeiro

- Status: OK
- Evidencia: backend sensivel via functions; movimentos; pagamentos; dividas; rastreio de origem fiscal.
- Risco: medio.

### Trabalhista / Workforce

- Status: Parcial
- Evidencia: base funcional existe, mas o contador nao faz parte do escopo atual.
- Risco: alto por densidade de tela e complexidade operacional.

### Clientes (tomadores)

- Status: Parcial
- Evidencia: base compartilhada `invoice_customers`; usada por tarefas e fiscal.
- Gap: consolidar melhor o cadastro mestre e a UX de duplicidade.

### Tarefas / Ordens de servico

- Status: Parcial
- Evidencia: origem operacional, anexos, PDF e vinculo com fiscal e cliente.
- Risco: alto.

### Relatorios

- Status: Parcial
- Evidencia: leitura executiva transversal para owner/manager.
- Gap: nao prometer `reports` para contador enquanto o backend e as regras de dados nao estiverem alinhados para esse perfil.

### Auditoria / Observabilidade

- Status: OK
- Evidencia: `audit_logs`, `runtime_incidents`, `system_issues` e funcoes auxiliares.
- Regra atual: acesso direto continua restrito a perfis supremos; contador pode atuar via fluxo de ideias quando aplicavel.
- Risco: medio.

## Matriz de permissoes (pratica)

### Regras de produto desejadas

- Owner: tudo na propria empresa.
- Manager: opera quase tudo, exceto configuracoes sensiveis e governanca.
- Accountant:
  - opera fiscal quando a empresa permitir
  - atua em carteira, perfil fiscal, cadastro de empresa, faturamento, ideias e leitura coerente de contratos/documentos
  - nao opera plataforma suprema, observabilidade direta, reports ou trabalhista no estado atual
- Employee:
  - app mobile, sem acesso web admin

### Implementacao atual

- Rotas (frontend): `lib/core/auth/session.dart` + `lib/core/router/app_router.dart`
  - contador: `/home`, `/assistant`, `/improvements`, `/billing`, `/fiscal`, `/contracts`, `/documents`
- Gates finos (fiscal): `company_settings.accountantPermissions` + checks no backend (`assertCanOperateFiscalInvoices`)
- Regras de dados: `firestore.rules`

### Permissoes fiscais por papel

- Criar/editar rascunho de nota: owner/manager/accountant
- Emitir oficial: owner/manager/accountant quando readiness e permissoes permitirem
- Cancelar oficial: owner/manager/accountant quando permitido
- Consultar status oficial: owner/manager/accountant
- Conciliar notas em processamento: owner/manager/accountant
- Ajustes sensiveis de token/certificado/readiness:
  - owner sempre
  - manager conforme politica interna
  - accountant apenas se a politica da empresa permitir

## Lista objetiva de gaps ainda vivos

1. Consolidar, no UI e na documentacao, quais chaves em `company_settings.accountantPermissions` habilitam emitir, cancelar, consultar e conciliar.
2. Continuar padronizando mensagens operacionais de erro do provedor fiscal com causa, acao recomendada e campo exato.
3. Se no futuro `reports` entrar no escopo do contador, alinhar rota, tela, regra de dados e vitrine comercial ao mesmo tempo.
