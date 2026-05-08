/**
 * Contrato WorkerConnector (resumo) — usado pelo cliente local ou futura UI.
 *
 * HTTP base: http://127.0.0.1:${WORKER_HTTP_PORT}
 * Header obrigatorio: X-Worker-Secret: ${WORKER_HTTP_SECRET}
 *
 * WebSocket: ws://127.0.0.1:${WORKER_HTTP_PORT}/ws?token=${WORKER_HTTP_SECRET}
 *
 * Filas cloud (Firebase Admin no worker):
 * - Coleção: engineering_agent_worker_jobs
 * - Callables Ponto Certo: engineeringAgentWorkerEnqueueJob, engineeringAgentWorkerApproveJob
 */

export const WorkerConnectorContract = Object.freeze({
  httpPaths: {
    health: '/health',
    task: '/task',
    approveFirebaseJob: '/firebase/job/:id/approve',
  },
  taskTypes: [
    'exec_powershell',
    'flutter_analyze',
    'flutter_build_web',
    'flutter_build_appbundle',
    'firebase_deploy',
    'git_status',
    'git_diff',
    'git_checkout',
    'npm_install',
    'npm_run_build',
    'read_file',
    'write_file',
    'list_dir',
    'diff_unified',
    'vscode_open',
  ],
});
