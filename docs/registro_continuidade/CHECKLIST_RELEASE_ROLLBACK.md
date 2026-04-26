# Checklist Release Rollback

Data: 22/03/2026 — secao **Paridade 21/04** em 23/04/2026

## Antes do release

- revisar `CONTINUIDADE_ATUAL.md`
- revisar `ULTIMA_VALIDACAO_TECNICA.md`
- tentar `analyze` se o ambiente permitir
- rodar `scripts/check_core_consistency.ps1` se o ambiente estiver com timeout
- revisar `functions/src/index.ts` se houve mudanca de backend
- revisar `firestore.rules` se houve mudanca de permissao
- confirmar integridade do fluxo `Clientes -> Tarefas -> Fiscal -> Financeiro`
- confirmar se `Workforce` continua coerente por competencia

## Release

- registrar data e objetivo da versao
- publicar frontend e backend na mesma janela quando houver dependencia cruzada
- validar login empresarial
- validar uma navegacao completa nos modulos centrais
- validar uma emissao fiscal de homologacao, se a release tocar fiscal real

## Depois do release

- revisar logs operacionais relevantes
- revisar se notas emitidas continuam conciliando com financeiro
- revisar se nao surgiram duplicidades em `finance_movements`
- atualizar `CONTINUIDADE_ATUAL.md` com o novo ponto real

## Paridade com o estado operacional de 21/04/2026 (apos regressao)

Objetivo: voltar o que o usuario ve (web) e o que emite (functions) ao mesmo **nivel de confianca** do dia em que a NFS-e em producao saiu **ok** (`cStat=100`, payload nacional coerente).

- **Codigo**: o repositorio ja concentra correcoes de emissao nacional (item LC 116 alinhado app + `buildFocusNationalInvoicePayload`) e estabilidade Firestore na web (`get` + epoca para listas fiscais). Nao basta “ter o codigo”: precisa **publicar**.
- **Build web completo**: na raiz do projeto, `flutter build web --release` e confirmar que existem `build/web/main.dart.js`, `build/web/index.html` e `build/web/flutter_bootstrap.js`. Evita tela branca por deploy incompleto.
- **Functions**: em `functions`, `npm run build` (deve passar sem erro de `tsc`).
- **Deploy na mesma janela** (quando houver mudanca cruzada web+backend): `firebase deploy --only "functions,hosting" --project pontocerto-e1dab` (ajuste o projeto se for outro). Assim o bundle web e o backend fiscal ficam alinhados.
- **Cache**: se o navegador ainda mostrar bundle antigo, hard refresh ou janela anonima; `firebase.json` ja manda `no-cache` em `index.html` e `main.dart.js`.
- **Prova rapida pos-deploy**: login, abrir Fiscal, lista de notas sem erro; em homologacao ou producao conforme politica, **uma emissao de teste** ou refresh de nota em processamento (se aplicavel).

## Rollback

- interromper novas alteracoes manuais no ambiente afetado
- identificar se o problema esta em frontend, backend ou regras
- reverter primeiro a camada que introduziu a regressao
- revisar integridade de `service_invoices`, `finance_movements` e `company_settings`
- registrar o incidente na continuidade atual
