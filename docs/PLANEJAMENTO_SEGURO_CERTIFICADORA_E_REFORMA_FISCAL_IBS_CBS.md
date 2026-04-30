# Planejamento seguro — certificadora e reforma fiscal (IBS/CBS)

**Estado:** registado apenas para execucao futura **passo a passo**. **Nada disto foi implementado** na rodada que criou este ficheiro.

**Data do registo:** 29/04/2026  
**Projeto:** Ponto Certo

**Regra maxima:** nao quebrar emissao NFS-e actual, payload Focus, cancelamento, consulta, conciliacao, ISS, financeiro vinculado, resumo fiscal, rotas ou permissoes validadas.

---

## Parte A — Integracao com certificadora (e-CNPJ / certificado A1 para emissao)

### Objetivo de produto

Permitir que o **contador**, na sua rota habitua, **inicie ou acompanhe** um pedido de certificacao com uma **certificadora parceira**, receba o certificado apos validacao, e **associe** o resultado ao fluxo **ja existente** de `company_settings` (`fiscalCertificate`, segredos, checklist, sincronizacao Focus) — **sem** substituir a Focus nem o motor de emissao.

### Principios de seguranca

1. **Orquestracao, nao substituicao:** o AC valida e emite; o sistema guarda **estado do pedido** e, no fim, os **mesmos** artefactos que o ecra fiscal ja espera (ficheiro / referencia / senha conforme modelo actual).
2. **Dados sensiveis:** minimo necessario; PII e callbacks com verificacao (assinatura/secret, HTTPS); idempotencia em webhooks.
3. **Nao ligar** pedido de certificadora directamente a `fiscalIssueServiceInvoice` nem aplicar `productionAuthorized` sozinho por callback — passos humanos/regra interna conforme modelo de risco.
4. **Coesistencia com PDF externo:** quando o fornecedor enviar especificacao (ex.: Soft House / Apresentacao no ambiente de trabalho), colar ou versionar em `docs/integracao_certificadora/` antes da Fase 1 de codigo.

### Encaixe arquitectural (conceito)

- **Rota nova** no perfil contador (ex.: item de menu + `GoRoute`), ou extensao de `accountant-fiscal-profile` / fluxo pos-«Cadastrar empresa».
- **Modelo de dados (conceitual):** documento ou subcolecao por `companyId` (e opcionalmente `officeId` / `accountantUserId`) com estados do tipo: `draft` → `submitted` → `awaiting_ca` → `issued` → `ready_to_upload` → `installed` (espelho de `fiscalCertificate` preenchido no Firestore).
- **Pontes:** ao estado `installed`, reutilizar fluxos existentes de upload / validade / sincronizacao Focus ja descritos na documentacao fiscal oficial.

### Fases sugeridas (so depois de OFICIAL_01/02/03 + aprovacao)

| Fase | Accao | Risco se feito cedo |
|------|--------|---------------------|
| A0 | Documentar API/webhook/PDF da certificadora no repo | Baixo |
| A1 | Tipos + colecao/coleccao segura + regras Firestore | Medio — rever `accountant_links` |
| A2 | UI contador (lista pedidos, detalhe, CTA) | Medio |
| A3 | Integracao HTTP + fila + validacao de assinatura | Alto |
| A4 | Testes E2E em homologacao | — |

**Nao executar** sem fechar A0 e alinhar compliance.

---

## Parte B — Preparacao para novas regras fiscais (IBS/CBS — “plano seguro”)

Origem: plano interno **“PLANO SEGURO – PREPARAR O PONTO CERTO PARA NOVAS REGRAS FISCAIS”** (reforma tributaria; CBS/IBS em documentos eletronicos orientados pela RF; **sem** calculo definitivo nem layout oficial no fluxo actual).

### Proibicoes explicitas (ate decisao futura)

- Alterar payload actual de emissao NFS-e, funcao que emite, cancelamento, consulta de status, conciliacao actual, calculo ISS, estados APPROVED/EMITTED usados no resumo, financeiro vinculado, resumo fiscal, rotas, permissoes, login, cadastro.
- Alterar tela fiscal de producao **sem** feature flag.

### Permitido (preparacao paralela)

- Novos modelos/campos **opcionais** (ex.: `taxProfile`, `taxBreakdown`, `futureTaxPreview`) — **nunca** obrigatorios; leitura legacy se ausentes.
- `fiscalRuleVersion` nas notas (default mental: `legacy` se ausente).
- Colecao `fiscal_operation_logs` (escrita **apos** operacao; falha de log **nao** bloqueia emissao).
- Funcao pura `simulateFutureTaxBreakdown(invoiceDraft)` — sem IO Focus, sem alterar nota/financeiro/resumo.
- Feature flags (ex.: `enableFutureTaxPreview`, `enableCbsIbsInPayload` **false** por defeito; **nunca** enviar CBS/IBS no payload real enquanto `enableCbsIbsInPayload` for false).
- Testes automatizados que validam regressao.

### Ordem de implementacao futura (obrigatoria)

1. Tipos/modelos opcionais apenas.  
2. Log fiscal extra.  
3. `fiscalRuleVersion`.  
4. Simulador isolado.  
5. Feature flags desligadas.  
6. Testes (emitir, cancelar, status, conciliar, resumo, nota antiga, simulacao off/on sem payload).  
7. UI discreta **so** com flag, texto “Preparacao fiscal futura”, sem promessa de conformidade.

### Resumo fiscal

Continuar a considerar apenas notas **oficiais autorizadas**, nao canceladas, com numero valido; **excluir** rascunho, erro, processamento, simulacao.

---

## Documentos oficiais a actualizar antes de codigo

Conforme regra do `OFICIAL_04`:

1. `OFICIAL_01` — expectativa visual (quando houver UI).  
2. `OFICIAL_02` — regra funcional.  
3. `OFICIAL_03` — sustentacao tecnica.  
4. So entao implementar; depois `OFICIAL_04` + `REGISTRO_ATUALIZACOES.md` + `CONTINUIDADE_ATUAL.md`.

---

## Referencia cruzada

- Memoria e registo: [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)  
- Registo operacional: [registro_continuidade/REGISTRO_ATUALIZACOES.md](registro_continuidade/REGISTRO_ATUALIZACOES.md)
