# Roadmap Fiscal Real - 2026-03-14

## Objetivo

Transformar o modulo fiscal em base de emissao real futura, sem depender de refazer a arquitetura depois.

## Fase 1

- mover NFS-e para o fiscal
- criar layout de emissor profissional
- criar cadastro de tomadores reutilizavel
- criar busca de `CNPJ` e `CEP` via backend
- salvar dados estruturados da nota no Firestore

## Fase 2

- criar servicos fiscais configuraveis por empresa
- mapear codigo de servico, CNAE, aliquota e municipio
- validar emitente e tomador antes de salvar
- criar historico e status de emissao

## Fase 3

- integrar provedor de emissao real
- protocolo, lote, cancelamento, carta de correcao quando aplicavel
- relatorio fiscal por competencia
- repasse padrao para contador

## Dados minimos da nota

- dados do emitente
- dados do tomador
- CNPJ/CPF
- inscricao municipal
- email e telefone
- CEP, logradouro, numero, complemento, bairro, cidade, UF
- codigo e descricao do servico
- valor bruto
- descontos
- base de calculo
- aliquota
- ISS retido
- valor liquido
- observacoes
- status
- numero oficial
- link oficial

## Regra de arquitetura

Consulta externa:

- nunca direto no Flutter web
- sempre via `Cloud Functions`
- com cache em Firestore

