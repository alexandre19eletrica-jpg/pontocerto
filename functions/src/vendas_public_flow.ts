/**
 * Fluxo publico de vendas (isolado): lead enviado pela empresa (dados do contador),
 * contador cria acesso do escritorio e depois cadastra a empresa pelo painel.
 */
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as functions from 'firebase-functions/v1';

type VendasEmailDeps = {
  obterConfigEmail: () => {
    sendgridKey: string;
    smtpUser: string;
    smtpAppPassword: string;
    fromEmail: string;
    smtpHost: string;
    smtpPort: number;
    smtpSecure: boolean;
  };
  enviarEmailHtml: (p: {
    toEmail: string;
    subject: string;
    html: string;
    fromEmail: string;
    sendgridKey: string;
    smtpUser: string;
    smtpAppPassword: string;
    smtpHost?: string;
    smtpPort?: number;
    smtpSecure?: boolean;
  }) => Promise<void>;
  escapeHtml: (value: string) => string;
};

const PUBLIC_BASE_URL = 'https://gestao-ponto-certo.com';
const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

function onlyDigits(value: unknown): string {
  return String(value ?? '').replace(/\D/g, '');
}

function asTrimmedString(value: unknown): string {
  return String(value ?? '').trim();
}

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function buildCompanyDisplayCode(params: {cnpj: unknown; companyName: unknown}): string {
  const digits = onlyDigits(params.cnpj).padEnd(5, '0').slice(0, 5);
  const firstWord =
    String(params.companyName ?? '')
      .trim()
      .split(/\s+/)
      .find((item) => item.trim().length > 0)
      ?.toLowerCase()
      .replace(/[^a-z0-9]/g, '') || 'empresa';
  return `comp_${digits}_${firstWord || 'empresa'}`;
}

function syntheticCnpj(prefixDigit: string): string {
  const core = String(Date.now()).padStart(13, '0').slice(-13);
  return `${prefixDigit}${core}`;
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function leadsContabilidadeRef() {
  return admin.firestore().collection('leads_contabilidade');
}

function tokensConviteRef() {
  return admin.firestore().collection('tokens_convite');
}

function accountingOfficeColl() {
  return admin.firestore().collection('accounting_offices');
}

async function logVendasPublic(
  action: string,
  details: Record<string, unknown>,
): Promise<void> {
  await admin.firestore().collection('vendas_public_logs').add({
    action,
    ...details,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function enviarHtmlVendas(
  deps: VendasEmailDeps,
  params: {toEmail: string; subject: string; html: string},
): Promise<void> {
  const c = deps.obterConfigEmail();
  await deps.enviarEmailHtml({
    toEmail: params.toEmail,
    subject: params.subject,
    html: params.html,
    fromEmail: c.fromEmail,
    sendgridKey: c.sendgridKey,
    smtpUser: c.smtpUser,
    smtpAppPassword: c.smtpAppPassword,
    smtpHost: c.smtpHost,
    smtpPort: c.smtpPort,
    smtpSecure: c.smtpSecure,
  });
}

function corsHeaders(res: functions.Response): void {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

async function loadTokenConvite(
  token: string,
): Promise<{snap: admin.firestore.DocumentSnapshot; data: Record<string, unknown>} | null> {
  const snap = await tokensConviteRef().doc(token).get();
  if (!snap.exists) return null;
  return {snap, data: asRecord(snap.data())};
}

async function assertTokenConviteValid(
  token: string,
): Promise<{
  snap: admin.firestore.DocumentSnapshot;
  data: Record<string, unknown>;
  leadId: string;
  emailContador: string;
}> {
  const loaded = await loadTokenConvite(token);
  if (!loaded) {
    throw new functions.https.HttpsError('not-found', 'Convite nao encontrado.');
  }
  const {snap, data} = loaded;
  const usado = data.usado === true;
  const expira = data.expira_em;
  const expMs =
    expira instanceof admin.firestore.Timestamp ? expira.toMillis() : 0;
  if (usado) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Este convite ja foi utilizado.',
    );
  }
  if (!expMs || expMs < Date.now()) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Convite expirado. Solicite um novo link ao cliente.',
    );
  }
  const leadId = asTrimmedString(data.lead_id);
  const emailContador = asTrimmedString(data.email_contador).toLowerCase();
  if (!leadId || !emailContador) {
    throw new functions.https.HttpsError('internal', 'Convite inconsistente.');
  }
  return {snap, data, leadId, emailContador};
}

export function initVendasPublicExports(
  exportsObj: Record<string, unknown>,
  deps: VendasEmailDeps,
): void {
  exportsObj.leadContabilidadeHttp = functions.https.onRequest(async (req, res) => {
    corsHeaders(res);
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ok: false, error: 'method-not-allowed'});
      return;
    }

    try {
      const body = asRecord(
        typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body,
      );
      const nomeEmpresa = asTrimmedString(body.nome_empresa);
      const nomeContabilidade = asTrimmedString(body.nome_contabilidade);
      const emailContador = asTrimmedString(body.email_contador).toLowerCase();
      const emailEmpresaOpt = asTrimmedString(body.email_empresa).toLowerCase();

      if (!nomeEmpresa || !nomeContabilidade || !emailContador) {
        res.status(400).json({ok: false, error: 'campos-obrigatorios'});
        return;
      }
      if (!isValidEmail(emailContador)) {
        res.status(400).json({ok: false, error: 'email-invalido'});
        return;
      }
      if (emailEmpresaOpt && !isValidEmail(emailEmpresaOpt)) {
        res.status(400).json({ok: false, error: 'email-empresa-invalido'});
        return;
      }

      const now = admin.firestore.Timestamp.now();
      const exp = admin.firestore.Timestamp.fromMillis(Date.now() + TOKEN_TTL_MS);
      const token = crypto.randomUUID();
      const leadRef = leadsContabilidadeRef().doc();
      const leadId = leadRef.id;

      const batch = admin.firestore().batch();
      batch.set(leadRef, {
        nome_empresa: nomeEmpresa,
        nome_contabilidade: nomeContabilidade,
        email_contador: emailContador,
        email_empresa: emailEmpresaOpt || '',
        status: 'pendente',
        created_at: now,
        token_convite_id: token,
      });

      batch.set(tokensConviteRef().doc(token), {
        token,
        lead_id: leadId,
        email_contador: emailContador,
        usado: false,
        created_at: now,
        expira_em: exp,
      });

      await batch.commit();

      const conviteUrl = `${PUBLIC_BASE_URL}/convite?token=${encodeURIComponent(token)}`;
      const html = `
        <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
          <p>Ola,</p>
          <p>Um cliente indicou seu escritorio para usar o <strong>Ponto Certo</strong> na emissao de notas e na organizacao da operacao.</p>
          <p><strong>Empresa que enviou os dados:</strong> ${deps.escapeHtml(nomeEmpresa)}<br/>
          <strong>Contabilidade informada no formulario:</strong> ${deps.escapeHtml(nomeContabilidade)}</p>
          <p><strong>Como funciona (ordem correta):</strong></p>
          <ol style="padding-left: 20px;">
            <li style="margin-bottom: 8px;">Use o link abaixo para <strong>criar seu acesso de contador</strong> e o cadastro inicial do escritorio.</li>
            <li style="margin-bottom: 8px;">Em seguida, <strong>entre no sistema</strong> e use a opcao de <strong>cadastrar a empresa</strong> da sua carteira (a mesma empresa acima).</li>
            <li>A empresa <strong>nao</strong> abre conta sozinha nesse fluxo: quem conclui o cadastro da empresa no Ponto Certo e o escritorio.</li>
          </ol>
          <p>Com o sistema em uso:</p>
          <ul>
            <li>A empresa lanca e emite</li>
            <li>Voce acompanha e controla</li>
          </ul>
          <p><a href="${conviteUrl}" style="font-weight:bold;">Criar meu acesso (passo 1)</a></p>
          <p style="color:#64748b;font-size:13px;">Se o link nao abrir, copie e cole no navegador:<br/>${deps.escapeHtml(
            conviteUrl,
          )}</p>
        </div>`;

      try {
        await enviarHtmlVendas(deps, {
          toEmail: emailContador,
          subject: 'Seu cliente quer organizar a emissao de notas',
          html,
        });
      } catch (e) {
        await logVendasPublic('lead_contabilidade_email_falhou', {
          leadId,
          erro: String(e),
        });
      }

      await logVendasPublic('lead_contabilidade_criado', {
        leadId,
        emailContador,
        nomeEmpresa,
      });

      res.status(200).json({ok: true, leadId});
    } catch (e) {
      await logVendasPublic('lead_contabilidade_erro', {erro: String(e)});
      res.status(500).json({ok: false, error: 'internal'});
    }
  });

  exportsObj.vendasPublicGetConvite = functions.https.onCall(async (data) => {
    const token = asTrimmedString(data?.token);
    if (!token) {
      return {ok: true, valid: false, reason: 'missing-token'};
    }
    try {
      const loaded = await loadTokenConvite(token);
      if (!loaded) {
        return {ok: true, valid: false, reason: 'not-found'};
      }
      const d = loaded.data;
      const usado = d.usado === true;
      const expira = d.expira_em;
      const expMs =
        expira instanceof admin.firestore.Timestamp ? expira.toMillis() : 0;
      const expired = !expMs || expMs < Date.now();
      const emailContador = asTrimmedString(d.email_contador);
      const leadId = asTrimmedString(d.lead_id);
      let nomeEmpresa = '';
      if (leadId) {
        const leadSnap = await leadsContabilidadeRef().doc(leadId).get();
        nomeEmpresa = asTrimmedString(asRecord(leadSnap.data()).nome_empresa);
      }
      const valid = !usado && !expired;
      await logVendasPublic('vendas_get_convite', {token: token.slice(0, 8), valid});
      return {
        ok: true,
        valid,
        expired,
        used: usado,
        emailContador,
        nomeEmpresa,
      };
    } catch (e) {
      await logVendasPublic('vendas_get_convite_erro', {erro: String(e)});
      throw e;
    }
  });

  exportsObj.vendasPublicSubmitContadorConvite = functions.https.onCall(async (data) => {
    const token = asTrimmedString(data?.token);
    const nomeContador = asTrimmedString(data?.nome_contador);
    const email = asTrimmedString(data?.email).toLowerCase();
    const senha = String(data?.senha ?? '');
    const confirma = String(data?.confirma_senha ?? '');

    if (!token || !nomeContador || !email || !senha) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Preencha nome, email e senha.',
      );
    }
    if (senha !== confirma) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A confirmacao de senha nao confere.',
      );
    }
    if (senha.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Senha muito curta (minimo 6 caracteres).',
      );
    }

    const {snap: tokenSnap, leadId, emailContador} = await assertTokenConviteValid(token);
    if (email !== emailContador) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Use o mesmo email do convite (email do contador indicado pelo cliente).',
      );
    }

    const leadSnap = await leadsContabilidadeRef().doc(leadId).get();
    const lead = asRecord(leadSnap.data());
    const nomeEmpresaLead = asTrimmedString(lead.nome_empresa);
    const nomeContabilidadeLead = asTrimmedString(lead.nome_contabilidade);

    let userRecord: admin.auth.UserRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password: senha,
        displayName: nomeContador,
        emailVerified: false,
      });
    } catch (err: unknown) {
      const code = (err as {code?: string}).code;
      if (code === 'auth/email-already-exists') {
        throw new functions.https.HttpsError(
          'already-exists',
          'Este email ja possui conta. Entre com login ou use recuperar senha.',
        );
      }
      throw new functions.https.HttpsError('internal', 'Nao foi possivel criar o usuario.');
    }

    const uid = userRecord.uid;
    const officeSyntheticCnpj = syntheticCnpj('9');
    const officeId = `office_vendas_${Date.now()}`;
    const officeName = nomeContabilidadeLead || nomeContador;
    const officeDisplayCode = buildCompanyDisplayCode({
      cnpj: officeSyntheticCnpj,
      companyName: officeName,
    });

    const ts = admin.firestore.FieldValue.serverTimestamp();

    await accountingOfficeColl().doc(officeId).set(
      {
        officeId,
        officeDisplayCode,
        officeName,
        cnpj: officeSyntheticCnpj,
        responsibleName: nomeContador,
        phone: '',
        email,
        address: '',
        city: '',
        state: '',
        billingChoiceDefault: 'office',
        notes: 'Cadastro inicial via fluxo vendas publico (CNPJ a regularizar).',
        source: 'vendas_public_convite',
        active: true,
        platformStatus: 'active',
        linkedCompaniesCount: 0,
        createdAt: ts,
        updatedAt: ts,
      },
      {merge: true},
    );

    await admin.firestore().collection('users').doc(uid).set(
      {
        companyId: officeId,
        companyName: officeName,
        role: 'ACCOUNTANT',
        nome: nomeContador,
        email,
        employeeId: uid,
        officeId,
        officeName,
        officeDisplayCode,
        officeBillingChoiceDefault: 'office',
        mustChangePassword: false,
        createdAt: ts,
        updatedAt: ts,
      },
      {merge: true},
    );

    await admin.auth().setCustomUserClaims(uid, {
      companyId: officeId,
      role: 'ACCOUNTANT',
      employeeId: uid,
      officeId,
    });

    const batch = admin.firestore().batch();
    batch.set(
      tokenSnap.ref,
      {
        usado: true,
        usado_em: ts,
        usado_por_uid: uid,
        updated_at: ts,
      },
      {merge: true},
    );
    batch.set(
      leadSnap.ref,
      {
        status: 'ativado',
        pendencia: 'cadastrar_empresa_no_painel',
        contador_uid: uid,
        contador_office_id: officeId,
        updated_at: ts,
      },
      {merge: true},
    );
    await batch.commit();

    const loginUrl = `${PUBLIC_BASE_URL}/login-contador`;
    const cadastrarEmpresaUrl = `${PUBLIC_BASE_URL}/accountant-register-company`;

    const htmlContadorPos = `
        <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
          <p>Ola, ${deps.escapeHtml(nomeContador)}!</p>
          <p>Seu acesso ao Ponto Certo foi criado. O proximo passo e cadastrar no sistema a empresa que indicou seu escritorio.</p>
          <p><strong>Empresa a cadastrar:</strong> ${deps.escapeHtml(nomeEmpresaLead)}</p>
          <ol style="padding-left: 20px;">
            <li style="margin-bottom: 8px;"><a href="${loginUrl}" style="font-weight:bold;">Entrar no login do contador</a></li>
            <li style="margin-bottom: 8px;">No painel, abra o cadastro de empresa da carteira (fluxo de nova empresa vinculada ao escritorio).</li>
            <li>Cadastre os dados da empresa acima. O cliente nao precisa criar conta sozinho neste fluxo.</li>
          </ol>
          <p>Atalho apos logar: <a href="${cadastrarEmpresaUrl}">${deps.escapeHtml(cadastrarEmpresaUrl)}</a></p>
        </div>`;

    try {
      await enviarHtmlVendas(deps, {
        toEmail: email,
        subject: 'Ponto Certo: proximo passo - cadastre a empresa no painel',
        html: htmlContadorPos,
      });
    } catch (e) {
      await logVendasPublic('vendas_email_contador_pos_convite_falhou', {
        leadId,
        erro: String(e),
      });
    }

    const emailEmpresaDest = asTrimmedString(lead.email_empresa).toLowerCase();
    if (emailEmpresaDest && isValidEmail(emailEmpresaDest)) {
      const htmlEmp = `
        <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
          <p>Ola,</p>
          <p>Sua solicitacao foi enviada ao email do seu contador. Ele vai criar o acesso do escritorio no Ponto Certo e, em seguida, <strong>cadastrar sua empresa</strong> pelo painel do contador.</p>
          <p><strong>Empresa informada:</strong> ${deps.escapeHtml(nomeEmpresaLead)}</p>
          <p>Neste fluxo voce <strong>nao</strong> finaliza o cadastro sozinho no site: quem conclui e o seu escritorio contabil. Quando estiver registrado, o contador orienta o proximo passo.</p>
        </div>`;
      try {
        await enviarHtmlVendas(deps, {
          toEmail: emailEmpresaDest,
          subject: 'Ponto Certo: seu contador vai cadastrar sua empresa',
          html: htmlEmp,
        });
      } catch (e) {
        await logVendasPublic('vendas_email_empresa_aviso_falhou', {
          leadId,
          erro: String(e),
        });
      }
    }

    await logVendasPublic('vendas_contador_convite_concluido', {
      leadId,
      uid,
      officeId,
    });

    return {
      ok: true,
      officeId,
      loginUrl,
      cadastrarEmpresaUrl,
    };
  });
}
