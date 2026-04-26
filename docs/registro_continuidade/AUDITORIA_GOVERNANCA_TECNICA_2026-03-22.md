# Auditoria Governanca Tecnica

Data: 22/03/2026

## Escopo

Rodada de revisao da camada de governanca tecnica, com foco em `functions/src/index.ts` e `firestore.rules`.

## Conclusoes desta rodada

- o backend ja concentra operacoes sensiveis de `Payments`, `Debts` e `Fiscal`
- o fluxo fiscal real ja tem bloqueios de readiness e checklist no backend
- a camada de regras ainda permitia margem excessiva em configuracoes fiscais sensiveis

## Endurecimentos aplicados

### Firestore Rules

- `fiscalRealIntegration` passou a ser tratado como chave protegida em `company_settings`
- `fiscalCertificate` passou a ser tratado como chave protegida em `company_settings`
- `fiscalHomologationChecklist` passou a ser tratado como chave protegida em `company_settings`
- `fiscal_secure` ficou restrito a `owner` para leitura e escrita via cliente

## Leitura pratica

- gerente continua operando modulos do dia a dia dentro das permissoes previstas
- configuracoes fiscais criticas e o cofre fiscal deixam de ficar expostos ao mesmo nivel do operacional
- a separacao entre operacao e segredo/configuracao sensivel ficou mais coerente

## Proximo passo recomendado

- validar em ambiente real se nao existe tela de gerente dependendo de leitura direta de `fiscal_secure`
- revisar `firestore.rules` para possiveis endurecimentos equivalentes em outros blocos sensiveis
- quando o ambiente permitir, rodar validacao tecnica real de regras e fluxo end-to-end
