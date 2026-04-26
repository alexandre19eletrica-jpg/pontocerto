# Inventario Firestore x regras (repo)

Data: 16/04/2026

Objetivo:

- Listar as colecoes **referenciadas pelo Flutter (cliente)**.
- Listar as colecoes **cobertas por `firestore.rules` no repo**.
- Apontar o **diff** (possiveis pontos cegos) sem alterar nada em producao.

> Importante: este inventario compara o **codigo do repo** com o arquivo `firestore.rules` do repo. Se o ambiente de producao tiver regras diferentes (deploy divergente), o diff abaixo pode ser “falso positivo” e precisa ser confirmado.

## 1) Colecoes referenciadas no Flutter (cliente)

Fonte: ocorrencias de `.collection('...')` em `lib/`.

- `accountant_links`
- `assistant_threads` (e subcolecao `messages`)
- `audit_logs`
- `company_runtime_summary`
- `company_settings`
- `debts`
- `device_consents`
- `employee_registration_documents`
- `finance_movements`
- `fiscal_competence_checks`
- `fiscal_secure`
- `fiscal_service_catalog`
- `generated_documents` (via feature `document_drafts`)
- `implementation_records` (aparece como subcolecao usada pela tela do contador)
- `invoice_customers`
- `justifications`
- `material_catalog`
- `payments`
- `payroll_closures`
- `payroll_documents`
- `period_closes`
- `product_feedback`
- `recurring_billings`
- `reports` (se aparece no cliente, o arquivo de rules existe; no app a leitura principal de relatorios parece vir de outras colecoes)
- `runtime_incidents`
- `service_invoices`
- `service_orders`
- `service_proposals`
- `service_catalog`
- `system_issues`
- `tasks`
- `users`

## 2) Colecoes cobertas por `firestore.rules` (repo)

Fonte: blocos `match /<collection>/{docId}` em `firestore.rules`.

- `users`
- `employees`
- `work_entries`
- `punches`
- `worked_days`
- `tasks`
- `projects`
- `service_orders`
- `recurring_billings`
- `generated_documents`
- `accountant_links`
- `service_proposals`
- `service_catalog`
- `debts`
- `payments`
- `audit_logs`
- `runtime_incidents`
- `system_issues`
- `reports`
- `product_feedback`
- `period_closes`
- `notifications`
- `finance_movements`
- `company_settings`
- `assistant_threads` (subcolecao `messages`)
- `assistant_secure`
- `payroll_documents`
- `payroll_closures`
- `fiscal_competence_checks`
- `service_invoices`
- `invoice_customers`
- `fiscal_secure`
- `fiscal_service_catalog`
- `registry_cache`
- `app_updates`
- `justifications`
- `device_consents`

## 3) Diff (pontos cegos potenciais)

### 3.1 Usado no Flutter, mas NAO aparece como `match` em `firestore.rules` do repo

Se o cliente tenta ler/escrever isso direto no Firestore, o `match /{document=**} allow false` vai negar.

- `material_catalog`
- `employee_registration_documents`
- `company_runtime_summary`
- `implementation_records` (aparece no Flutter como subcolecao; nao ha regra explicita de subcolecao sob `company_settings`)

Leituras recomendadas antes de qualquer mudanca:

- Confirmar se estas colecoes sao, na pratica, acessadas via **Cloud Functions** (e nao por Firestore direto).
- Confirmar se as regras em producao estao iguais ao repo (deploy).

### 3.2 Aparece nas rules, mas nao foi visto em `.collection('...')` no Flutter

Isto nao e problema; normalmente indica colecoes alimentadas por backend ou modulos ainda nao usados no cliente.

- `registry_cache`
- `notifications`
- `projects`
- `punches`
- `worked_days`
- `employees`
- `work_entries`
- `assistant_secure`
- `app_updates`

## 4) Checklist de confirmacao (sem mexer no sistema)

1. Validar se o modulo **Materiais** (UI) esta lendo/escrevendo `material_catalog` em producao sem erro de permissao.
2. Validar se o **Workforce** consegue criar/ler `employee_registration_documents` em producao.
3. Validar se o dashboard que usa `company_runtime_summary` funciona em producao.
4. Validar como a tela do contador le `implementation_records` (subcolecao) e se existe regra especifica em producao.

Se qualquer item acima falhar, o proximo passo seguro e:

- alinhar regras (repo + deploy) **ou**
- mover o acesso para Cloud Functions (se a colecao for sensivel).

