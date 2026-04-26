# Mapa Fiscal Real Backend

Data: 22/03/2026

## Objetivo

Registrar, de forma objetiva, o que o sistema ja possui para `NFS-e oficial`, o que ainda falta para operacao real controlada e qual deve ser a ordem de continuidade.

## O que ja existe hoje

### 1. Backend fiscal real em `Cloud Functions`

Arquivo base: `functions/src/index.ts`

Ja existem funcoes reais para emissao e cancelamento:

- `fiscalSyncFocusCompany`
- `fiscalIssueServiceInvoice`
- `fiscalCancelServiceInvoice`
- `lookupBrazilCnpj`
- `lookupBrazilCep`

Ja existem helpers estruturais para Focus NFe:

- `providerIsFocus`
- `focusRequest`
- `resolveFocusMunicipalityCode`
- `buildFocusCompanyPayload`
- `syncFocusCompany`
- `buildFocusInvoicePayload`
- `issueWithFocus`
- `cancelWithFocus`
- `callFiscalProvider`

Isso significa que o modulo fiscal ja nao esta apenas em preparacao. A base de integracao real ja existe.

### 2. Fluxo atual de emissao oficial

Hoje o fluxo backend funciona assim:

1. a tela fiscal chama `fiscalIssueServiceInvoice`;
2. a function valida autenticacao, perfil e `invoiceId`;
3. a nota e carregada de `service_invoices`;
4. `company_settings` e carregado e enriquecido por `mergeFiscalSecureSettings`;
5. se o provedor for `Focus NFe`, a empresa pode ser sincronizada antes da emissao;
6. a nota e enviada para o provedor;
7. o retorno oficial e persistido em `service_invoices`;
8. a acao gera `audit log`.

Persistencia ja prevista na nota:

- `status`
- `officialNumber`
- `officialPortalUrl`
- `officialProtocol`
- `officialProvider`
- `officialEnvironment`
- `officialIssuedAt`
- `lastEmissionAttemptAt`
- `lastEmissionAttemptStatus`
- `officialResponse`

### 3. Fluxo atual de cancelamento oficial

Hoje o cancelamento backend funciona assim:

1. a tela fiscal chama `fiscalCancelServiceInvoice`;
2. a function valida autenticacao, perfil e `invoiceId`;
3. carrega `service_invoices` e `company_settings`;
4. envia a operacao de cancelamento ao provedor;
5. persiste retorno na nota;
6. grava auditoria.

Persistencia ja prevista no cancelamento:

- `status`
- `cancellationReason`
- `canceledAt`
- `cancelProtocol`
- `lastEmissionAttemptAt`
- `lastEmissionAttemptStatus`
- `cancelResponse`

### 4. Configuracao sensivel e certificado

O sistema ja separa dados mais sensiveis:

- `company_settings` guarda configuracao funcional da empresa;
- `fiscal_secure/{companyId}` complementa segredos do certificado;
- `mergeFiscalSecureSettings` recompone os dados antes da emissao.

Ja existe suporte para:

- upload de certificado digital;
- armazenamento do caminho do arquivo;
- senha do certificado;
- login e senha do responsavel;
- sincronizacao do certificado com a Focus;
- retorno de validade e CNPJ do certificado.

### 5. Base de apoio operacional

Ja existe suporte no backend e na tela para:

- consulta de `CNPJ`;
- consulta de `CEP`;
- cliente fiscal salvo em `invoice_customers`;
- checklist por competencia em `fiscal_competence_checks`;
- persistencia de notas em `service_invoices`;
- trilha de auditoria do ciclo fiscal.

### 6. Regras `Firestore`

Arquivo base: `firestore.rules`

Ja ha regras especificas para:

- `company_settings`
- `fiscal_competence_checks`
- `service_invoices`
- `invoice_customers`
- `audit_logs`

O recorte atual indica que a seguranca multiempresa e o controle por perfil ja estao relativamente maduros para a operacao fiscal.

### 7. Endurecimento ja aplicado em 22/03/2026

Nesta rodada, o backend passou a:

- bloquear emissao oficial quando faltam dados minimos do emitente, tomador, servico ou configuracao fiscal real;
- registrar `lastEmissionError` na nota quando a emissao oficial falha;
- registrar `lastEmissionError` na nota quando o cancelamento oficial falha.

Esse endurecimento foi aplicado em `functions/src/index.ts`.

### 8. Reconsulta manual de status oficial ja aplicada em 22/03/2026

Nesta rodada, o sistema passou a:

- consultar novamente o status oficial da nota via `fiscalRefreshServiceInvoiceStatus`;
- persistir retorno oficial atualizado em `service_invoices`;
- marcar tentativa como `PROCESSING`, `SUCCESS`, `CANCELED`, `QUERY_SUCCESS` ou `QUERY_FAILED`;
- limpar `lastEmissionError` quando a reconsulta conclui com retorno valido;
- mostrar na lista fiscal quando a nota esta em processamento ou quando a consulta oficial falhou.

### 9. Conciliacao automatica de notas em processamento ja aplicada em 22/03/2026

Nesta rodada, o sistema passou a:

- reconciliar em lote notas em `PROCESSING` via `fiscalReconcileProcessingInvoices`;
- disparar essa conciliacao automaticamente na tela fiscal quando houver notas em processamento na competencia aberta;
- disponibilizar tambem uma acao manual de conciliacao em lote no cabecalho da secao de `NFS-e`.

### 10. Readiness operacional por empresa mais bloqueante na UI em 22/03/2026

Nesta rodada, a tela fiscal passou a:

- mostrar o estagio operacional da empresa (`Homologacao pendente`, `Homologacao pronta`, `Producao bloqueada` ou `Producao liberada`);
- listar bloqueios objetivos de readiness fiscal;
- explicitar se a liberacao de producao esta apta ou bloqueada;
- concentrar a leitura de certificado, provedor, token, codigo municipal, sincronizacao e homologacao em uma unica area.

### 11. Homologacao assistida persistida por empresa em 22/03/2026

Nesta rodada, a tela fiscal passou a:

- manter um checklist de homologacao salvo em `company_settings.fiscalHomologationChecklist`;
- acompanhar progresso de homologacao por empresa;
- registrar validacao de cadastro base, certificado, matriz fiscal, conexao com provedor, emissao piloto e autorizacao de producao;
- bloquear a marcacao de `producao autorizada` quando o readiness operacional ainda estiver incompleto.

### 12. Atualizacao automatica do checklist pela operacao real em 22/03/2026

Nesta rodada, o backend passou a:

- marcar `providerConnectionValidated` automaticamente quando a sincronizacao com a Focus NFe conclui com sucesso;
- marcar `providerConnectionValidated` e `pilotInvoiceValidated` automaticamente quando a emissao oficial ou a reconciliacao oficial retornam sucesso;
- reduzir a dependencia de marcacao manual para itens que ja possuem evidencia tecnica direta no sistema.

### 13. Passagem controlada para producao endurecida no backend em 22/03/2026

Nesta rodada, a emissao oficial em ambiente `producao` passou a exigir no backend:

- `companyBaseReviewed`
- `certificateValidated`
- `matrixValidated`
- `providerConnectionValidated`
- `pilotInvoiceValidated`
- `productionAuthorized`

Sem isso, a function bloqueia a emissao oficial com `failed-precondition`.

### 14. Identificador compartilhado do tomador alinhado entre fiscal e tarefas em 22/03/2026

Nesta rodada, o `Fiscal` passou a usar o mesmo ID compartilhado por documento que `Tasks` ja usa para gravar tomadores em `invoice_customers` e em `service_invoices.customerId`.

Isso reduz o risco de o mesmo cliente/tomador virar registros paralelos entre tarefa e nota fiscal.

### 15. Origem operacional da nota ligada a tarefa em 22/03/2026

Nesta rodada, o emissor fiscal passou a:

- permitir selecao de `tarefa de origem` no formulario da `NFS-e`;
- persistir referencia da tarefa em `service_invoices.sourceTask` e `sourceTaskId`;
- reaproveitar dados basicos da tarefa para cliente, descricao e valor quando disponiveis;
- exibir a origem da tarefa na lista fiscal e nos PDFs auxiliares/exportados.

### 16. Coerencia minima entre tarefa e nota validada no backend em 22/03/2026

Nesta rodada, a emissao oficial passou a validar no backend que:

- a tarefa vinculada existe;
- a tarefa pertence a mesma empresa;
- o cliente da tarefa nao diverge do tomador da nota;
- o documento do cliente da tarefa nao diverge do documento do tomador.

### 17. Ligacao fiscal-financeiro com rastreabilidade em 22/03/2026

Nesta rodada, o modulo fiscal passou a:

- gerar `finance_movements` de receita diretamente a partir da nota fiscal;
- gravar a referencia do lancamento financeiro em `service_invoices.financeMovementId`;
- carregar no financeiro a origem fiscal da receita, incluindo `sourceInvoiceId`, `sourceTaskId` e cliente;
- exibir na lista fiscal e nos PDFs quando a nota ja esta vinculada ao financeiro.

### 18. Auditoria tambem nas falhas fiscais oficiais em 22/03/2026

Nesta rodada, o backend passou a:

- registrar auditoria tambem quando a emissao oficial falha;
- registrar auditoria tambem quando o cancelamento oficial falha;
- registrar auditoria tambem quando a consulta oficial falha;
- registrar auditoria tambem quando a reconciliacao de nota em processamento falha.

Isso reduz ponto cego operacional em cenarios de erro no provedor.

## O que ainda falta para operacao real segura

### 1. Readiness cadastral do emitente

Ainda falta tratar como requisito operacional obrigatorio:

- conferir se o emitente tem `CNPJ`, `inscricao municipal`, endereco e municipio validos;
- impedir emissao oficial quando cadastro base estiver incompleto;
- deixar isso explicito na interface como bloqueio real, nao apenas como dica.

### 2. Readiness cadastral do tomador

Ainda falta endurecer:

- validacao de `CPF/CNPJ` do tomador;
- validacao de endereco minimo quando exigido pelo provedor/prefeitura;
- padrao unico para cliente compartilhado entre `Clientes`, `Tarefas` e `Fiscal`.

### 3. Readiness fiscal do servico

Ainda falta garantir de forma mais forte:

- `item_lista_servico`;
- `codigo_tributario_municipio`;
- `aliquota`;
- `natureza_operacao`;
- comportamento de `ISS retido`;
- consistencia entre catalogo e nota emitida.

Hoje a base existe, mas ainda depende bastante de preenchimento operacional correto.

### 4. Tratamento de estados oficiais

Ainda falta consolidar o ciclo completo de status:

- `processando`
- `emitida`
- `cancelada`
- `erro`
- `rejeitada`
- `pendente de consulta`

O backend ja consulta a Focus apos emitir, mas ainda falta uma estrategia mais clara para conciliacao quando o status oficial nao fecha imediatamente.

### 5. Reconciliacao e reprocessamento

Ainda falta uma rotina clara para:

- consultar novamente notas em processamento;
- reprocessar falhas recuperaveis;
- diferenciar erro de provedor, erro de cadastro e erro operacional;
- mostrar isso na tela de forma objetiva.

### 6. Homologacao por empresa

Ainda falta transformar a configuracao fiscal em readiness controlado por empresa:

- ambiente `homologacao` versus `producao`;
- comprovacao de certificado valido;
- sincronizacao da empresa com provedor;
- checklist de homologacao concluido;
- bloqueio de producao sem criterios minimos.

### 7. Conciliacao documental e financeira

Ainda falta ligar melhor a nota oficial com:

- movimento financeiro;
- tarefa/origem do servico;
- cliente/tomador;
- evidencias de cancelamento;
- historico de tentativas.

### 8. Operacao assistida e suporte

Ainda falta um fluxo mais operacional para o usuario:

- mensagens de erro mais acionaveis;
- diferenciacao entre falha local, falha de provedor e cadastro incompleto;
- checklist de emissao real por competencia;
- trilha de suporte para homologacao e producao.

## O que a tela fiscal ja faz hoje

Arquivo base: `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`

A tela ja suporta:

- emitir oficialmente via `fiscalIssueServiceInvoice`;
- cancelar oficialmente via `fiscalCancelServiceInvoice`;
- sincronizar empresa com `Focus NFe`;
- salvar configuracao de integracao fiscal real;
- upload de certificado;
- acompanhamento visual do readiness fiscal;
- checklist mensal por competencia.

Ou seja: a tela ja tem a espinha dorsal da operacao. O que falta agora e endurecer criterios, estados e fluxo operacional.

## Lacunas mais importantes

### Lacuna 1. Fiscal ainda esta forte em preparacao e media em controle operacional

Ja existe integracao, mas ainda falta transformar isso em operacao guiada por readiness real.

### Lacuna 2. Falta um ciclo de conciliacao oficial

Emitir e cancelar ja existe. Consultar, reconciliar, reprocessar e classificar falhas ainda precisa ficar mais claro.

### Lacuna 3. Falta endurecer bloqueios antes da emissao

O sistema precisa impedir emissao oficial quando:

- cadastro do emitente estiver incompleto;
- tomador estiver inconsistente;
- servico fiscal estiver mal classificado;
- configuracao real estiver insuficiente.

### Lacuna 4. Falta fechar a passagem para producao

O ambiente de `homologacao` e `producao` existe conceitualmente, mas a governanca da passagem ainda precisa ser melhor documentada e aplicada.

## Ordem recomendada de continuidade

### Fase 1. Endurecimento do readiness

- transformar pendencias cadastrais em bloqueios reais de emissao;
- revisar criterios minimos do emitente, tomador e servico;
- registrar readiness por empresa de forma objetiva.

### Fase 2. Conciliacao de status oficial

- criar rotina de consulta/reconsulta de nota oficial;
- classificar status e falhas com mais precisao;
- refletir isso na tela e na auditoria.

### Fase 3. Homologacao controlada

- fechar checklist de homologacao por empresa;
- validar certificado e sincronizacao;
- impedir producao sem requisitos minimos.

### Fase 4. Operacao ponta a ponta

- alinhar `Clientes`, `Tarefas`, `Catalogo` e `Fiscal`;
- garantir consistencia entre origem do servico e nota oficial;
- revisar conciliacao com financeiro.

## Proximo passo seguro imediato

1. Criar uma matriz de readiness fiscal obrigatoria por empresa.
2. Levar leitura de erro/status oficial para outras areas da tela fiscal.
3. Fechar auditoria operacional ponta a ponta entre `Clientes`, `Tarefas`, `Fiscal` e `Financeiro`.
4. Depois disso, retomar consolidacao estrutural de `Workforce`.
