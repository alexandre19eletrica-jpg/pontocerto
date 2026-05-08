import { WebSocketServer } from 'ws';

export function attachWebSocket(server, cfg, log) {
  const wss = new WebSocketServer({ server });
  const clients = new Set();

  wss.on('connection', (ws, req) => {
    try {
      const host = req.headers.host || 'localhost';
      const url = new URL(req.url || '/', `http://${host}`);
      const token = url.searchParams.get('token') || '';
      if (!cfg.httpSecret || token !== cfg.httpSecret) {
        log.warn('WS rejeitado — token invalido.');
        ws.close(4401, 'nao autorizado');
        return;
      }
      clients.add(ws);
      ws.send(JSON.stringify({ type: 'hello', message: 'Worker Ponto Certo ligado.', ts: new Date().toISOString() }));
      ws.on('close', () => clients.delete(ws));
    } catch (err) {
      log.error('Erro WS', err.message);
      ws.close();
    }
  });

  function broadcast(obj) {
    const raw = JSON.stringify(obj);
    for (const ws of clients) {
      try {
        if (ws.readyState === 1) ws.send(raw);
      } catch (_) {}
    }
  }

  log.info(`WebSocket em /ws?token=*** (mesmo segredo HTTP)`);
  return { broadcast, wss };
}
