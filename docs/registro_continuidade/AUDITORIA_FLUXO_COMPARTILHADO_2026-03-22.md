# Auditoria Fluxo Compartilhado

Data: 22/03/2026

## Escopo

Fluxo revisado:

- `Clientes`
- `Tarefas`
- `Fiscal`
- `Financeiro`

Objetivo: verificar se o sistema continua tratando o mesmo cliente e a mesma operacao como uma linha unica, sem fragmentar cadastro, origem do servico e receita.

## Estado atual do fluxo

### 1. Clientes

Base compartilhada principal:

- `invoice_customers`

Uso atual:

- `Clients` le e organiza essa base;
- `Tasks` reaproveita e atualiza o mesmo cadastro;
- `Fiscal` reaproveita e atualiza o mesmo cadastro.

Ponto positivo:

- o cliente/tomador ja deixou de ser local de um modulo so.

### 2. Tarefas

Base principal:

- `tasks`

Uso atual:

- `Tasks` salva `clienteId`, `clienteNome` e `clienteDocumento`;
- o ID compartilhado do cliente ja e derivado do documento;
- esse mesmo ID agora passou a ser respeitado no `Fiscal`.

Ponto positivo:

- a tarefa ja funciona como origem operacional rastreavel do servico.

### 3. Fiscal

Base principal:

- `service_invoices`

Uso atual:

- `customerId` alinhado ao mesmo ID compartilhado por documento;
- `sourceTaskId` e `sourceTask` persistidos na nota;
- emissao oficial valida coerencia minima entre tarefa e tomador;
- nota pode gerar receita no `finance_movements`;
- `financeMovementId` fica salvo na propria nota.

Ponto positivo:

- a nota agora esta ligada a origem operacional e ao financeiro.

### 4. Financeiro

Base principal:

- `finance_movements`

Uso atual:

- a receita gerada pelo fiscal pode carregar:
  - `sourceModule`
  - `sourceInvoiceId`
  - `sourceTaskId`
  - `sourceCustomerId`
  - `sourceCustomerName`
- a tela financeira da empresa agora mostra quando o lancamento veio de nota fiscal e, quando houver, de qual tarefa.

Ponto positivo:

- a receita deixou de ser um item cego sem origem operacional.

## O que foi fechado nesta fase

### Fechado

- identificador compartilhado de cliente entre `Tasks` e `Fiscal`;
- referencia de tarefa na nota fiscal;
- validacao backend de coerencia minima entre tarefa e tomador;
- criacao de receita financeira a partir da nota;
- visibilidade da origem fiscal no financeiro.

## O que ainda falta para considerar o fluxo realmente maduro

### 1. Vinculo automatico ainda e parcial

Hoje:

- a nota pode gerar o financeiro;
- mas isso ainda depende de acao direta no modulo fiscal.

Falta:

- decidir se o lancamento financeiro deve nascer automaticamente em situacoes especificas, como `NFS-e emitida`.

### 2. Cliente compartilhado ainda esta concentrado em `invoice_customers`

Hoje:

- isso funciona como base comum pratica.

Falta:

- decidir se essa colecao sera assumida oficialmente como cadastro mestre unico de cliente do sistema.

### 3. Falta leitura consolidada do ciclo completo

Hoje:

- o usuario consegue rastrear em partes.

Falta:

- uma visao unica do ciclo:
  - cliente
  - tarefa
  - nota
  - receita financeira

### 4. Falta criterio unico de fechamento operacional

Hoje:

- `Fiscal` ja esta forte em readiness;
- `Financeiro` ja recebeu rastreabilidade;
- `Tasks` ja fornece origem.

Falta:

- consolidar regra de quando uma operacao esta pronta para:
  - emitir
  - faturar
  - reconhecer receita

## Conclusao honesta

Este passo pode ser considerado fechado no nivel de integracao basica e rastreabilidade operacional.

O fluxo compartilhado ja nao esta mais solto como antes. Agora existe trilha minima consistente entre:

- cliente/tomador
- tarefa/origem
- nota fiscal
- movimento financeiro

O proximo passo correto deixa de ser “ligar modulos” e passa a ser “governar melhor a operacao integrada”.

## Proximo passo seguro

1. decidir se a receita financeira da nota deve nascer automaticamente em cenarios controlados;
2. consolidar uma visao executiva do ciclo `cliente -> tarefa -> nota -> receita`;
3. depois disso, retomar consolidacao estrutural de `Workforce`.
