# pontocerto-ai-worker

Worker **local** do Agente de Engenharia do Ponto Certo: executa **PowerShell**, **Flutter**, **Firebase CLI**, **Git** e **VS Code** na sua máquina Windows — **não** usa terminal cloud.

## Pasta em `C:\pontocerto-ai-worker`

O projeto está versionado em **`pontocerto-ai-worker`** na raiz do repositório Ponto Certo. Para ficar exatamente em `C:\`:

```powershell
cmd /c mklink /J C:\pontocerto-ai-worker "c:\Users\hp\pontocerto\pontocerto-ai-worker"
```

*(Ajuste o segundo caminho se o seu clone for outro.)*

## Instalação

```powershell
cd C:\pontocerto-ai-worker
copy .env.example .env
# Editar .env: WORKER_HTTP_SECRET, WORKER_OWNER_UID, FIREBASE_SERVICE_ACCOUNT_PATH (opcional)
npm install
npm start
```

Serviços:

- **HTTP**: `http://127.0.0.1:37651` (porta configurável)
- **WebSocket**: `ws://127.0.0.1:37651/ws?token=SEU_SEGREDO`

## Variáveis `.env` (principal)

| Variável | Descrição |
|----------|-----------|
| `WORKER_HTTP_SECRET` | Segredo para header `X-Worker-Secret` e query WS |
| `WORKER_OWNER_UID` | UID Firebase Auth (conta suprema que usa o agente) |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Caminho absoluto para JSON da conta de serviço com Firestore |
| `FIRESTORE_PROJECT_ID` | Ex.: `pontocerto-e1dab` |
| `DEFAULT_PROJECT_ROOT` | Opcional: root quando o cliente não envia `projectRoot` |

## Integração com o backend Ponto Certo

### Callables (deploy Functions necessário)

- **`engineeringAgentWorkerEnqueueJob`** — fila `engineering_agent_worker_jobs`. Use `commandLine` ou `sessionId` (usa `lastCommand` após `engineeringAgentGenerateCommand`). Modo Ponto Certo: `workspaceRoot`; externo: `projectId`.
- **`engineeringAgentWorkerApproveJob`** — aprova job em `pending_approval`.

O worker faz **polling** de `status == 'queued'` e `approved == true`.

### HTTP local

`POST /task` com JSON (header `X-Worker-Secret`). Tipos: ver `src/workerConnector.js`. Comandos de risco exigem `forceApprove: true`.

## Segurança

- Escuta apenas **127.0.0.1**.
- Caminhos confinados ao **`projectRoot`** (anti path traversal).
- Deploy/push/AAB bloqueados sem confirmação explícita (`forceApprove` ou callable `ApproveJob`).

## Comandos rápidos

```powershell
npm install
npm start
```

### Validação (uma linha)

```powershell
cd C:\pontocerto-ai-worker; npm install; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; node -e "fetch('http://127.0.0.1:37651/health').then(r=>r.json()).then(console.log)" 2>$null; npm start
```

*(Após `npm start`, o último `fetch` falha até o servidor estar a correr — use um segundo terminal para `Invoke-RestMethod http://127.0.0.1:37651/health`.)*
