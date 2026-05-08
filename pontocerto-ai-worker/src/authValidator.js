export function assertSecret(cfg, req) {
  const hdr =
    req.headers['x-worker-secret'] ||
    req.headers.authorization?.replace(/^Bearer\s+/i, '') ||
    '';
  const secret = String(hdr).trim();
  if (!cfg.httpSecret || secret !== cfg.httpSecret) {
    const err = new Error('Nao autorizado — verifique X-Worker-Secret ou Authorization Bearer.');
    err.statusCode = 401;
    throw err;
  }
}
