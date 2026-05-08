import express from 'express';
import cors from 'cors';
import { assertSecret } from './authValidator.js';
import { runStructuredTask } from './taskRunner.js';
import admin from 'firebase-admin';

export function createExpressApp(cfg, log, broadcast) {
  const app = express();
  app.use(cors({ origin: false }));
  app.use(express.json({ limit: '4mb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'pontocerto-ai-worker', lang: 'pt-BR' });
  });

  app.post('/task', async (req, res) => {
    try {
      assertSecret(cfg, req);
      const result = await runStructuredTask(cfg, log, req.body, {
        forceApprove: req.body.forceApprove === true,
      });
      broadcast?.({ type: 'task_result', ok: true, result });
      res.json({ ok: true, result });
    } catch (err) {
      log.error(err.message);
      broadcast?.({ type: 'task_result', ok: false, error: err.message });
      res.status(err.statusCode || 400).json({ ok: false, error: err.message });
    }
  });

  /** Aprovar job Firestore localmente (alternativa ao callable da cloud). */
  app.post('/firebase/job/:id/approve', async (req, res) => {
    try {
      assertSecret(cfg, req);
      if (!admin.apps.length) throw new Error('Firebase Admin nao inicializado');
      const db = admin.firestore();
      const ref = db.collection('engineering_agent_worker_jobs').doc(req.params.id);
      await ref.set(
        {
          approved: true,
          operatorApproved: true,
          status: 'queued',
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          approvedVia: 'local_worker_http',
        },
        { merge: true },
      );
      broadcast?.({ type: 'job_approved', jobId: req.params.id });
      res.json({ ok: true, jobId: req.params.id });
    } catch (err) {
      res.status(400).json({ ok: false, error: err.message });
    }
  });

  return app;
}
