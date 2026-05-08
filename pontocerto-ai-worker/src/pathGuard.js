import path from 'path';

function ensureTrailingSep(p) {
  const n = path.resolve(p);
  const sep = n.endsWith(path.sep) ? n : n + path.sep;
  return sep;
}

/**
 * Resolve caminho final e garante que fica dentro de authorizedRoot (prefixo, inclui Windows).
 */
export function resolveUnderRoot(authorizedRoot, relativeOrAbsolute) {
  const root = path.resolve(authorizedRoot);
  let candidate;
  if (path.isAbsolute(relativeOrAbsolute)) {
    candidate = path.resolve(relativeOrAbsolute);
  } else {
    candidate = path.resolve(root, relativeOrAbsolute);
  }

  const rootPref = ensureTrailingSep(root);
  const candPref = ensureTrailingSep(candidate);

  if (candidate !== root && !candPref.toLowerCase().startsWith(rootPref.toLowerCase())) {
    throw new Error(`Acesso bloqueado fora do root autorizado.\nroot=${root}\ncandidate=${candidate}`);
  }
  return candidate;
}

export function normalizeRoot(r) {
  return path.resolve(String(r || '').trim());
}
