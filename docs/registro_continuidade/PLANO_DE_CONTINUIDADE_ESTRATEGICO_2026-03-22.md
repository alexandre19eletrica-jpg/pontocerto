# Plano De Continuidade Estrategico

Data: 22/03/2026

## Objetivo

Este documento registra o que ainda falta para o `Ponto Certo` sair de uma base SaaS operacional forte para um sistema mais consolidado, validado e pronto para crescer com menos risco.

## Leitura honesta do momento atual

O sistema ja tem:

- estrutura multiempresa
- RBAC funcional
- shell web-first bastante consolidado
- modulos fortes em `Financeiro`, `Fiscal` e `Trabalhista`
- backend relevante em `Cloud Functions`
- regras `Firestore` maduras para varias operacoes sensiveis

O sistema ainda nao tem:

- validacao tecnica automatica estavel no ambiente atual
- emissao fiscal oficial fechada ponta a ponta em producao real
- refino estrutural suficiente nos arquivos mais longos
- cobertura operacional/documental que reduza risco de manutencao
- camada de relatorios e indicadores no mesmo nivel dos modulos operacionais

## Frentes que ainda faltam

### 1. Estabilizacao tecnica

Prioridade: `Critica`

Ainda falta:

- conseguir rodar `analyze`, formatacao e validacoes sem timeout
- revisar imports, warnings e inconsistencias silenciosas
- criar rotina minima de verificacao antes de novas entregas
- validar integridade entre `Flutter`, `Functions` e `Firestore Rules`

Entregaveis recomendados:

- rotina curta de verificacao local
- checklist de pre-release
- rodada de saneamento tecnico dos arquivos mais alterados

### 2. Refatoracao estrutural

Prioridade: `Alta`

Arquivos que ainda concentram risco:

- `lib/features/fiscal/presentation/pages/fiscal_readiness_page.dart`
- `lib/features/workforce/presentation/pages/workforce_management_page.dart`
- `lib/features/tasks/presentation/pages/tasks_page.dart`
- `lib/features/employees/presentation/pages/employee_review_page.dart`

O que falta:

- quebrar trechos longos em widgets/componentes menores
- separar leitura visual de regras de negocio
- reduzir duplicacao entre visoes `empresa` e `funcionario`
- preparar esses modulos para manutencao continua sem gargalo

### 3. Fiscal real

Prioridade: `Critica`

Esta e a frente mais estrategica do produto.

O que ainda falta:

- fechar configuracao real de provedor, ambiente e certificado
- validar emissao oficial por fluxo completo
- validar cancelamento oficial, retorno de erro e conciliacao de status
- revisar base cadastral do emitente e do tomador
- revisar persistencia e auditoria do ciclo fiscal
- revisar dependencias da emissao em `company_settings`

Entregaveis recomendados:

- checklist operacional de emissao real
- matriz de readiness por empresa
- fluxo assistido de homologacao
- revisao das `Cloud Functions` fiscais com cenarios de falha

### 4. Financeiro e conciliacao

Prioridade: `Alta`

O shell visual ja esta forte, mas ainda falta:

- revisar coerencia entre `payments`, `debts`, `movements` e `finance`
- confirmar se toda operacao sensivel esta protegida por backend
- revisar limpeza financeira e seus efeitos colaterais
- criar visao de conciliacao e historico operacional mais clara

Entregaveis recomendados:

- mapa de origem das operacoes financeiras
- checklist de consistencia por competencia
- revisao de seguranca entre cliente e `Cloud Functions`

### 5. Workforce e RH

Prioridade: `Alta`

O modulo ja e rico, mas ainda falta:

- consolidar fechamento mensal como fluxo mais previsivel
- revisar documentos gerados e nomenclaturas
- revisar paines de aprovacao e historico
- separar melhor `folha`, `contratos`, `documentos` e `operacoes complementares`

Entregaveis recomendados:

- mapa de fluxo da competencia trabalhista
- reducao de densidade do arquivo principal
- checklist mensal de RH/folha

### 6. Operacao compartilhada

Prioridade: `Alta`

Fluxo principal:

- `Clientes -> Tarefas -> Propostas/Contratos -> Fiscal`

Ainda falta:

- revisar consistencia de dados compartilhados
- reduzir duplicacao de cadastro
- garantir que o cliente salvo alimente corretamente tarefas e fiscal
- revisar PDFs, anexos, materiais e catalogos como partes do mesmo fluxo

Entregaveis recomendados:

- mapa unificado da jornada operacional
- padrao de identificacao de cliente/tomador
- revisao dos pontos de reutilizacao de catalogo e materiais

### 7. Relatorios e indicadores

Prioridade: `Media`

Ainda falta:

- levar `Reports` para um nivel mais executivo
- criar indicadores coerentes com `Financeiro`, `Fiscal` e `Workforce`
- evitar relatorio solto sem relacao com a operacao real

Entregaveis recomendados:

- painel de indicadores por competencia
- visao de inadimplencia, folha, emissao e produtividade

### 8. Governanca e operacao

Prioridade: `Alta`

Ainda falta:

- reforcar trilhas de auditoria nos fluxos mais criticos
- consolidar documentacao de continuidade e de release
- definir melhor o processo de atualizacao do sistema
- documentar configuracoes sensiveis por empresa

Entregaveis recomendados:

- manual interno de operacao
- checklist de deploy e rollback
- inventario de configuracoes sensiveis

Status em 22/03/2026:

- `manual interno de operacao` iniciado
- `checklist de deploy e rollback` iniciado

## Ordem recomendada para continuar

### Fase 1. Congelamento e estabilidade

- parar de abrir novas frentes grandes por um momento
- estabilizar validacao tecnica local
- revisar os modulos mais alterados recentemente

### Fase 2. Refino estrutural

- quebrar `Fiscal`, `Workforce`, `Tasks` e `Employee review`
- reduzir acoplamento de tela com regra
- consolidar componentes reutilizaveis

### Fase 3. Operacao real

- avancar `Fiscal` para fluxo oficial controlado
- revisar conciliacao do `Financeiro`
- revisar fechamento da competencia em `Workforce`

### Fase 4. Camada executiva

- evoluir `Reports`
- consolidar indicadores por competencia
- preparar processo de release e manutencao continua

## O que nao deveria ser prioridade agora

- abrir muitas frentes novas de modulo
- sofisticar visualmente telas que ja estao boas o suficiente
- aumentar escopo comercial antes de consolidar fiscal, financeiro e workforce

## Proximo passo seguro imediato

1. Validar tecnicamente os arquivos mais alterados quando o ambiente permitir.
2. Iniciar refatoracao estrutural de `Fiscal` e `Workforce`.
3. Criar um checklist operacional da emissao fiscal real.
4. Revisar consistencia entre `Financeiro`, `Payments` e `Debts`.
