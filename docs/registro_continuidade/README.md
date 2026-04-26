# Registro de continuidade

Esta pasta centraliza o estado atual do projeto e substitui os arquivos soltos de continuidade na raiz.

## Arquivos principais

- `CONTINUIDADE_ATUAL.md`
  - registro operacional corrente
  - sobrescrito/atualizado pelo processo automatico
- `ESTADO_ATUAL_DO_SISTEMA.md`
  - descricao consolidada da arquitetura, modulos, integracoes, maturidade e riscos
- `continuity_state.json`
  - metadados tecnicos usados pelo processo automatico

## Scripts

- `scripts/save_continuity.ps1`
  - gera ou atualiza `CONTINUIDADE_ATUAL.md`
  - atualiza `continuity_state.json`
  - grava snapshots rotativos em `docs/registro_continuidade/snapshots`
  - grava log de execucao em `docs/registro_continuidade/save_continuity.log`
  - remove registros antigos dispersos e logs tecnicos residuais
- `scripts/start_continuity_watcher.ps1`
  - monitora alteracoes em pastas-chave
  - dispara o salvamento automatico da continuidade
  - executa `heartbeat` periodico para salvar mesmo sem evento de arquivo confiavel
  - grava log do watcher em `docs/registro_continuidade/watcher_continuity.log`
- `scripts/install_continuity_startup.ps1`
  - instala o watcher como tarefa agendada no login do Windows
  - reduz risco de esquecer de iniciar o registro automatico
  - se o Windows bloquear a tarefa agendada por permissao, pode ser substituido por um launcher em `Startup`

## Uso recomendado

Salvar uma vez manualmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\save_continuity.ps1
```

Deixar automatico durante a sessao de trabalho:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_continuity_watcher.ps1
```

Instalar inicializacao automatica no login do Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_continuity_startup.ps1
```

## Politica

- a continuidade corrente fica centralizada nesta pasta
- esta e a pasta oficial de memoria do projeto
- antes de iniciar qualquer nova atualizacao, deve-se ler primeiro esta pasta, com prioridade para `CONTINUIDADE_ATUAL.md`
- toda nova atualizacao relevante deve ser registrada aqui antes de encerrar a rodada
- quando houver duvida sobre o estado do projeto, o registro desta pasta prevalece como fonte operacional
- registros antigos soltos na raiz nao devem mais ser criados
- logs tecnicos residuais e backups antigos devem ser limpos pelo processo
- o watcher deve preferencialmente ficar ativo durante a sessao ou ser instalado na inicializacao
