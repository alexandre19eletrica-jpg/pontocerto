import { gitDiff } from './gitHelper.js';

export async function unifiedDiff(cfg, log, cwd, pathsArg = '') {
  const res = await gitDiff(cfg, log, cwd, `--no-color ${pathsArg}`.trim());
  return res;
}
