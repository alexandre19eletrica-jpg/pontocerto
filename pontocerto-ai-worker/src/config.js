import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export function loadConfig() {
  dotenv.config({ path: path.join(process.cwd(), '.env') });

  const cfg = {
    httpPort: Number(process.env.WORKER_HTTP_PORT || 37651),
    httpSecret: (process.env.WORKER_HTTP_SECRET || '').trim(),
    ownerUid: (process.env.WORKER_OWNER_UID || '').trim(),
    serviceAccountPath: (process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '').trim(),
    firestoreProjectId: (process.env.FIRESTORE_PROJECT_ID || 'pontocerto-e1dab').trim(),
    pollIntervalMs: Number(process.env.POLL_INTERVAL_MS || 3500),
    commandTimeoutMs: Number(process.env.COMMAND_TIMEOUT_MS || 900000),
    maxStdoutChars: Number(process.env.MAX_STDOUT_CHARS || 400000),
    maxStderrChars: Number(process.env.MAX_STDERR_CHARS || 120000),
    defaultProjectRoot: (process.env.DEFAULT_PROJECT_ROOT || '').trim(),
    vscodeCli: (process.env.VSCODE_CLI || 'code').trim(),
    wsLogBroadcast: (process.env.WS_LOG_BROADCAST || 'true').toLowerCase() === 'true',
    repoRoot: process.cwd(),
  };

  if (!cfg.httpSecret) {
    console.warn('[config] WORKER_HTTP_SECRET vazio — defina no .env antes de expor na rede.');
  }

  if (cfg.serviceAccountPath && !fs.existsSync(cfg.serviceAccountPath)) {
    console.warn('[config] FIREBASE_SERVICE_ACCOUNT_PATH nao encontrado — fila Firestore desativada.');
  }

  return cfg;
}
