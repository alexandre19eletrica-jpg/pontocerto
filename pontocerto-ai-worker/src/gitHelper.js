import { execPwshLine } from './powershellHelper.js';

export async function gitStatus(cfg, log, cwd) {
  return execPwshLine(cfg, log, cwd, 'git status');
}

export async function gitDiff(cfg, log, cwd, extraArgs = '') {
  const line = extraArgs.trim() ? `git diff ${extraArgs}` : 'git diff';
  return execPwshLine(cfg, log, cwd, line);
}

export async function gitCheckout(cfg, log, cwd, refOrBranch) {
  const safe = refOrBranch.replace(/"/g, '');
  return execPwshLine(cfg, log, cwd, `git checkout ${safe}`);
}
