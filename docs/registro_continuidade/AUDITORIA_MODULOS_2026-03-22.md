# Auditoria De Modulos

Data: 22/03/2026

## Escala usada

- `Status`
  - `Consolidado`
  - `Avancado`
  - `Em consolidacao`
  - `Basico`
- `Risco`
  - `Baixo`
  - `Medio`
  - `Alto`
- `Prioridade`
  - `Baixa`
  - `Media`
  - `Alta`
  - `Critica`

## Resumo executivo

O sistema ja tem corpo de SaaS operacional multiempresa com base forte em `Financeiro`, `Fiscal`, `Workforce` e `seguranca`. O principal gargalo atual nao parece ser ausencia de funcionalidade, e sim consolidacao estrutural, consistencia visual entre modulos e reducao de risco em telas muito grandes.

## Auditoria por modulo

### Home

- `Status`: `Avancado`
- `Forca`: painel executivo mais coerente com o shell web e leitura operacional consolidada
- `Risco`: `Baixo`
- `Prioridade`: `Media`
- `Observacao`: esta em boa direcao; pede apenas refinamento fino de consistencia e densidade visual

### Financeiro

- `Status`: `Avancado`
- `Forca`: boa separacao empresa/funcionario, backend sensivel em functions, resumo operacional forte
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: modulo importante e relativamente maduro, mas a visao do funcionario ainda parece abaixo do nivel do cockpit principal

### Fiscal

- `Status`: `Avancado`
- `Forca`: modulo proprio, busca `CNPJ`/`CEP`, base de NFS-e, servicos fiscais e preparacao para emissao real
- `Risco`: `Alto`
- `Prioridade`: `Critica`
- `Observacao`: e a frente mais estrategica do sistema; funcionalmente promissor, mas ainda em transicao entre camada preparatoria e operacao oficial

### Trabalhista

- `Status`: `Avancado`
- `Forca`: folha por competencia, documentos, fechamento, reabertura, apoio a `13`, `ferias` e `rescisao`
- `Risco`: `Alto`
- `Prioridade`: `Alta`
- `Observacao`: modulo rico, mas muito denso; precisa consolidacao estrutural para nao virar gargalo permanente

### Empresa

- `Status`: `Avancado`
- `Forca`: virou centro de configuracao do emitente e do perfil operacional do negocio
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: tem papel central na configuracao dos demais modulos; deve permanecer consistente e previsivel

### Funcionarios

- `Status`: `Avancado`
- `Forca`: base forte para RH, folha e operacao por empregado
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: relevante, mas parece depender da estabilidade do `Workforce` para entregar tudo com qualidade

### Clientes

- `Status`: `Em consolidacao`
- `Forca`: virou base compartilhada para tarefas e fiscal, com busca por `CNPJ`
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: modulo pequeno, mas estrategico; precisa ficar muito consistente porque reduz retrabalho entre frentes

### Tarefas

- `Status`: `Em consolidacao`
- `Forca`: modulo operacional conectado a cliente, anexos, PDF e execucao
- `Risco`: `Alto`
- `Prioridade`: `Alta`
- `Observacao`: importante no fluxo diario, mas parece concentrar muita logica e merece revisao estrutural futura

### Catalogo de servicos

- `Status`: `Em consolidacao`
- `Forca`: base reaproveitavel para tarefas, propostas e contratos
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: funcionalmente util; precisa manter coerencia com o fluxo de aprovacao e com a base comercial

### Materiais

- `Status`: `Basico`
- `Forca`: complemento operacional da base de servicos
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: parece menos central hoje que servicos, fiscal e financeiro

### Propostas

- `Status`: `Em consolidacao`
- `Forca`: ajuda a costurar operacao comercial com execucao
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: deve evoluir junto de contratos e clausulas, nao isoladamente

### Contratos e clausulas

- `Status`: `Em consolidacao`
- `Forca`: sustentam formalizacao do fluxo comercial
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: relevantes, mas nao parecem o gargalo tecnico imediato

### Dividas

- `Status`: `Em consolidacao`
- `Forca`: ja opera com permissao, aprovacao e baixa
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: funcionalmente boa, mas com acabamento visual inferior ao shell principal

### Pagamentos

- `Status`: `Avancado`
- `Forca`: fluxo importante ja protegido com backend e regras
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: deve continuar alinhado ao financeiro, nao como modulo paralelo desconectado

### Relatorios

- `Status`: `Basico`
- `Forca`: existe como camada de leitura transversal
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: tende a crescer conforme financeiro, fiscal e workforce consolidarem indicadores

### Ponto

- `Status`: `Avancado`
- `Forca`: parte operacional forte do uso diario
- `Risco`: `Medio`
- `Prioridade`: `Media`
- `Observacao`: depende de consentimento e regras adequadas; importante manter simples e robusto

### Justificativas

- `Status`: `Avancado`
- `Forca`: fluxo operacional claro com estados e historico
- `Risco`: `Baixo`
- `Prioridade`: `Baixa`
- `Observacao`: parece relativamente estabilizado frente a outros modulos

### Auditoria

- `Status`: `Avancado`
- `Forca`: componente essencial de governanca e rastreabilidade
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: vale manter forte porque sustenta seguranca e confianca operacional

### Configuracoes

- `Status`: `Em consolidacao`
- `Forca`: concentra configuracoes sensiveis e operacionais
- `Risco`: `Alto`
- `Prioridade`: `Alta`
- `Observacao`: qualquer incoerencia aqui pode vazar para varios modulos

## Estrutura transversal

### Sessao e autenticacao

- `Status`: `Avancado`
- `Forca`: bootstrap de sessao e sincronizacao com Firebase Auth
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: base boa; precisa continuar previsivel porque impacta todo o sistema

### Rotas e RBAC

- `Status`: `Avancado`
- `Forca`: controle por perfil e bloqueio de funcionario na web
- `Risco`: `Medio`
- `Prioridade`: `Alta`
- `Observacao`: pilar importante da versao web-first

### Firestore Rules

- `Status`: `Avancado`
- `Forca`: tenant, role, employee scope e protecao de configuracoes sensiveis
- `Risco`: `Medio`
- `Prioridade`: `Critica`
- `Observacao`: esta entre os ativos mais importantes do sistema

### Cloud Functions

- `Status`: `Avancado`
- `Forca`: operacoes sensiveis saindo do cliente e indo para backend
- `Risco`: `Medio`
- `Prioridade`: `Critica`
- `Observacao`: caminho correto para estabilidade operacional e fiscal

## Maiores riscos hoje

1. `Fiscal` e `Workforce` estao muito importantes e muito densos ao mesmo tempo.
2. `Tasks` e alguns modulos internos ainda podem acumular complexidade demais em paginas unicas.
3. A padronizacao visual nao chegou no mesmo nivel para todos os modulos.
4. O conhecimento do sistema vinha se espalhando em arquivos soltos; isso comecou a ser corrigido agora.

## Ordem de execucao recomendada

1. Consolidar os modulos internos ainda abaixo do padrao visual do shell principal:
   - `Financeiro funcionario`
   - `Dividas`
   - pontos restantes de `Clientes`, `Tarefas` e `Catalogo`
2. Revisar modulos de alto valor e alto risco:
   - `Fiscal`
   - `Workforce`
   - `Configuracoes`
3. So depois aprofundar novas frentes fiscais e corporativas

## Conclusao

Hoje o sistema esta forte o suficiente para ser tratado como uma plataforma operacional real, mas ainda nao esta no ponto ideal para abrir muitas novas frentes sem consolidacao. O caminho mais seguro e fortalecer consistencia, reduzir concentracao de logica em arquivos centrais e preservar a evolucao do `Fiscal` como prioridade estrategica.
