# Arquitetura SaaS Web-First - 2026-03-14

## Direcao

O Ponto Certo passa a seguir um modelo `web-first` para operacoes pesadas e um modelo `mobile-light` para operacoes mais rapidas no app Android.

## Principios

- Web concentra operacoes administrativas, fiscais, financeiras e de configuracao.
- App Android concentra uso operacional leve, registro de ponto, consultas rapidas e aprovacoes simples.
- Integracoes externas sensiveis nao ficam no Flutter direto. Ficam em `Cloud Functions`.
- Dados fiscais e cadastrais devem ser reutilizaveis entre modulos, sem retrabalho por tela.
- Toda evolucao relevante precisa deixar rastro nesta raiz ou em `docs/`.

## Web

- Dashboard principal em formato SaaS com menu lateral.
- Modulos pesados:
  - Financeiro
  - Fiscal / NFS-e
  - Trabalhista
  - Relatorios
  - Configuracoes da empresa
- Formularios longos e fluxos complexos devem priorizar experiencia desktop.

## Mobile

- Registro de ponto
- Consulta de tarefas
- Consulta de pagamentos
- Justificativas
- Aprovacoes simples
- Atualizacao via Play Store

## Fiscal

O modulo fiscal deve evoluir para um emissor profissional, com:

- emitente
- tomador
- servico
- tributacao
- totais
- validacoes
- historico

## Integracoes fiscais

Integracoes externas devem passar por `Cloud Functions`:

- consulta de `CNPJ`
- consulta de `CEP`
- validacao cadastral
- cache interno por empresa
- futuro gateway de emissao real de NFS-e

## Colecoes novas

- `invoice_customers`
  - cadastro reutilizavel de tomadores/clientes para notas
- `registry_cache`
  - cache tecnico de consultas de CNPJ/CEP mantido pelo backend

## Estado atual

- shell lateral SaaS iniciada
- home, financeiro, fiscal e trabalhista migrando para visual desktop
- emissao de NFS-e movida do trabalhista para o fiscal
- proxima fase: transformar formulario fiscal em emissor realista

