# Plano De Evolucao ERP + IA + Contador

Data: 26/03/2026

## Premissa obrigatoria

Esta frente deve seguir a diretriz de evolucao controlada do `Ponto Certo`.

Regras fixas:

- reaproveitar o que ja funciona
- nao quebrar funcionalidades validadas
- nao remover fluxos homologados
- nao reescrever o sistema
- evoluir por modulos e extensoes isoladas

Principio tecnico:

`Nao mexer no que esta funcionando, apenas evoluir ao redor.`

## Objetivo estrutural

Expandir o `Ponto Certo` para uma base ERP de servicos com:

- operacao
- fiscal
- financeiro
- contratos
- ordens de servico
- projetos
- timesheet
- IA assistente
- acesso para contador

## Estado atual relevante

Base ja existente e que deve ser preservada:

- multiempresa com `companyId`
- RBAC atual com `owner`, `manager` e `employee`
- shell web-first com modulos administrativos
- modulo fiscal validado em emissao real
- automacao multiempresa de provisionamento Focus
- contratos e propostas ja existentes
- tarefas, clientes, materiais e catalogo de servicos ja ativos
- financeiro com `Cloud Functions`
- trilha de auditoria

## Gap principal identificado

O sistema ainda nao possui:

- papel `contador`
- modulo de chat IA
- estrutura de permissao fina para contador
- fundacao de assistente contextual
- modulo proprio de ordens de servico
- modo visual de projetos
- consolidacao explicita de timesheet como base de custo/faturamento
- governanca comercial multiempresa

## Estrategia de implementacao segura

Cada frente deve entrar em fases pequenas, isoladas e reversiveis.

### Fase 1 - RBAC Contador

Objetivo:

- introduzir o papel `contador` sem quebrar `owner`, `manager` e `employee`

Escopo:

- ampliar `Role` no app
- ampliar `AppRole` no backend
- ampliar regras do Firestore
- ajustar login/bootstrap/sessao
- criar permissoes iniciais do contador
- manter contador fora de modulos nao autorizados

Permissao inicial recomendada:

- acesso ao `Fiscal`
- acesso a `Financeiro`
- acesso a `Relatorios`
- acesso a `Contratos` em leitura
- acesso a exportacoes fiscais
- sem acesso a `Configuracoes`
- sem acesso a `Auditoria`
- sem acesso amplo a gestao de equipe

### Fase 2 - Vinculo Empresa x Contador

Objetivo:

- permitir 1 ou mais contadores por empresa com isolamento total por `companyId`

Escopo:

- cadastro e convite de contador
- associacao controlada a empresa
- telas de gestao de acessos
- trilha de auditoria de vinculo

### Fase 3 - Assistente Inteligente

Objetivo:

- adicionar modulo de chat com OpenAI sem espalhar logica na UI

Escopo tecnico recomendado:

- modulo novo `assistant`
- service isolado para provedor de IA
- backend para chamadas sensiveis
- contexto minimo por tela/modulo
- historico por empresa e usuario
- logs de uso

Primeiro corte seguro:

- chat de ajuda operacional
- respostas sobre uso do sistema
- sem escrita automatica em dados sensiveis

Status em 27/03/2026:

- base estrutural implementada no source
- callable `assistantSendMessage` criada no backend
- historico separado em `assistant_threads`
- rota `/assistant` adicionada no Flutter source
- backend e regras publicados em `pontocerto-e1dab`
- pendente:
  - configurar chave OpenAI
  - rebuild/deploy web

### Fase 4 - Geracao assistida de documentos

Objetivo:

- gerar rascunhos de documentos a partir de dados ja existentes

Escopo:

- contrato de funcionario
- contrato de prestacao de servico
- proposta comercial
- orcamento

Regra:

- IA gera rascunho
- usuario revisa
- sistema nao publica automaticamente sem confirmacao humana

Status em 27/03/2026:

- primeiro corte implementado no source como rascunho seguro
- modulo `document_drafts` criado com provider e tela propria
- rota `/documents` adicionada no Flutter source
- colecao `generated_documents` protegida em `firestore.rules`
- templates iniciais para contrato de colaborador, contrato de prestacao, proposta e orcamento
- pendente:
  - integracao opcional com OpenAI
  - exportacao PDF
  - aproveitamento mais profundo de propostas/contratos ja cadastrados
  - rebuild/deploy web

### Fase 5 - Ordens de Servico

Objetivo:

- estruturar execucao operacional em campo

Escopo:

- criar OS
- vincular cliente, projeto, servico e funcionario
- registrar status, fotos e observacoes

Status em 27/03/2026:

- base estrutural implementada no source
- rota `/service-orders` adicionada no Flutter source
- colecao `service_orders` protegida em `firestore.rules`
- pendente:
  - anexos/fotos
  - integracao mais profunda com faturamento
  - rebuild/deploy web

### Fase 6 - Projetos e Kanban

Objetivo:

- complementar `Tarefas` com visao de projeto

Regra:

- aproveitar base atual de tarefas
- adicionar camada de projeto por cima
- evitar reescrever o modulo existente

Status em 27/03/2026:

- base estrutural implementada no source
- modulo `projects` criado com provider e tela propria
- rota `/projects` adicionada no Flutter source
- quadro inicial por etapas (`planning`, `active`, `completed`)
- `firestore.rules` publicadas para a colecao `projects`
- pendente:
  - aprofundar relacao com tarefas
  - indicadores de progresso
  - rebuild/deploy web

### Fase 7 - Timesheet

Objetivo:

- consolidar horas por cliente, projeto e servico

Reaproveitamento recomendado:

- usar `work_entries` como base inicial
- evoluir em volta do modulo existente
- nao substituir o controle de horas ja ativo

Status em 27/03/2026:

- base estrutural implementada no source
- `work_entries` evoluiu de forma compativel para aceitar vinculos com projeto, cliente, tarefa e OS
- rota `/timesheet` adicionada no Flutter source
- tela inicial de lancamento e leitura de horas criada sobre a base existente
- pendente:
  - apuracao analitica por projeto/cliente/servico
  - fechamento mensal
  - integracao direta com rentabilidade
  - rebuild/deploy web

### Fase 8 - Financeiro e Fiscal automatizados

Objetivo:

- conectar contratos, recorrencia, cobranca e nota fiscal

Fluxo alvo:

- contrato
- recorrencia
- cobranca
- nota
- relatorio

Status em 27/03/2026:

- primeiro corte estrutural implementado no source
- modulo `recurring_billing` criado com provider e tela propria
- rota `/billing` adicionada no Flutter source
- colecao `recurring_billings` protegida em `firestore.rules`
- a acao inicial `Gerar cobranca` cria receita em `finance_movements` com origem `recurring_billing`
- pendente:
  - automacao calendarizada
  - integracao nativa com contratos existentes
  - geracao automatica de rascunho fiscal
  - cobranca externa/boletos/assinatura
  - rebuild/deploy web

### Fase 9 - Governanca Comercial SaaS

Objetivo:

- controlar planos, status, ativacao e bloqueio das empresas multitenant

Escopo inicial seguro:

- `company_settings.commercialSettings`
- leitura do status comercial no app
- bloqueio de login por estado da empresa
- callables protegidas para administracao da plataforma

Status em 27/03/2026:

- base estrutural implementada e publicada
- login e bootstrap respeitam o estado comercial
- pendente:
  - painel visual da plataforma
  - automacao de vencimento/renovacao
  - integracao com cobranca/assinatura

## Arquitetura recomendada

Respeitar a base existente:

- UI apenas para orquestracao e apresentacao
- regras de negocio em services/repositories
- integracoes sensiveis via backend
- documentos prontos para sincronizacao futura

Direcao de persistencia:

- manter Firebase como base ativa
- quando fizer sentido, adicionar cache/local-first sem desmontar o modelo atual
- nao introduzir `Hive` de forma agressiva em fluxos ja dependentes de Firestore

## Risco tecnico imediato

O maior risco desta frente e tentar implementar tudo em lote.

Regra operacional:

- nao abrir todas as frentes ao mesmo tempo
- fechar uma fase por vez
- validar estabilidade antes da proxima

## Ordem recomendada

1. papel `contador`
2. vinculo de contadores por empresa
3. modulo `Assistente Inteligente`
4. geracao assistida de documentos
5. ordens de servico
6. projetos/kanban
7. timesheet
8. faturamento recorrente e cobranca
9. rentabilidade por projeto/cliente
10. geracao assistida de documentos

Status em 27/03/2026:

- `rentabilidade por projeto/cliente` iniciada no source
- rota `/profitability` adicionada no Flutter source
- leitura inicial baseada em `projects`, `work_entries` e `finance_movements`
- custo hora mantido como estimativa local da tela para nao introduzir risco em folha e financeiro
- pendente:
  - custo de equipe real
  - alocacao mais precisa de receita por projeto
  - persistencia segura dos parametros analiticos
  - rebuild/deploy web
7. timesheet consolidado
8. automacoes de contrato + cobranca + fiscal

## Resultado esperado

Ao final dessa trilha, o `Ponto Certo` evolui para ERP de servicos sem perder:

- estabilidade
- multiempresa
- trilha fiscal validada
- integracoes ja homologadas
