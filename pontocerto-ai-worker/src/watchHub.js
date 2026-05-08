import chokidar from 'chokidar';

/** Observação opcional de pastas (variável WATCH_DIRS separada por `;`). */
export function startWatchHub(cfg, log, broadcast) {
  const raw = process.env.WATCH_DIRS || '';
  const roots = raw
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);
  if (roots.length === 0) {
    return () => {};
  }

  log.info(`chokidar a observar: ${roots.join(', ')}`);
  const watcher = chokidar.watch(roots, {
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 400, pollInterval: 100 },
  });

  const send = (ev, path) => broadcast?.({ type: 'fs_event', ev, path, ts: new Date().toISOString() });

  watcher.on('add', (p) => send('add', p));
  watcher.on('change', (p) => send('change', p));
  watcher.on('unlink', (p) => send('unlink', p));

  return () => watcher.close();
}
