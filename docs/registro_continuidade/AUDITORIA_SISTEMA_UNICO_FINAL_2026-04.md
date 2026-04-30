# Auditoria «sistema unico» — conclusao (abril/2026)

Estado: **revisao de codigo concluida** sem alterar fluxos ja **validados na empresa suprema** em producao. Nenhuma mudanca obrigatoria de backend ou de rota fiscal foi imposta nesta fase; o objetivo e **registar o desenho real** e **o que e apenas governanca** vs **o que e motor partilhado**.

## 1. Principio acordado

- **Uma unica aplicacao** (Flutter + Cloud Functions + Firestore). Nao ha «segundo produto» para escritorio contabil.
- **Rotas e menus** diferem por **perfil** (`Role`: owner, manager, accountant, employee) e por **empresa ativa** (`session.companyId`), nao por regras de negocio paralelas.
- **Isolamento**: cada operacao de dados deve estar ancorada no **mesmo `companyId`** da sessao (e regras Firestore); contador e empresa **nao misturam** dados entre empresas — o contador **troca a empresa ativa** na carteira, e a sessao passa a ver **so** aquele tenant.

## 2. Empresa suprema: o que e exclusivo (governanca)

A **suprema** (IDs em `lib/core/platform/platform_access.dart` e espelho em `functions/src/index.ts`: `SUPREME_PLATFORM_COMPANY_IDS`) existe para **governar a plataforma**, nao para ter outro motor fiscal.

**So na suprema (ou equivalente administrativo):**

- Ajustes **globais** da integracao Focus no dialogo «Preparar emissao fiscal real» quando `hasSupremePlatformAccess` (ambiente, provedor, URL, matriz, reprocessos) — ver `fiscal_readiness_integration_actions.dart` (`usesGlobalIntegrationDefaults`).
- Alguns blocos de **matriz / checklist** fiscal com copy explicita «suprema» em `fiscal_readiness_page.dart`.
- Rotas **plataforma**: `/platform-admin`, observabilidade alimentada por incidentes em tempo real no assistente, fila «suprema» no chat, etc.

**Nao e exclusivo da suprema (mesmo codigo para todos os `companyId`):**

- `buildRecommendedFiscalSetup`, `buildFocusProvisioningStatus`, `autoProvisionFocusCompanyIfReady`, `fiscalIssueServiceInvoice`, `fiscalSyncFocusCompany`, leitura de `service_invoices`, etc. — **mesmas funcoes**, **mesmos criterios** de token de plataforma (`FOCUS_API_TOKEN` + `usesPlatformFocusToken`), certificado e cadastro.

Detalhe Focus/provisionamento: continuar a ver `AUDITORIA_FOCUS_PROVISIONAMENTO_2026-04.md`.

## 3. Contador / escritorio (mesmo sistema)

- **Login**: rota dedicada (`/login-contador`) e **mesma** `MaterialApp` / `GoRouter`.
- **Empresa ativa**: `AccountantCompanyContextService` resolve `companyId` via `accountant_links` (ativo) + `currentCompanyId` / claims; `authSelectAccountantCompany` alinha **custom claims** ao tenant escolhido.
- **Modulos** (Fiscal, Documentos, etc.) leem `company_settings` e colecoes com **filtro do `companyId` atual** — o mesmo codigo de pagina que a empresa usaria como dono, com **permissao** de contador onde as regras o permitem.

Conclusao: a rota contador esta **coerente** com o desenho «um so sistema», **rotas diferentes**, **login e tenant** isolados.

## 4. Sincronismo obrigatorio (manutencao)

- Os **IDs** em `supremePlatformCompanyIds` (Dart) e `SUPREME_PLATFORM_COMPANY_IDS` (TypeScript) devem permanecer **identicos**. Qualquer novo ID suprema deve ser atualizado **nos dois sitios** antes de deploy.

## 5. Itens evolutivos (nao bloqueiam «sistema unico»)

- **Assistente**: credencial ja pode ser **só plataforma** (`OPENAI_API_KEY`); opcional evoluir UI para **não** incentivar chave por empresa em `assistant_secure` — decisao de produto, nao de paridade fiscal.
- **Varredura usabilidade**: mensagens que ainda falem «token API» fora do Fiscal — revisao pontual de copy quando aparecer.

## 6. Publicacao

Esta auditoria **nao exige** novo deploy por si so; alteracoes funcionais ja entregues seguem o fluxo normal (`publish_all.ps1` ou equivalente) quando o produto decidir.
