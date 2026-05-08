import { normalizeRoot, resolveUnderRoot } from './pathGuard.js';
import { execPwshLine } from './powershellHelper.js';
import { gitStatus, gitDiff, gitCheckout } from './gitHelper.js';
import { flutterAnalyze, flutterBuildWeb, flutterBuildAppBundle } from './flutterHelper.js';
import { firebaseDeploy } from './firebaseHelper.js';
import { readTextFile, writeTextFile, listDir } from './fileOps.js';
import { unifiedDiff } from './diffGenerator.js';
import { commandNeedsLocalApproval } from './riskyCommands.js';
import { spawn } from 'child_process';

function effectiveRoot(cfg, projectRoot) {
  const pr = projectRoot?.trim();
  if (pr) return normalizeRoot(pr);
  if (cfg.defaultProjectRoot) return normalizeRoot(cfg.defaultProjectRoot);
  throw new Error('projectRoot obrigatorio ou configure DEFAULT_PROJECT_ROOT no .env');
}

/**
 * Executa tarefa estruturada (HTTP). Opcional forceApprove para comandos de risco (uso consciente).
 */
export async function runStructuredTask(cfg, log, body, options = {}) {
  const { forceApprove = false } = options;
  const type = String(body.type || '').trim();
  const projectRoot = effectiveRoot(cfg, body.projectRoot);

  switch (type) {
    case 'exec_powershell': {
      const cmd = String(body.command || '').trim();
      if (!cmd) throw new Error('command obrigatorio');
      if (commandNeedsLocalApproval(cmd) && !forceApprove) {
        throw new Error(
          'Comando potencialmente destrutivo ou deploy — defina forceApprove:true no body depois de confirmar manualmente.',
        );
      }
      const cwdRel = String(body.cwdRelative || '.');
      const cwd = resolveUnderRoot(projectRoot, cwdRel);
      return execPwshLine(cfg, log, cwd, cmd);
    }
    case 'flutter_analyze': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return flutterAnalyze(cfg, log, cwd, String(body.extraArgs || ''));
    }
    case 'flutter_build_web': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return flutterBuildWeb(cfg, log, cwd, body.release !== false);
    }
    case 'flutter_build_appbundle': {
      if (!forceApprove) {
        throw new Error('AAB bloqueado sem forceApprove:true (politica do projeto).');
      }
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return flutterBuildAppBundle(cfg, log, cwd, String(body.extraArgs || '--release'));
    }
    case 'firebase_deploy': {
      if (!forceApprove) {
        throw new Error('firebase deploy bloqueado sem forceApprove:true.');
      }
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return firebaseDeploy(cfg, log, cwd, String(body.only || ''));
    }
    case 'git_status': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return gitStatus(cfg, log, cwd);
    }
    case 'git_diff': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return gitDiff(cfg, log, cwd, String(body.extraArgs || ''));
    }
    case 'git_checkout': {
      const ref = String(body.ref || '').trim();
      if (!ref) throw new Error('ref obrigatorio para git_checkout');
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return gitCheckout(cfg, log, cwd, ref);
    }
    case 'npm_install': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return execPwshLine(cfg, log, cwd, 'npm install');
    }
    case 'npm_run_build': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      const script = String(body.script || 'build');
      return execPwshLine(cfg, log, cwd, `npm run ${script}`);
    }
    case 'read_file': {
      const text = await readTextFile(projectRoot, String(body.relativePath || ''));
      return { exitCode: 0, stdout: text, stderr: '' };
    }
    case 'write_file': {
      await writeTextFile(projectRoot, String(body.relativePath || ''), String(body.content ?? ''));
      return { exitCode: 0, stdout: 'gravado', stderr: '' };
    }
    case 'list_dir': {
      const items = await listDir(projectRoot, String(body.relativeDir || '.'));
      return { exitCode: 0, stdout: JSON.stringify(items, null, 2), stderr: '' };
    }
    case 'diff_unified': {
      const cwd = resolveUnderRoot(projectRoot, body.cwdRelative || '.');
      return unifiedDiff(cfg, log, cwd, String(body.pathsArg || ''));
    }
    case 'vscode_open': {
      const target = resolveUnderRoot(projectRoot, String(body.relativeTarget || '.'));
      const cli = cfg.vscodeCli || 'code';
      spawn(cli, [target], { detached: true, stdio: 'ignore' });
      return { exitCode: 0, stdout: `VS Code aberto em ${target}`, stderr: '' };
    }
    default:
      throw new Error(`Tipo de tarefa desconhecido: ${type}`);
  }
}
