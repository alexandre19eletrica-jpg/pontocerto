import fs from 'fs';
import admin from 'firebase-admin';
import { normalizeRoot, resolveUnderRoot } from './pathGuard.js';
import { execPwshLine } from './powershellHelper.js';

function initFirebase(cfg, log) {
  if (!cfg.serviceAccountPath || !fs.existsSync(cfg.serviceAccountPath)) {
    log.warn('Firebase Admin omitido — fila cloud desativada.');
    return null;
  }
  const raw = fs.readFileSync(cfg.serviceAccountPath, 'utf8');
  const sa = JSON.parse(raw);
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: cfg.firestoreProjectId,
    });
  }
  log.info(`Firebase Admin OK — projeto ${cfg.firestoreProjectId}`);
  return admin.firestore();
}

async function claimJob(db, docRef, log) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const data = snap.data();
    if (!snap.exists || !data) return false;
    if (data.status !== 'queued' || data.approved !== true) return false;
    tx.update(docRef, {
      status: 'running',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      runner: 'pontocerto-ai-worker',
    });
    return true;
  });
}

export async function startFirebaseJobPoller(cfg, log, broadcast) {
  const db = initFirebase(cfg, log);
  if (!db || !cfg.ownerUid) {
    log.warn('WORKER_OWNER_UID ou credencial Firebase ausente — polling parado.');
    return () => {};
  }

  let timer;

  const tick = async () => {
    try {
      const query = db
        .collection('engineering_agent_worker_jobs')
        .where('ownerUid', '==', cfg.ownerUid)
        .where('status', '==', 'queued')
        .orderBy('createdAt', 'asc')
        .limit(5);

      const snap = await query.get();
      for (const doc of snap.docs) {
        const job = doc.data();
        if (!job.approved) continue;

        const ok = await claimJob(db, doc.ref, log);
        if (!ok) continue;

        broadcast?.({ type: 'job_started', jobId: doc.id });

        const projectRoot = normalizeRoot(job.projectRoot || '');
        const cwdRel = String(job.cwdRelative || '.');
        let cwd;
        try {
          cwd = resolveUnderRoot(projectRoot, cwdRel);
        } catch (e) {
          await doc.ref.set(
            {
              status: 'failed',
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
              exitCode: -1,
              stderr: String(e.message),
              errorMessage: 'cwd invalido',
            },
            { merge: true },
          );
          broadcast?.({ type: 'job_failed', jobId: doc.id, error: e.message });
          continue;
        }

        const cmd = String(job.commandLine || '');
        if (job.requiresApproval === true && job.operatorApproved !== true) {
          await doc.ref.set(
            {
              status: 'failed',
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
              errorMessage:
                'Comando exige aprovacao explicita do operador na cloud (engineeringAgentWorkerApproveJob).',
            },
            { merge: true },
          );
          broadcast?.({ type: 'job_failed', jobId: doc.id, error: 'sem_aprovacao' });
          continue;
        }

        try {
          const result = await execPwshLine(cfg, log, cwd, cmd);
          await doc.ref.set(
            {
              status: result.exitCode === 0 ? 'completed' : 'failed',
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
              exitCode: result.exitCode,
              stdout: result.stdout,
              stderr: result.stderr,
            },
            { merge: true },
          );
          broadcast?.({
            type: result.exitCode === 0 ? 'job_completed' : 'job_failed',
            jobId: doc.id,
            exitCode: result.exitCode,
          });
        } catch (err) {
          await doc.ref.set(
            {
              status: 'failed',
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
              errorMessage: String(err.message || err),
            },
            { merge: true },
          );
          broadcast?.({ type: 'job_failed', jobId: doc.id, error: String(err.message || err) });
        }
      }
    } catch (err) {
      log.error('Erro no polling Firestore', err.message || err);
    }
  };

  timer = setInterval(tick, cfg.pollIntervalMs);
  tick();
  log.info(`Polling engineering_agent_worker_jobs a cada ${cfg.pollIntervalMs}ms`);

  return () => clearInterval(timer);
}
