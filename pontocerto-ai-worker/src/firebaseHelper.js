import { execPwshLine } from './powershellHelper.js';

export async function firebaseDeploy(cfg, log, cwd, onlyTargets) {
  const only = onlyTargets?.trim() ? ` --only ${onlyTargets.trim()}` : '';
  return execPwshLine(cfg, log, cwd, `firebase deploy${only}`);
}
