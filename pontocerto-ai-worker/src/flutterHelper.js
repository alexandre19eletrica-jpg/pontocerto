import { execPwshLine } from './powershellHelper.js';

export async function flutterAnalyze(cfg, log, cwd, extra = '') {
  return execPwshLine(cfg, log, cwd, `flutter analyze ${extra}`.trim());
}

export async function flutterBuildWeb(cfg, log, cwd, release = true) {
  const rel = release ? '--release' : '';
  return execPwshLine(cfg, log, cwd, `flutter build web ${rel}`.trim());
}

export async function flutterBuildAppBundle(cfg, log, cwd, extra = '--release') {
  return execPwshLine(cfg, log, cwd, `flutter build appbundle ${extra}`.trim());
}
