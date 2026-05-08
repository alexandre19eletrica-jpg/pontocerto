import http from 'http';
import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { createExpressApp } from './httpServer.js';
import { attachWebSocket } from './websocketHub.js';
import { startFirebaseJobPoller } from './firebaseJobPoller.js';
import { startWatchHub } from './watchHub.js';

async function main() {
  const cfg = loadConfig();
  const log = createLogger();

  let broadcast = (_payload) => {};
  const app = createExpressApp(cfg, log, (payload) => broadcast(payload));
  const server = http.createServer(app);
  const wsHub = attachWebSocket(server, cfg, log);
  broadcast = wsHub.broadcast;

  server.listen(cfg.httpPort, '127.0.0.1', () => {
    log.info(`HTTP http://127.0.0.1:${cfg.httpPort} | WS ws://127.0.0.1:${cfg.httpPort}/ws?token=***`);
    log.info('Bridge Firestore: coleção engineering_agent_worker_jobs');
  });

  await startFirebaseJobPoller(cfg, log, broadcast);
  startWatchHub(cfg, log, broadcast);
}

main().catch((err) => {
  console.error('[fatal]', err);
  process.exit(1);
});
