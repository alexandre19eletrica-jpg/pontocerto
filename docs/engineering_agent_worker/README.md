# Worker local — Agente de Engenharia (implementação real)

Implementação Node.js em **`pontocerto-ai-worker/`** na raiz do repositório Ponto Certo.

## Resumo

- HTTP + WebSocket em **127.0.0.1** (segredo `WORKER_HTTP_SECRET`).
- Execução via **`powershell.exe -Command`** (`child_process.spawn`).
- Fila Firestore **`engineering_agent_worker_jobs`** + Admin SDK no worker (polling).
- Callables: **`engineeringAgentWorkerEnqueueJob`**, **`engineeringAgentWorkerApproveJob`** (`functions/src/index.ts`).
- Regras Firestore: cliente sem acesso direto à coleção.

## Ligação ao fluxo do agente

1. **Gerar comando** (`engineeringAgentGenerateCommand`) grava `lastCommand` na sessão.
2. **`engineeringAgentWorkerEnqueueJob`** com `sessionId` + `workspaceRoot` enfileira o comando no PC.
3. Worker executa localmente; resultado gravado no documento do job.
4. Comandos sensíveis em **`pending_approval`** até **`engineeringAgentWorkerApproveJob`** ou `POST /firebase/job/:id/approve` no worker.

Instruções completas: **`pontocerto-ai-worker/README.md`**.
