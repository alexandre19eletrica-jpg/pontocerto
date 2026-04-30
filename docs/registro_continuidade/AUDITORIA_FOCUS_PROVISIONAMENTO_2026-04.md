# Auditoria Focus / provisionamento / paridade empresa suprema (2026-04)

Objetivo: confirmar no codigo que **empresas novas** seguem a **mesma base de regras** que a empresa suprema para integracao Focus, sem alterar fluxos ja validados em producao.

## Backend (`functions/src/index.ts`)

- **`buildRecommendedFiscalSetup`**: para empresa de servicos, define rota (`focus_municipal` / `focus_national`), provedor Focus quando aplicavel, `usesPlatformFocusToken` quando existe `FOCUS_API_TOKEN` na plataforma e **nao** ha token proprio no doc da empresa (mesma logica para qualquer `companyId`).
- **`buildFocusProvisioningStatus` / `autoProvisionFocusCompanyIfReady`**: exige Focus como provedor, CNPJ, inscricao municipal, cidade, UF, token efetivo (empresa **ou** `FOCUS_API_TOKEN`), certificado com `storagePath` e senha. Igual para todos os tenants.
- **Emissao**: `buildFocusInvoiceServiceDescription` monta a discriminacao; anexa `emitter.fiscalPaymentBankInfo` ao final do texto do servico (corpo / notas na API Focus).

Nenhuma alteracao de regra foi necessaria nesta rodada: a suprema e as demais empresas **ja** passam pelo mesmo codigo; a diferenca e **governanca de UI** (matriz global, homologacao editavel so na suprema), nao o motor de token/provisionamento.

## App (`lib/`)

- **Provisionamento**: `fiscalRefreshCompanyProvisioning` chama o mesmo callable para qualquer empresa; pendencias (`focusProvisioning.missing`) refletem a checklist acima.
- **Dados de recebimento**: campo `companyData.fiscalPaymentBankInfo` em `company_settings`; **cartao dedicado** na pagina Fiscal quando NFS-e oficial esta ativa; dialogo de nota continua a sincronizar o mesmo campo ao salvar.

## Conclusao

- Nao foi introduzida divergencia de regra entre suprema e outras empresas no **provisionamento Focus**; o alinhamento e por **completar cadastro + certificado + reprocessar automacao** (`Sincronizar` / callable de refresh).
- Texto de recebimento entra na **discriminacao do servico** (nao em campo separado de observacao municipal), coerente com o payload atual da Focus.

**Auditoria mais ampla** («um so sistema», contador, governanca suprema): `AUDITORIA_SISTEMA_UNICO_FINAL_2026-04.md`.
