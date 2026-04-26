# Status do projeto e proximos passos

## O que ja foi feito

### Base trabalhista e RH

- cadastro de funcionario com:
  - cargo
  - data de admissao
  - tipo de remuneracao (`diaria`, `mensal`, `comissao`)
  - valor salarial
  - percentual de comissao
- gestao de folha por competencia
- calculo automatico com base em:
  - dias/apontamentos aprovados
  - servicos finalizados com valor
  - salario mensal cadastrado
- geracao de:
  - holerite simples
  - recibo
  - comprovante de renda
  - contrato simples
- exportacao em lote de holerites
- assinatura eletronica simples:
  - nome
  - data/hora
  - imagem de assinatura opcional
- historico de aceite por funcionario
- acompanhamento operacional na gestao trabalhista para:
  - `13 salario` por funcionario na competencia
  - `ferias` em acompanhamento na competencia
  - geracao simples de `recibo 13 salario`
  - geracao simples de `recibo ferias`
  - geracao simples de `termo de rescisao`

### Fechamento e governanca

- fechamento mensal da folha por competencia
- reabertura de competencia
- bloqueio de criacao/edicao/remocao em competencias fechadas
- snapshot de fechamento salvo em `payroll_closures`
- historico de fechamento e reabertura
- PDF de resumo mensal
- PDF de fechamento da competencia
- painel RH mensal com divergencias e pendencias
- geracao automatica de pagamentos faltantes

### Permissoes e seguranca

- modo `simples` e `completo` no trabalhista
- modo `simples` e `completo` no financeiro
- permissoes operacionais por gerente
- protecao de campos sensiveis em `company_settings`
- regras de backend em `firestore.rules` para:
  - pagamentos
  - dividas
  - movimentos financeiros
  - documentos da folha
  - fechamentos
  - notas de servico
  - solicitacoes sensiveis

### Aprovacoes e auditoria

- solicitacao e aprovacao do dono para:
  - fechamento da folha
  - reabertura da folha
  - limpeza financeira
  - mudancas sensiveis do financeiro
  - mudancas sensiveis do trabalhista
  - mudancas sensiveis do fiscal
- comentario do aprovador
- historico recente de solicitacoes
- auditoria operacional em `audit_logs`
- filtros na tela de auditoria
- exportacao PDF da auditoria

### Notas e contratos

- controle interno de notas de servico
- campo para numero oficial da NFS-e
- campo para link do portal oficial
- PDF auxiliar da nota
- contratos simples com aviso de revisao juridica

### Nova camada fiscal preparatoria

- novo modulo `Fiscal`
- rota `/fiscal`
- card no painel inicial
- configuracao fiscal por empresa:
  - `fiscalMode`
  - `fiscalFeatures`
- recursos fiscais configuraveis:
  - `NFS-e oficial`
  - `encargos da folha`
  - `13 salario`
  - `ferias`
  - `rescisao`
  - `beneficios`
- resumo fiscal por competencia
- conferencia de NFS-e com pendencias:
  - sem numero oficial
  - sem link oficial
- checklist mensal salvo em `fiscal_competence_checks`
- checklist mensal ampliado com controle operacional por competencia para:
  - conferencia individual de `13 salario`
  - acompanhamento individual de `ferias`
  - observacoes de `rescisao`
  - observacoes de `beneficios`
- PDF de resumo fiscal

### Operacao pequena x estrutura maior

- novo `perfil operacional` da empresa em `Empresa`
- perfis selecionaveis:
  - `Pequena`
  - `Crescimento`
  - `Estrutura maior`
- os presets ligam/desligam modos e recursos recomendados de:
  - financeiro
  - trabalhista
  - fiscal
- nada da camada maior foi removido; tudo continua selecionavel depois
- os modulos agora mostram orientacoes por perfil:
  - empresa pequena: uso simples e direto
  - crescimento: proximos controles recomendados
  - estrutura maior: implementacoes e integracoes sugeridas
- a tela `Empresa` agora mostra um checklist de implantacao por perfil para ajudar na configuracao inicial
- a tela `Empresa` agora tem `Assistente de ativacao inicial` com aplicacao em 1 clique por perfil

## O que ainda precisa fazer

### Prioridade alta

- integrar emissao oficial de `NFS-e`
  - prefeitura
  - padrao nacional
  - ou integrador externo
- criar rotina oficial de folha para envio ao contador/eSocial
- calcular encargos reais:
  - INSS
  - FGTS
  - IRRF
- transformar a camada fiscal atual de preparatoria para operacional oficial

### Prioridade media

- implementar calculo operacional mais completo de:
  - ferias
  - 13 salario
  - rescisao
  - beneficios
- gerar relatorios mensais mais completos para contador
- numeracao e padronizacao fiscal mais forte para documentos
- filtros e dashboards por periodo no modulo fiscal

### Prioridade corporativa

- integracao com eSocial
- integracao com contador/escritorio contabil
- trilha de auditoria ainda mais forte no backend
- aprovacao em duas etapas para operacoes criticas adicionais
- automacoes de vencimentos e obrigacoes fiscais

## Arquivos principais dessa fase

- `lib/features/workforce/presentation/pages/workforce_management_page.dart`
- `lib/features/finance/presentation/pages/finance_company_page.dart`
- `lib/features/audit/presentation/pages/audit_page.dart`
- `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/core/router/app_router.dart`
- `firestore.rules`
- `docs/WORKFORCE_FIRESTORE_DEPLOY.md`
- `docs/FISCAL_READINESS.md`

## Proximo passo recomendado

Escolher uma frente para continuar:

1. `NFS-e oficial`
2. `encargos e eSocial`
3. `ferias, 13 e rescisao`
## Atualizacao 2026-03-14 - SaaS web-first e emissor fiscal

- Arquitetura web-first registrada em `ARQUITETURA_SAAS_WEB_FIRST_2026-03-14.md`.
- Roadmap do emissor fiscal real registrado em `ROADMAP_FISCAL_REAL_2026-03-14.md`.
- Criada base para consultas fiscais via backend:
  - `lookupBrazilCnpj`
  - `lookupBrazilCep`
- Adicionadas colecoes/regras para:
  - `invoice_customers`
  - `registry_cache`
- Formulario de NFS-e no fiscal recebeu:
  - busca por CNPJ
  - busca por CEP
  - campos de inscricao municipal/estadual
  - campos de email/telefone
  - endereco do tomador
  - codigo de servico
  - deducoes
  - aliquota ISS
  - indicacao de ISS retido
  - totais fiscais basicos
- Notas novas passam a gravar blocos estruturados:
  - `customer`
  - `service`
  - `tax`
- Cadastro do tomador passa a ser salvo em `invoice_customers` para reaproveitamento futuro.
