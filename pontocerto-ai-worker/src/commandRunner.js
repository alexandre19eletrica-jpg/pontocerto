import { spawn } from 'child_process';

function truncate(s, max) {
  if (!s || s.length <= max) return s || '';
  return `${s.slice(0, max)}\n...[truncado]`;
}

/**
 * Executa comando PowerShell real no Windows (stdout/stderr capturados).
 */
export function runPowerShellCommand(commandLine, cwd, timeoutMs, maxOut, maxErr) {
  return new Promise((resolve, reject) => {
    const args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', commandLine];
    const child = spawn('powershell.exe', args, {
      cwd,
      windowsHide: true,
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';
    const killTimer = setTimeout(() => {
      try {
        child.kill('SIGTERM');
      } catch (_) {}
      reject(new Error(`Timeout apos ${timeoutMs}ms`));
    }, timeoutMs);

    child.stdout?.on('data', (d) => {
      stdout += d.toString();
    });
    child.stderr?.on('data', (d) => {
      stderr += d.toString();
    });

    child.on('error', (err) => {
      clearTimeout(killTimer);
      reject(err);
    });

    child.on('close', (code) => {
      clearTimeout(killTimer);
      resolve({
        exitCode: code ?? -1,
        stdout: truncate(stdout, maxOut),
        stderr: truncate(stderr, maxErr),
      });
    });
  });
}
