import { runPowerShellCommand } from './commandRunner.js';

export async function execPwshLine(cfg, log, cwd, commandLine) {
  log.info(`PowerShell (cwd=${cwd}): ${commandLine.slice(0, 400)}`);
  return runPowerShellCommand(commandLine, cwd, cfg.commandTimeoutMs, cfg.maxStdoutChars, cfg.maxStderrChars);
}
