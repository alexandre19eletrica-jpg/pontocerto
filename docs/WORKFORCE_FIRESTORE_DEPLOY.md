## Gestao trabalhista, notas e contratos

Arquivos alterados:

- `firestore.rules`
- `lib/features/workforce/presentation/pages/workforce_management_page.dart`

Novas colecoes:

- `payroll_documents`
- `payroll_closures`
- `service_invoices`

Campos novos em `company_settings`:

- `closedPayrollCompetences` com lista `YYYY-MM` das competencias fechadas
- `payrollClosureHistory` com historico de fechamento/reabertura
- `payrollDocumentSequence` com contador sequencial interno dos documentos da folha
- `workforceMode` com preset operacional (`simple` ou `advanced`)
- `workforceFeatures` com ligas/desligas por recurso do modulo

Permissoes esperadas:

- empresa/gerencia: leitura e escrita
- funcionario: leitura apenas dos documentos dele em `payroll_documents`
- funcionario: sem acesso a `payroll_closures`
- funcionario: sem acesso a `service_invoices`

Observacoes de consulta:

- `payroll_documents`
  - consultas atuais: `companyId + employeeId`
  - consultas atuais: `companyId + docGroup`
- `service_invoices`
  - consulta atual: `companyId`
- `payroll_closures`
  - consulta atual: `companyId + competence`

Se o Firestore pedir indice composto no console, criar estes:

1. Colecao `payroll_documents`
   Campos:
   - `companyId` Asc
   - `employeeId` Asc
   - `createdAt` Desc

2. Colecao `payroll_documents`
   Campos:
   - `companyId` Asc
   - `docGroup` Asc
   - `createdAt` Desc

3. Colecao `service_invoices`
   Campos:
   - `companyId` Asc
   - `issueDate` Desc

4. Colecao `payroll_closures`
   Campos:
   - `companyId` Asc
   - `competence` Asc

Fluxo recomendado de implantacao:

1. Publicar `firestore.rules`
2. Abrir o modulo `Gestao trabalhista`
3. Testar cadastro/edicao de funcionario com salario
4. Gerar um holerite
5. Gerar um contrato simples
6. Testar `Exportar holerites`
7. Testar `Fechar` e `Reabrir` competencia
8. Cadastrar uma nota de servico
9. Se o Firestore solicitar indice, criar pelo link do console e repetir o teste

Reforco de seguranca aplicado:

- `payments` agora nao aceita criar, editar ou excluir pagamentos em competencias fechadas tambem pelas `firestore.rules`
- documentos da folha passam a receber `sequenceNumber` e `sequenceLabel` internos, por exemplo `DOC-000001`
- fechamento/reabertura da competencia passa a gravar um snapshot consolidado em `payroll_closures`
- o modulo passa a permitir navegar pelo historico de competencias salvas e exportar um PDF proprio do fechamento mensal

Limite atual da funcionalidade:

- `NFS-e` no app e um controle interno com documento auxiliar
- a emissao fiscal oficial continua dependendo do portal oficial da prefeitura/NFS-e
- o contrato e um modelo base e nao substitui revisao juridica trabalhista
- assinatura atual e eletronica simples por nome + data/hora, sem certificado ICP-Brasil

Modo operacional:

- `simple`: indicado para empresas pequenas, escondendo recursos avancados por padrao
- `advanced`: libera o pacote completo do modulo
- mesmo no modo simples, a empresa pode ativar individualmente:
  - fechamento mensal
  - painel RH mensal
  - documentos avancados
  - notas de servico
  - contratos
  - confirmacao reforcada no fechamento da folha
  - aprovacao do dono antes do fechamento efetivo

Financeiro configuravel:

- `financeMode`: preset `simple` ou `advanced`
- `financeFeatures`: ligas/desligas para pagamentos, dividas, movimentos da empresa e limpeza financeira
- `financeManagerPermissions`: permissoes operacionais do gerente para criar pagamentos, gerir dividas, gerir movimentos e executar limpeza
- `financeManagerPermissions` agora tambem e usado pelas `firestore.rules` para travar escrita em `payments`, `debts` e movimentos da empresa em `finance_movements`
- `financeRequireOwnerApprovalForCleanup`: exige aprovacao do dono antes da limpeza financeira quando ativado

Gestao trabalhista configuravel:

- `workforceManagerPermissions`: permissoes operacionais do gerente para fechamento mensal, documentos da folha, notas de servico e contratos
- `workforceManagerPermissions` agora tambem e usado pelas `firestore.rules` para travar escrita em `payroll_documents`, `payroll_closures` e `service_invoices`
- campos sensiveis de configuracao (`finance*` e `workforce*`) passam a ser alteraveis apenas pelo dono nas `company_settings`

Auditoria operacional:

- alteracoes sensiveis de configuracao financeira e trabalhista passam a gerar registro em `audit_logs`
- fechamento e reabertura da folha tambem geram auditoria com competencia e totais principais
- limpeza financeira gera evento de auditoria antes da execucao

Aprovacao de fechamento:

- quando `requireOwnerApprovalForClosure` estiver ativo, gerente envia solicitacao em `period_closes`
- o dono aprova ou rejeita a solicitacao no modulo trabalhista
- somente apos aprovacao o fechamento efetivo da competencia e aplicado
- aprovacao e rejeicao agora podem registrar `resolutionComment`
- o painel mostra historico recente de solicitacoes aprovadas/rejeitadas

Aprovacao de limpeza:

- quando `financeRequireOwnerApprovalForCleanup` estiver ativo, gerente envia solicitacao em `period_closes`
- o dono aprova ou rejeita a limpeza pelo painel operacional
- somente apos aprovacao a limpeza e executada

Ajustes sensiveis por solicitacao:

- gerente agora pode solicitar mudancas sensiveis do modulo financeiro e do modulo trabalhista sem alterar `company_settings` direto
- essas solicitacoes usam `period_closes` com `module` igual a `finance_settings_change` ou `workforce_settings_change`
- somente o dono pode aprovar ou rejeitar a aplicacao dessas mudancas
- ao aprovar, o app aplica os novos valores em `company_settings` e registra auditoria

Relatorios para conferencia:

- a tela de `Auditoria` agora exporta PDF com os filtros aplicados
- o historico de solicitacoes passa a consolidar folha, limpeza e ajustes sensiveis antes da camada fiscal/oficial
