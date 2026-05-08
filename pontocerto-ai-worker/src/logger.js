function ts() {
  return new Date().toISOString();
}

export function createLogger() {
  return {
    info: (m, e) => console.log(`[${ts()}] [info] ${m}`, e || ''),
    warn: (m, e) => console.warn(`[${ts()}] [warn] ${m}`, e || ''),
    error: (m, e) => console.error(`[${ts()}] [error] ${m}`, e || ''),
  };
}
