## Camada fiscal preparatoria

Arquivos principais:

- `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`
- `lib/core/router/app_router.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `firestore.rules`

Objetivo:

- preparar a empresa para a camada fiscal oficial sem obrigar integracao externa imediata
- manter operacao simples para empresa pequena
- liberar conferencia mais completa para empresa maior

Campos novos em `company_settings`:

- `fiscalMode`: `simple` ou `advanced`
- `fiscalFeatures`:
  - `enableOfficialInvoicePrep`
  - `enablePayrollTaxPrep`
  - `enableThirteenthSalary`
  - `enableVacation`
  - `enableTermination`
  - `enableBenefits`

Colecao nova:

- `fiscal_competence_checks`

Uso do modulo:

1. Abrir `Fiscal`
2. Escolher `Simples` ou `Completo`
3. Conferir a competencia fiscal
4. Validar pendencias de NFS-e oficial
5. Validar base de folha e checklist mensal
6. Exportar o resumo fiscal em PDF quando necessario

Perfil operacional da empresa:

- a tela `Empresa` agora permite aplicar presets de operacao:
  - `Pequena`
  - `Crescimento`
  - `Estrutura maior`
- esses presets ajustam os modos e recursos de financeiro, trabalhista e fiscal
- depois do preset, a empresa ainda pode personalizar cada modulo separadamente

Observacoes:

- a parte de NFS-e continua preparatoria; a emissao oficial depende de prefeitura, padrao nacional ou integrador
- a parte de encargos e folha oficial continua estimativa operacional para conferencia, nao substitui calculo contabil
- o checklist mensal foi feito para organizar envio ao contador e transicao para eSocial/rotinas oficiais

Seguranca:

- `fiscalMode` e `fiscalFeatures` ficam protegidos nas `firestore.rules`
- gerente pode solicitar ajuste sensivel via `period_closes`
- aprovacao/rejeicao do ajuste fiscal e exclusiva do dono
- `fiscal_competence_checks` aceita leitura e escrita apenas na mesma empresa por dono/gerencia
