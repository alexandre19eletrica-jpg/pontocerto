# Checklist Tecnico Proxima Fase

Data: 22/03/2026

## Objetivo

Lista operacional da fase seguinte, quando a consolidacao visual e estrutural principal ja estiver avancada e o foco passar para estabilidade tecnica e operacao real.

## Validacao tecnica

- estabilizar o ambiente antes de nova rodada estrutural:
  - encerrar processos `java`, `flutter` e `dart` orfaos quando o terminal travar
  - limpar `build` e `.dart_tool` quando a web parar de responder com confianca
  - manter Android como validacao primaria e `web` como validacao secundaria ate o build web voltar a fechar de forma confiavel
- tentar rodar `flutter analyze` por arquivo ou por modulo
- tentar rodar formatacao controlada dos arquivos mais alterados
- revisar imports, warnings e tipagem
- verificar se os arquivos refatorados continuam coerentes entre si
- usar `scripts/check_core_consistency.ps1` como fallback quando o ambiente estiver travando
- manter `ULTIMA_VALIDACAO_TECNICA.md` atualizado a cada rodada estrutural importante
- quando o `analyze` falhar dentro da sandbox, lembrar que o problema ja foi identificado como restricao do ambiente e nao necessariamente do codigo

## Fiscal

- prioridade maxima da frente estrutural atual
- fase 1 segura: extrair classes/helpers internos do fim de `fiscal_readiness_page.dart`
- fase 2 segura: extrair blocos visuais grandes do modulo
- fase 3 segura: extrair PDF, integracao real e compliance sem mudar regra
- manter `fiscal_readiness_page.dart` apenas como orquestrador gradualmente
- revisar `Cloud Functions` fiscais ponta a ponta
- revisar configuracao de provedor, certificado e homologacao
- testar ciclo de emissao oficial e cancelamento oficial
- revisar consistencia de `company_settings` ligado ao fiscal

## Workforce

- atacar somente depois da primeira rodada segura do `Fiscal`
- repetir a mesma estrategia: helpers/modelos, depois blocos visuais, depois servicos
- manter a regra atual: `Funcionarios` consulta e `Trabalhista` cadastro operacional
- manter a extracao de tiles/helpers de configuracao, notas internas e historicos documentais
- revisar fluxo de fechamento por competencia
- revisar aprovacoes, historicos e snapshots
- revisar geracao de documentos e nomenclaturas

## Financeiro

- revisar coerencia entre `finance`, `payments`, `debts` e `movements`
- confirmar que operacoes sensiveis relevantes usam backend
- revisar limpeza financeira e seus impactos

## Operacao compartilhada

- revisar consistencia do fluxo `Clientes -> Tarefas -> Propostas/Contratos -> Fiscal`
- revisar anexos, materiais e catalogos
- revisar reaproveitamento de cadastro de cliente/tomador
- manter como regra de plataforma:
  - `web` deve espelhar a versao Play Store `1.0.70+1040`
  - unica diferenca permitida: `funcionario` acessa apenas o app/Play Store

## Governanca

- revisar `firestore.rules` frente aos fluxos mais recentes
- revisar `functions/src/index.ts` com foco em permissao e auditoria
- manter `ESTADO_ATUAL_DO_SISTEMA.md` e `PLANO_DE_CONTINUIDADE_ESTRATEGICO_2026-03-22.md` atualizados
