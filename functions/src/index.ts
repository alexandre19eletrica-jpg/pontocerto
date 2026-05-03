import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as functions from 'firebase-functions/v1';
import sendgridMail from '@sendgrid/mail';
import nodemailer from 'nodemailer';
import { GoogleAuth } from 'google-auth-library';
import { defineString } from 'firebase-functions/params';
import {initVendasPublicExports} from './vendas_public_flow';

if (!admin.apps.length) {
  admin.initializeApp();
}

type AppRole = 'OWNER' | 'MANAGER' | 'ACCOUNTANT' | 'EMPLOYEE';

type Claims = {
  uid: string;
  companyId: string;
  role: AppRole;
  employeeId: string;
};

/** Unica empresa suprema (plataforma). Espelho de `supremePlatformCompanyIds` no app (Dart).
 * Perfis de usuario com este companyId nao podem ser desativados (ativo=false) nem ter delete
 * via regras do Firestore; cancelamento de assinatura Asaas e barrado em companyCancelBillingSubscription.
 */
const SUPREME_PLATFORM_COMPANY_IDS = new Set([
  // Bonfim Alexandre Sousa Santos — unico ID suprema; nao incluir outros.
  // Login e flags comerciais nunca bloqueiam esta empresa (companyAccessState, buildDefaultCommercialSettings, bootstrap).
  'comp_1771754418259',
]);
const DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS = 9790;

function gerarSenhaTemporaria(): string {
  const base = crypto.randomBytes(9).toString('base64url');
  return `${base}A1!`;
}

function normalizarRole(valor: unknown): string {
  return String(valor ?? '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function roleParaFirestore(valor: unknown): AppRole {
  const normalizado = normalizarRole(valor);
  if (normalizado === 'owner' || normalizado === 'dono') return 'OWNER';
  if (normalizado === 'manager' || normalizado === 'gerente') return 'MANAGER';
  if (normalizado === 'accountant' || normalizado === 'contador') return 'ACCOUNTANT';
  return 'EMPLOYEE';
}

function isVisibleEmployeeRole(valor: unknown): boolean {
  const normalizado = normalizarRole(valor);
  return (
    normalizado === 'employee' ||
    normalizado === 'manager' ||
    normalizado === 'accountant' ||
    normalizado === 'unknown'
  );
}

type InviteEmailConfig = {
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  fromEmail: string;
  apkUrl: string;
  appDistributionAppId: string;
};

type AssistantConfig = {
  apiKey: string;
  model: string;
};

type AssistantRuntimeConfig = AssistantConfig & {
  source: 'company' | 'platform' | 'missing';
  keyPreview: string;
  updatedByName?: string;
  updatedAtIso?: string;
};

type AsaasConfig = {
  apiKey: string;
  environment: 'sandbox' | 'production';
  baseUrl: string;
};

const MAIL_FROM = defineString('MAIL_FROM');
const SMTP_USER = defineString('SMTP_USER');
const SMTP_APP_PASSWORD = defineString('SMTP_APP_PASSWORD');
const SMTP_HOST = defineString('SMTP_HOST');
const SMTP_PORT = defineString('SMTP_PORT');
const SMTP_SECURE = defineString('SMTP_SECURE');
const SENDGRID_KEY = defineString('SENDGRID_KEY');
const APP_APK_URL = defineString('APP_APK_URL');
const APPDISTRIBUTION_APP_ID = defineString('APPDISTRIBUTION_APP_ID');
const ASAAS_WEBHOOK_TOKEN = defineString('ASAAS_WEBHOOK_TOKEN');
const ASAAS_API_KEY = defineString('ASAAS_API_KEY');
const ASAAS_ENVIRONMENT = defineString('ASAAS_ENVIRONMENT');
const DEFAULT_PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=br.com.alexandresousa.pontocerto';
const DEFAULT_REAL_ENVIRONMENT_URL = DEFAULT_PLAY_STORE_URL;

function obterConfigEmail(): InviteEmailConfig {
  const configuredApkUrl = APP_APK_URL.value().trim();
  return {
    sendgridKey: SENDGRID_KEY.value().trim(),
    smtpUser: SMTP_USER.value().trim(),
    smtpAppPassword: SMTP_APP_PASSWORD.value().trim(),
    smtpHost: SMTP_HOST.value().trim(),
    smtpPort: Number(SMTP_PORT.value().trim() || '587') || 587,
    smtpSecure: ['1', 'true', 'yes', 'on'].includes(
      SMTP_SECURE.value().trim().toLowerCase(),
    ),
    fromEmail: MAIL_FROM.value().trim(),
    apkUrl: configuredApkUrl || DEFAULT_PLAY_STORE_URL,
    appDistributionAppId:
      APPDISTRIBUTION_APP_ID.value().trim() ||
      '1:1074663509241:android:882c17b485b01c7aa06628',
  };
}

function missingInviteConfig(cfg: InviteEmailConfig): string[] {
  const missing: string[] = [];
  const smtpConfigured = !!cfg.smtpUser || !!cfg.smtpAppPassword;
  const sendgridConfigured = !!cfg.sendgridKey;

  if (smtpConfigured) {
    if (!cfg.smtpHost) missing.push('smtp.host');
    if (!cfg.smtpUser) missing.push('smtp.user');
    if (!cfg.smtpAppPassword) missing.push('smtp.app_password');
  } else if (sendgridConfigured) {
    if (!cfg.sendgridKey) missing.push('sendgrid.key');
  } else {
    // Padrao recomendado: Gmail SMTP.
    missing.push('smtp.user', 'smtp.app_password');
  }

  if (!cfg.fromEmail) missing.push('mail.from');
  return missing;
}

function obterConfigAsaas(): AsaasConfig {
  const apiKey = ASAAS_API_KEY.value().trim();
  const environmentRaw = ASAAS_ENVIRONMENT.value().trim().toLowerCase();
  const environment: 'sandbox' | 'production' =
    environmentRaw === 'production' || environmentRaw === 'prod'
      ? 'production'
      : 'sandbox';
  const baseUrl =
    environment === 'production'
      ? 'https://api.asaas.com/v3'
      : 'https://api-sandbox.asaas.com/v3';
  return { apiKey, environment, baseUrl };
}

function obterConfigFocusPlatform(): {apiToken: string; environment: string} {
  const environment =
    String(process.env.FOCUS_DEFAULT_ENVIRONMENT ?? '').trim().toLowerCase() ||
    'homologacao';
  return {
    apiToken: String(process.env.FOCUS_API_TOKEN ?? '').trim(),
    environment,
  };
}

function assertAsaasConfigured(): AsaasConfig {
  const cfg = obterConfigAsaas();
  if (!cfg.apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'ASAAS_API_KEY nao configurada nas Functions.',
    );
  }
  return cfg;
}

function obterConfigAssistant(): AssistantConfig {
  return {
    apiKey: String(process.env.OPENAI_API_KEY ?? '').trim(),
    model: String(process.env.OPENAI_MODEL ?? '').trim() || 'gpt-4.1-mini',
  };
}

function assistantSecretRef(companyId: string): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('assistant_secure').doc(companyId);
}

async function obterConfigAssistantRuntime(companyId: string): Promise<AssistantRuntimeConfig> {
  const platformCfg = obterConfigAssistant();
  const snap = await assistantSecretRef(companyId).get();
  const data = asRecord(snap.data());
  const companyApiKey = asTrimmedString(data.apiKey);
  const companyModel = asTrimmedString(data.model);
  const updatedAt = data.updatedAt;
  const updatedAtIso =
    updatedAt instanceof admin.firestore.Timestamp ? updatedAt.toDate().toISOString() : undefined;
  const updatedByName = asTrimmedString(data.updatedByName);

  if (companyApiKey) {
    return {
      apiKey: companyApiKey,
      model: companyModel || platformCfg.model,
      source: 'company',
      keyPreview: maskSecret(companyApiKey),
      updatedByName,
      updatedAtIso,
    };
  }

  if (platformCfg.apiKey) {
    return {
      ...platformCfg,
      source: 'platform',
      keyPreview: '',
      updatedByName,
      updatedAtIso,
    };
  }

  return {
    ...platformCfg,
    source: 'missing',
    keyPreview: '',
    updatedByName,
    updatedAtIso,
  };
}

function missingAssistantConfig(cfg: AssistantConfig): string[] {
  const missing: string[] = [];
  if (!cfg.apiKey) missing.push('OPENAI_API_KEY da empresa ou da plataforma');
  return missing;
}

function platformAdminEmails(): string[] {
  return String(process.env.PLATFORM_ADMIN_EMAILS ?? '')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function isSupremePlatformCompany(companyId: string): boolean {
  return SUPREME_PLATFORM_COMPANY_IDS.has(companyId.trim());
}

async function addTesterToFirebaseAppDistribution(params: {
  email: string;
  appId: string;
}): Promise<void> {
  const appId = params.appId.trim();
  if (!appId) return;

  const appIdParts = appId.split(':');
  if (appIdParts.length < 2) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'appdistribution.app_id invalido.',
    );
  }

  const projectNumber = appIdParts[1];
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const client = await auth.getClient();

  const url = `https://firebaseappdistribution.googleapis.com/v1/projects/${projectNumber}/apps/${encodeURIComponent(
    appId,
  )}/testers:batchAdd`;

  const res = await client.request({
    url,
    method: 'POST',
    data: {
      emails: [params.email],
    },
  });

  if (res.status < 200 || res.status >= 300) {
    throw new functions.https.HttpsError(
      'internal',
      'Falha ao adicionar tester no App Distribution.',
    );
  }
}

function assertAuth(context: functions.https.CallableContext): { uid: string; token: admin.auth.DecodedIdToken } {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuario nao autenticado.');
  }
  return { uid: context.auth.uid, token: context.auth.token };
}

function assertClaims(context: functions.https.CallableContext): Claims {
  const { uid, token } = assertAuth(context);
  const companyId = String(token.companyId ?? '').trim();
  const role = roleParaFirestore(token.role);
  const employeeId = String(token.employeeId ?? '').trim();

  if (!companyId || !employeeId || !token.role) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Custom claims ausentes. Execute authSyncClaims antes de usar esta operacao.',
    );
  }

  return { uid, companyId, role, employeeId };
}

function assertRole(claims: Claims, allowed: AppRole[]): void {
  if (!allowed.includes(claims.role)) {
    throw new functions.https.HttpsError('permission-denied', 'Perfil sem permissao para esta acao.');
  }
}

function assertSupremePlatformAccess(claims: Claims): void {
  if (claims.role !== 'OWNER' || !isSupremePlatformCompany(claims.companyId)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Apenas a empresa suprema da plataforma pode usar esta operacao.',
    );
  }
}

function assertObservabilityAccess(claims: Claims): void {
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
}

function assertCompany(companyId: string, claims: Claims): void {
  if (companyId !== claims.companyId) {
    throw new functions.https.HttpsError('permission-denied', 'Acesso cross-company bloqueado.');
  }
}

function parsePositiveInt(valor: unknown, nomeCampo: string): number {
  const n = Number(valor);
  if (!Number.isInteger(n) || n <= 0) {
    throw new functions.https.HttpsError('invalid-argument', `${nomeCampo} invalido.`);
  }
  return n;
}

function parseNonNegativeInt(valor: unknown, nomeCampo: string): number {
  const n = Number(valor);
  if (!Number.isInteger(n) || n < 0) {
    throw new functions.https.HttpsError('invalid-argument', `${nomeCampo} invalido.`);
  }
  return n;
}

function parseOptionalDate(valor: unknown, nomeCampo: string): admin.firestore.Timestamp | null {
  if (valor == null || String(valor).trim() == '') return null;
  const asDate = valor instanceof Date ? valor : new Date(String(valor));
  if (Number.isNaN(asDate.getTime())) {
    throw new functions.https.HttpsError('invalid-argument', `${nomeCampo} invalido.`);
  }
  return admin.firestore.Timestamp.fromDate(asDate);
}

function parseOptionalBoolean(value: unknown, fieldName: string): boolean | null {
  if (value == null || String(value).trim() == '') return null;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'sim', 'yes'].includes(normalized)) return true;
  if (['false', '0', 'nao', 'não', 'no'].includes(normalized)) return false;
  throw new functions.https.HttpsError('invalid-argument', `${fieldName} invalido.`);
}

function normalizePaymentType(
  explicitValue: unknown,
  fallbackCompensationType?: unknown,
): string {
  const explicit = asTrimmedString(explicitValue).toUpperCase();
  if (['DAILY', 'WEEKLY', 'MONTHLY', 'COMMISSION'].includes(explicit)) {
    return explicit;
  }

  const fallback = asTrimmedString(fallbackCompensationType).toUpperCase();
  if (['DAILY', 'WEEKLY', 'MONTHLY', 'COMMISSION'].includes(fallback)) {
    return fallback;
  }

  return 'MONTHLY';
}

function paymentLaunchReferenceLabel(data: Record<string, unknown>): string {
  const paidAt = data.paidAt;
  const createdAt = data.createdAt;
  const dueDate = data.dueDate;
  const timestampValue =
    paidAt instanceof admin.firestore.Timestamp
      ? paidAt
      : createdAt instanceof admin.firestore.Timestamp
          ? createdAt
          : dueDate instanceof admin.firestore.Timestamp
              ? dueDate
              : null;
  if (timestampValue == null) {
    return 'data nao registrada';
  }
  return timestampValue.toDate().toISOString().slice(0, 10);
}

async function carregarUsuario(uid: string): Promise<FirebaseFirestore.DocumentData> {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Perfil do usuario nao encontrado.');
  }
  return snap.data() ?? {};
}

async function carregarUsuarioMesmoTenant(uid: string, claims: Claims): Promise<FirebaseFirestore.DocumentData> {
  const user = await carregarUsuario(uid);
  const companyId = String(user.companyId ?? '').trim();
  if (!companyId || companyId !== claims.companyId) {
    throw new functions.https.HttpsError('permission-denied', 'Usuario de outra empresa.');
  }
  return user;
}

async function carregarOwnerDaEmpresa(companyId: string): Promise<Record<string, unknown>> {
  const snap = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', companyId)
    .where('role', '==', 'OWNER')
    .limit(1)
    .get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Owner da empresa nao encontrado.');
  }
  return asRecord(snap.docs[0].data());
}

async function assertOperatorFromProfile(
  context: functions.https.CallableContext,
): Promise<Claims> {
  const { uid, token } = assertAuth(context);
  const profile = await carregarUsuario(uid);
  const companyId = String(token.companyId ?? profile.companyId ?? '').trim();
  const role = roleParaFirestore(token.role ?? profile.role);
  const employeeId = String(token.employeeId ?? profile.employeeId ?? uid).trim();

  const claims: Claims = { uid, companyId, role, employeeId };
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
  return claims;
}

async function assertNotDemoReadOnly(claims: Claims): Promise<void> {
  const profile = await carregarUsuario(claims.uid);
  if (profile.demoReadOnly === true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Acesso demo disponivel apenas para leitura.',
    );
  }
}

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function asTrimmedString(value: unknown): string {
  return String(value ?? '').trim();
}

function asFocusDecimal(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const text = asTrimmedString(value);
  if (!text) return fallback;
  const normalized = text.replace(/\./g, '').replace(',', '.');
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asUpperStatus(value: unknown, fallback = 'EMITTED'): string {
  const normalized = asTrimmedString(value).toUpperCase();
  return normalized || fallback;
}

function accountantPermissions(settingsData: Record<string, unknown>): Record<string, unknown> {
  return asRecord(settingsData.accountantPermissions);
}

function accountantCanManageFiscalInvoices(settingsData: Record<string, unknown>): boolean {
  // Contador vinculado: emissao/gestao fiscal nao fica bloqueada por allowIssueServiceInvoices.
  // Mantem-se leitura do objeto (compat/auditoria) sem efeito na decisao.
  void accountantPermissions(settingsData);
  return true;
}

function assertCanOperateFiscalInvoices(params: {
  claims: Claims;
  settingsData: Record<string, unknown>;
}): void {
  if (params.claims.role === 'ACCOUNTANT' && !accountantCanManageFiscalInvoices(params.settingsData)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'O contador desta empresa esta em modo somente leitura para emissao fiscal.',
    );
  }
}

function assistantSettings(settingsData: Record<string, unknown>): Record<string, unknown> {
  return asRecord(settingsData.assistantSettings);
}

function assistantUsage(settingsData: Record<string, unknown>): Record<string, unknown> {
  return asRecord(settingsData.assistantUsage);
}

function currentAssistantPeriodKey(date = new Date()): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

function assistantRequestLimit(settingsData: Record<string, unknown>): number {
  const settings = assistantSettings(settingsData);
  const raw = Number(settings.monthlyRequestLimit ?? 200);
  if (!Number.isFinite(raw) || raw < 0) return 200;
  return Math.trunc(raw);
}

function assistantEnabledForRole(
  settingsData: Record<string, unknown>,
  role: AppRole,
): boolean {
  const settings = assistantSettings(settingsData);
  if (settings.enabled === false) return false;
  if (role === 'EMPLOYEE') return settings.allowEmployeeAccess !== false;
  if (role === 'ACCOUNTANT') return settings.allowAccountantAccess !== false;
  if (role === 'MANAGER') return settings.allowManagerAccess !== false;
  return true;
}

function assertCanUseAssistant(params: {
  claims: Claims;
  settingsData: Record<string, unknown>;
}): void {
  if (!assistantEnabledForRole(params.settingsData, params.claims.role)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'O Assistente Inteligente nao esta liberado para este perfil nesta empresa.',
    );
  }

  const periodKey = currentAssistantPeriodKey();
  const usage = assistantUsage(params.settingsData);
  const currentPeriodUsage =
    asTrimmedString(usage.periodKey) === periodKey ? Number(usage.requestCount ?? 0) : 0;
  const requestLimit = assistantRequestLimit(params.settingsData);
  const blockWhenLimitReached =
    assistantSettings(params.settingsData).blockWhenLimitReached !== false;

  if (
    blockWhenLimitReached &&
    requestLimit > 0 &&
    Number.isFinite(currentPeriodUsage) &&
    currentPeriodUsage >= requestLimit
  ) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'A franquia mensal do assistente foi atingida para esta empresa.',
    );
  }
}

const ASSISTANT_MIN_INTERVAL_MS = 1500;
const ASSISTANT_BURST_WINDOW_MS = 60_000;
const ASSISTANT_BURST_MAX_REQUESTS = 20;

async function reserveAssistantBurstQuota(claims: Claims): Promise<void> {
  const quotaRef = admin
    .firestore()
    .collection('assistant_runtime_quota')
    .doc(`${claims.companyId}_${claims.uid}`);
  const now = Date.now();

  await admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(quotaRef);
    const data = asRecord(snap.data());
    const lastRequestAtMs = Number(data.lastRequestAtMs ?? 0);
    const currentWindowStartMs = Number(data.windowStartMs ?? 0);
    const currentRequestCount = Number(data.requestCount ?? 0);

    if (Number.isFinite(lastRequestAtMs) && lastRequestAtMs > 0) {
      const elapsedMs = now - lastRequestAtMs;
      if (elapsedMs >= 0 && elapsedMs < ASSISTANT_MIN_INTERVAL_MS) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Aguarde um instante antes de enviar outra mensagem ao assistente.',
        );
      }
    }

    const windowStillActive =
      Number.isFinite(currentWindowStartMs) &&
      currentWindowStartMs > 0 &&
      now - currentWindowStartMs < ASSISTANT_BURST_WINDOW_MS;
    const nextWindowStartMs = windowStillActive ? currentWindowStartMs : now;
    const nextRequestCount = windowStillActive
      ? Math.max(0, Math.trunc(currentRequestCount)) + 1
      : 1;

    if (nextRequestCount > ASSISTANT_BURST_MAX_REQUESTS) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Muitas mensagens em pouco tempo. Aguarde um minuto e tente novamente.',
      );
    }

    transaction.set(
      quotaRef,
      {
        companyId: claims.companyId,
        uid: claims.uid,
        role: claims.role,
        windowStartMs: nextWindowStartMs,
        requestCount: nextRequestCount,
        lastRequestAtMs: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

function commercialSettings(settingsData: Record<string, unknown>): Record<string, unknown> {
  return asRecord(settingsData.commercialSettings);
}

/**
 * Firestore rejeita `undefined`. Remove chaves indefinidas (recursivo), preservando
 * Timestamp / GeoPoint / DocumentReference / FieldValue e valores primitivos.
 */
function omitUndefinedForFirestore(value: unknown): unknown {
  if (value === undefined) {
    return undefined;
  }
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value;
  }
  if (value instanceof admin.firestore.GeoPoint) {
    return value;
  }
  if (value instanceof admin.firestore.DocumentReference) {
    return value;
  }
  if (
    typeof admin.firestore.FieldValue !== 'undefined' &&
    value instanceof admin.firestore.FieldValue
  ) {
    return value;
  }
  if (Array.isArray(value)) {
    return value
      .map((entry) => omitUndefinedForFirestore(entry))
      .filter((entry) => entry !== undefined);
  }
  if (typeof value === 'object' && value !== null) {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (v === undefined) continue;
      const nv = omitUndefinedForFirestore(v);
      if (nv !== undefined) {
        out[k] = nv;
      }
    }
    return out;
  }
  return value;
}

function publicSalesConfigRef(): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('platform_public').doc('sales_page');
}

function demoAccessConfigRef(): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('platform_public').doc('demo_access');
}

function demoPublicAccessRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('demo_public_accesses');
}

function buildDefaultPublicSalesConfig(
  current: Record<string, unknown>,
): Record<string, unknown> {
  const planSolo = asRecord(current.planSolo);
  const planEquipe = asRecord(current.planEquipe);
  const additionalAccess = asRecord(current.additionalAccess);
  return {
    enabled: current.enabled !== false,
    updatedAt: current.updatedAt ?? null,
    planSolo: {
      code: asTrimmedString(planSolo.code) || 'solo',
      title: asTrimmedString(planSolo.title) || 'Plano Solo',
      priceLabel: 'R$ 97,90/mes',
      priceCents: 9790,
      implantationLabel: 'Teste real gratuito por 30 dias, com operacao administrativa e fiscal organizadas desde o primeiro acesso.',
      implementationFeeCents: 0,
      checkoutUrl:
        asTrimmedString(planSolo.checkoutUrl) ||
        'https://www.asaas.com/c/zl74djk2gu2sc88p',
    },
    planEquipe: {
      code: asTrimmedString(planEquipe.code) || 'equipe',
      title: asTrimmedString(planEquipe.title) || 'Plano Equipe',
      priceLabel: 'R$ 97,90/mes',
      priceCents: 9790,
      implantationLabel: 'Teste real gratuito por 30 dias. A entrada pelo web alinha empresa e escritorio no mesmo fluxo operacional.',
      implementationFeeCents: 0,
      checkoutUrl:
        asTrimmedString(planEquipe.checkoutUrl) ||
        'https://www.asaas.com/c/twi5txqg1lcqq7gd',
    },
    additionalAccess: {
      code: asTrimmedString(additionalAccess.code) || 'app_play_store_access',
      title:
        asTrimmedString(additionalAccess.title) ||
        'Acesso app Play Store para funcionario',
      priceLabel: 'R$ 19,90/mes',
      priceCents: 1990,
      implantationLabel: 'Tambem entra no teste real de 30 dias quando a empresa estiver ativa',
      implementationFeeCents: 0,
      checkoutUrl: asTrimmedString(additionalAccess.checkoutUrl),
    },
    // Trecho exibido no <head> do app web (codigo de base do Meta Pixel, etc).
    metaPixelHeadSnippet: asTrimmedString(current.metaPixelHeadSnippet) || '',
  };
}

function hashPublicToken(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

/** ID de documento em platform_public/demo_access: deduplica visitas do mesmo IP + assinatura leve do dispositivo. */
function buildPublicDemoAccessDedupeDocId(params: {
  ipHash: string;
  userAgent: string;
  deviceType: string;
  language: string;
  screenWidth: number;
  screenHeight: number;
}): string {
  const uaShort = hashPublicToken(asTrimmedString(params.userAgent)).slice(0, 20);
  const seed = [
    params.ipHash || 'na',
    sanitizeMarketingKey(params.deviceType),
    String(Number(params.screenWidth) || 0),
    String(Number(params.screenHeight) || 0),
    asTrimmedString(params.language).slice(0, 16),
    uaShort,
  ].join('|');
  return `dv1_${hashPublicToken(seed).slice(0, 48)}`;
}

function firestoreCreatedMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (
    value &&
    typeof value === 'object' &&
    typeof (value as {toMillis?: () => number}).toMillis === 'function'
  ) {
    try {
      return (value as {toMillis: () => number}).toMillis();
    } catch (_) {
      return Number.MAX_SAFE_INTEGER;
    }
  }
  return Number.MAX_SAFE_INTEGER;
}

function generatePublicToken(): string {
  return crypto.randomBytes(24).toString('base64url');
}

function salesOnboardingRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('sales_onboarding_requests');
}

function salesLeadRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('sales_public_leads');
}

/** Evita indice composto customerEmail + planCode em leads publicos. */
async function findSalesLeadDocByCustomerEmailAndPlan(
  customerEmail: string,
  planCode: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const normalized = customerEmail.trim().toLowerCase();
  if (!normalized) return null;
  const wantPlan = planCode.trim().toLowerCase();
  const snap = await salesLeadRef()
    .where('customerEmail', '==', normalized)
    .limit(50)
    .get();
  return (
    snap.docs.find(
      (doc) =>
        asTrimmedString(asRecord(doc.data()).planCode).toLowerCase() === wantPlan,
    ) ?? null
  );
}

/** Evita indice composto em onboarding publico (customerEmail + planCode). */
async function findSalesOnboardingDocByRecipientEmailAndPlan(
  recipientEmail: string,
  planCode: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const normalized = recipientEmail.trim().toLowerCase();
  if (!normalized) return null;
  const wantPlan = planCode.trim().toLowerCase();
  const snap = await salesOnboardingRef()
    .where('customerEmail', '==', normalized)
    .limit(80)
    .get();
  return (
    snap.docs.find(
      (doc) =>
        asTrimmedString(asRecord(doc.data()).planCode).toLowerCase() === wantPlan,
    ) ?? null
  );
}

function employeeTesterLeadRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('employee_tester_leads');
}

function trialInviteRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('trial_invites');
}

function accountingOfficeRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('accounting_offices');
}

function accountingOfficeInviteRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('accounting_office_invites');
}

type TrialInvite = {
  companyEmail: string;
  accountantEmail: string;
  tokenHash: string;
  tokenIssuedAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  tokenExpiresAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  status: 'issued' | 'used' | 'expired' | 'revoked' | 'deleted';
  usedAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp | null;
  usedCompanyId?: string;
  /** Quando o convite 30d foi concluido pelo cadastro do escritorio (contador). */
  usedOfficeId?: string;
  /** Opcional, em convites 30d emitidos pela plataforma. */
  accountantName?: string;
  issuedByUid?: string;
  issuedByName?: string;
  notes?: string;
  companyName?: string;
  /** 14 digitos, sem formatacao */
  companyCnpj?: string;
  /** Texto livre ex.: 26/02/2022 */
  companyOpenedAt?: string;
  deletedAt?: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp | null;
  deletedByUid?: string;
  deletedByName?: string;
};

const PUBLIC_EMPLOYEE_TESTER_COMPANY_ID = 'public_employee_testers';
const PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME = 'Comunidade de testes Ponto Certo';
const PUBLIC_DEMO_OWNER_UID = 'public_demo_owner';
const PUBLIC_DEMO_ACCOUNTANT_UID = 'public_demo_accountant';
const PUBLIC_DEMO_COMPANY_ID = 'public_demo_workspace';
const PUBLIC_DEMO_COMPANY_NAME = 'Ponto Certo';
const PUBLIC_DEMO_OFFICE_ID = 'public_demo_office';
const PUBLIC_DEMO_OFFICE_NAME = 'Escritorio Ponto Certo';

type PublicDemoProfile = 'company' | 'accountant';

function normalizePublicDemoProfile(value: unknown): PublicDemoProfile {
  return asTrimmedString(value).toLowerCase() === 'accountant'
    ? 'accountant'
    : 'company';
}

function buildDefaultDemoAccessConfig(current: Record<string, unknown>): Record<string, unknown> {
  return {
    enabled: current.enabled !== false,
    ownerUid: PUBLIC_DEMO_OWNER_UID,
    accountantUid: PUBLIC_DEMO_ACCOUNTANT_UID,
    ownerCompanyId: PUBLIC_DEMO_COMPANY_ID,
    accountantCompanyId: PUBLIC_DEMO_COMPANY_ID,
    ownerDisplayName:
      asTrimmedString(current.ownerDisplayName) || PUBLIC_DEMO_COMPANY_NAME,
    accountantDisplayName:
      asTrimmedString(current.accountantDisplayName) || PUBLIC_DEMO_OFFICE_NAME,
  };
}

function buildLightweightTrialCommercialSettings(params: {
  companyId: string;
  plan: string;
  businessTier: string;
  monthlyPriceCents: number;
  seatsIncluded: number;
  platformNote: string;
}) {
  const graceUntil = admin.firestore.Timestamp.fromMillis(
    Date.now() + 30 * 24 * 60 * 60 * 1000,
  );
  return buildDefaultCommercialSettings({
    companyId: params.companyId,
    commercialSettings: {
      plan: params.plan,
      businessTier: params.businessTier,
      lifecycleStatus: 'trial',
      billingStatus: 'trialing',
      allowLogin: true,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired: false,
      activationStatus: 'released',
      billingIntegration: {
        provider: 'manual',
        accessManagedByGateway: true,
        customerId: '',
        subscriptionId: '',
        paymentLinkUrl: '',
        checkoutUrl: '',
        externalReference: params.companyId,
        status: 'trialing',
        graceDays: 30,
        graceUntil,
        webhookReady: false,
      },
      baseSystemPriceCents: params.monthlyPriceCents,
      monthlyPriceCents: params.monthlyPriceCents,
      seatsIncluded: params.seatsIncluded,
      contractedAppUsers: params.seatsIncluded,
      pricingModel: 'trial_access',
      platformNote: params.platformNote,
    },
  });
}

function readPublicRequestMetadata(context: unknown): {
  ipHash: string;
  userAgent: string;
} {
  const rawRequest = asRecord((context as {rawRequest?: unknown})?.rawRequest);
  const headers = asRecord(rawRequest.headers);
  const forwardedFor = asTrimmedString(headers['x-forwarded-for']);
  const ipRaw =
    forwardedFor.split(',').map((item) => item.trim()).find((item) => item) ||
    asTrimmedString(rawRequest.ip) ||
    'unknown';
  const userAgent = asTrimmedString(headers['user-agent']);
  return {
    ipHash: hashPublicToken(ipRaw),
    userAgent,
  };
}

async function ensurePublicDemoUser(params: {
  uid: string;
  companyId: string;
  role: AppRole;
  displayName: string;
  demoProfile: PublicDemoProfile;
}): Promise<void> {
  const userRef = admin.firestore().collection('users').doc(params.uid);
  const companySnap = await admin
    .firestore()
    .collection('company_settings')
    .doc(params.companyId)
    .get();
  if (!companySnap.exists) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Company demo ${params.companyId} nao encontrada para o perfil ${params.demoProfile}.`,
    );
  }
  const companySettings = asRecord(companySnap.data());
  const companyData = asRecord(companySettings.companyData);
  const companyName =
    asTrimmedString(companyData.nomeFantasia) ||
    asTrimmedString(companyData.razaoSocial) ||
    params.displayName;

  await userRef.set(
    {
      uid: params.uid,
      companyId: params.companyId,
      currentCompanyId: params.companyId,
      role: params.role,
      nome: params.displayName,
      email: `${params.uid}@demo.pontocerto.local`,
      ativo: true,
      companyName,
      companyData,
      demoReadOnly: true,
      demoProfile: params.demoProfile,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function ensurePublicDemoAuthUser(params: {
  uid: string;
  email: string;
  displayName: string;
}): Promise<string> {
  const emailRaw = params.email.trim();
  const desiredEmail = emailRaw.toLowerCase();
  const displayName = params.displayName;

  try {
    const user = await admin.auth().getUser(params.uid);
    const currentEmail = asTrimmedString(user.email).toLowerCase();
    if (currentEmail !== desiredEmail) {
      try {
        await admin.auth().updateUser(user.uid, {
          email: emailRaw,
          displayName,
          disabled: false,
          emailVerified: true,
        });
      } catch (error: unknown) {
        const typed = error as {code?: string};
        if (typed.code === 'auth/email-already-exists') {
          const holder = await admin.auth().getUserByEmail(emailRaw);
          await admin.auth().updateUser(holder.uid, {
            displayName,
            disabled: false,
            emailVerified: true,
          });
          functions.logger.warn('demo_auth_email_holder', {
            canonicalUid: params.uid,
            holderUid: holder.uid,
          });
          return holder.uid;
        }
        throw error;
      }
      return params.uid;
    }

    await admin.auth().updateUser(user.uid, {
      displayName,
      disabled: false,
      emailVerified: true,
    });
    return user.uid;
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    const byEmail = await admin.auth().getUserByEmail(emailRaw);
    await admin.auth().updateUser(byEmail.uid, {
      displayName,
      disabled: false,
      emailVerified: true,
    });
    if (byEmail.uid !== params.uid) {
      functions.logger.warn('demo_auth_uid_mismatch_existing_email', {
        canonicalUid: params.uid,
        actualUid: byEmail.uid,
      });
    }
    return byEmail.uid;
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    const created = await admin.auth().createUser({
      uid: params.uid,
      email: emailRaw,
      displayName,
      emailVerified: true,
      disabled: false,
    });
    return created.uid;
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code === 'auth/email-already-exists') {
      const holder = await admin.auth().getUserByEmail(emailRaw);
      await admin.auth().updateUser(holder.uid, {
        displayName,
        disabled: false,
        emailVerified: true,
      });
      functions.logger.warn('demo_auth_create_email_collision', {
        canonicalUid: params.uid,
        holderUid: holder.uid,
      });
      return holder.uid;
    }
    if (typed.code === 'auth/uid-already-exists') {
      const u = await admin.auth().getUser(params.uid);
      await admin.auth().updateUser(u.uid, {
        displayName,
        disabled: false,
        emailVerified: true,
      });
      return u.uid;
    }
    throw error;
  }
}

async function ensurePublicDemoAccountantLink(params: {
  accountantUid: string;
  companyId: string;
}): Promise<void> {
  await admin
    .firestore()
    .collection('accountant_links')
    .doc(`${params.companyId}_${params.accountantUid}`)
    .set(
      {
        companyId: params.companyId,
        accountantUserId: params.accountantUid,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        demoReadOnly: true,
      },
      {merge: true},
    );
}

async function ensurePublicDemoWorkspace(companyId: string): Promise<void> {
  await admin
    .firestore()
    .collection('company_settings')
    .doc(companyId)
    .set(
      {
        companyId,
        companyName: PUBLIC_DEMO_COMPANY_NAME,
        companyOperationalProfile: 'small_business',
        companyData: {
          razaoSocial: PUBLIC_DEMO_COMPANY_NAME,
          nomeFantasia: PUBLIC_DEMO_COMPANY_NAME,
          responsavelNome: 'Equipe Ponto Certo',
          cnpj: '00000000000000',
          businessCategory: 'service',
          inscricaoEstadual: '',
          inscricaoEstadualDispensada: true,
          inscricaoMunicipalObrigatoria: true,
          inscricaoMunicipal: 'DEMO-IM',
          telefone: '(00) 00000-0000',
          email: 'demo@pontocerto.local',
          endereco: 'Ambiente demonstrativo',
          rua: 'Rua Demo',
          numero: '100',
          bairro: 'Centro',
          cidade: 'Sao Paulo',
          estado: 'SP',
          cep: '00000000',
          companyType: 'EMPRESA',
          companyPlan: 'EQUIPE',
          legalNature: 'Demonstracao',
          companySize: 'Demo',
          mainCnaeDescription: 'Ambiente demonstrativo do sistema',
          companyDisplayCode: 'DEMO-PC',
        },
        companyExperience: {
          type: 'EMPRESA',
          plan: 'Equipe',
          validationLabel: 'Ambiente demo ficticio',
          validationReason:
            'Workspace demonstrativo do Ponto Certo, sem dados reais.',
        },
        accountantOffice: {
          officeId: PUBLIC_DEMO_OFFICE_ID,
          officeName: PUBLIC_DEMO_OFFICE_NAME,
          officeEmail: 'contador.demo@pontocerto.local',
          accountantName: PUBLIC_DEMO_OFFICE_NAME,
          accountantEmail: 'contador.demo@pontocerto.local',
        },
        commercialSettings: buildLightweightTrialCommercialSettings({
          companyId,
          plan: 'equipe',
          businessTier: 'empresa',
          monthlyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
          seatsIncluded: 3,
          platformNote:
            'Workspace demo ficticio do Ponto Certo, isolado para acesso publico.',
        }),
        directSignup: {
          source: 'public_demo_workspace',
          lightweightProfilePending: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  await accountingOfficeRef().doc(PUBLIC_DEMO_OFFICE_ID).set(
    {
      officeId: PUBLIC_DEMO_OFFICE_ID,
      officeName: PUBLIC_DEMO_OFFICE_NAME,
      cnpj: '00000000000000',
      responsibleName: 'Equipe Ponto Certo',
      phone: '(00) 00000-0000',
      email: 'contador.demo@pontocerto.local',
      address: 'Ambiente demonstrativo',
      city: 'Sao Paulo',
      state: 'SP',
      billingChoiceDefault: 'office',
      notes: 'Escritorio demo ficticio para apresentacao publica.',
      source: 'public_demo_workspace',
      active: true,
      platformStatus: 'active',
      officeMonthlyPriceCents: 9790,
      officeMonthlyPriceLabel: 'R$ 97,90/mes',
      officeBillingStatus: 'trialing',
      officePricingModel: 'trial_access',
      officePartnershipWaiverAllowed: true,
      officePartnershipWaiverActive: false,
      officePartnershipStatus: 'standard',
      linkedCompaniesCount: 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function buildPublicDemoAccessSummary(): Promise<{
  visitors: number;
  companyUnique: number;
  accountantUnique: number;
}> {
  const snap = await demoPublicAccessRef().get();
  let companyUnique = 0;
  let accountantUnique = 0;
  for (const doc of snap.docs) {
    const data = asRecord(doc.data());
    const roles = asRecord(data.roles);
    if (roles.company === true) companyUnique += 1;
    if (roles.accountant === true) accountantUnique += 1;
  }
  return {
    visitors: snap.size,
    companyUnique,
    accountantUnique,
  };
}

async function ensurePublicEmployeeTesterCompany(): Promise<void> {
  const settingsRef = admin
    .firestore()
    .collection('company_settings')
    .doc(PUBLIC_EMPLOYEE_TESTER_COMPANY_ID);
  await settingsRef.set(
    {
      companyId: PUBLIC_EMPLOYEE_TESTER_COMPANY_ID,
      companyName: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
      companyOperationalProfile: 'small_business',
      companyData: {
        nomeFantasia: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
        razaoSocial: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
        companyType: 'equipe',
        companyPlan: 'employee_testers',
        businessCategory: 'service',
      },
      commercialSettings: {
        plan: 'equipe',
        lifecycleStatus: 'released',
        approvalStatus: 'approved',
        allowLogin: true,
        requiresApproval: false,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

function marketingEventsRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('marketing_public_events');
}

function marketingVisitorsRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('marketing_public_visitors');
}

function marketingSessionsRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('marketing_public_sessions');
}

function marketingDailyRef(dateKey: string): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('marketing_public_daily').doc(dateKey);
}

function marketingDailyCollectionRef(): FirebaseFirestore.CollectionReference {
  return admin.firestore().collection('marketing_public_daily');
}

function sanitizeMarketingKey(value: unknown): string {
  return asTrimmedString(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60);
}

function marketingDateKey(value = new Date()): string {
  return value.toISOString().slice(0, 10);
}

function marketingReferrerHost(referrer: unknown): string {
  const raw = asTrimmedString(referrer);
  if (!raw) return '';
  try {
    return new URL(raw).hostname.toLowerCase();
  } catch (_) {
    return raw.toLowerCase();
  }
}

function inferMarketingSourceBucket(params: {
  utmSource: unknown;
  referrerHost: unknown;
}): string {
  const utmSource = sanitizeMarketingKey(params.utmSource);
  if (utmSource) return utmSource;

  const host = marketingReferrerHost(params.referrerHost);
  if (!host) return 'direct';
  if (host.includes('instagram')) return 'instagram';
  if (host.includes('facebook')) return 'facebook';
  if (host.includes('google')) return 'google';
  if (host.includes('whatsapp')) return 'whatsapp';
  return sanitizeMarketingKey(host) || 'referral';
}

function marketingEventScore(eventName: string): number {
  switch (eventName) {
    case 'sales_page_view':
      return 1;
    case 'sales_preregistration_view':
      return 4;
    case 'sales_plan_select':
      return 8;
    case 'sales_whatsapp_comercial':
      return 10;
    case 'sales_preregistration_submit':
      return 20;
    default:
      return 0;
  }
}

function publicSalesPlanEntries(
  config: Record<string, unknown>,
): Array<Record<string, unknown>> {
  return [
    asRecord(config.planSolo),
    asRecord(config.planEquipe),
    asRecord(config.additionalAccess),
  ];
}

function inferPublicPlanFromPayment(params: {
  config: Record<string, unknown>;
  payment: Record<string, unknown>;
}): Record<string, unknown> | null {
  const valueCents = Math.round((Number(params.payment.value ?? 0) || 0) * 100);
  const description = asTrimmedString(params.payment.description).toLowerCase();
  const entries = publicSalesPlanEntries(params.config);

  for (const entry of entries) {
    const code = asTrimmedString(entry.code).toLowerCase();
    const title = asTrimmedString(entry.title).toLowerCase();
    const priceCents = Number(entry.priceCents ?? 0) || 0;
    if (priceCents > 0 && priceCents === valueCents) {
      return entry;
    }
    if (
      description &&
      ((code && description.includes(code)) || (title && description.includes(title)))
    ) {
      return entry;
    }
  }

  return null;
}

async function fetchAsaasCustomer(
  cfg: AsaasConfig,
  customerId: string,
): Promise<Record<string, unknown>> {
  if (!customerId.trim()) return {};
  return asaasRequest(cfg, `/customers/${encodeURIComponent(customerId)}`);
}

function billingIntegrationSettings(currentCommercial: Record<string, unknown>): Record<string, unknown> {
  return asRecord(currentCommercial.billingIntegration);
}

function buildDefaultBillingIntegration(
  currentCommercial: Record<string, unknown>,
): Record<string, unknown> {
  const currentBilling = billingIntegrationSettings(currentCommercial);
  const rawGraceDays = Number(currentBilling.graceDays);
  return {
    provider: asTrimmedString(currentBilling.provider) || 'manual',
    accessManagedByGateway: currentBilling.accessManagedByGateway === true,
    billingType: asTrimmedString(currentBilling.billingType) || 'BOLETO',
    cycle: asTrimmedString(currentBilling.cycle) || 'MONTHLY',
    customerId: asTrimmedString(currentBilling.customerId),
    subscriptionId: asTrimmedString(currentBilling.subscriptionId),
    paymentLinkUrl: asTrimmedString(currentBilling.paymentLinkUrl),
    checkoutUrl: asTrimmedString(currentBilling.checkoutUrl),
    externalReference: asTrimmedString(currentBilling.externalReference),
    status: asTrimmedString(currentBilling.status) || 'pending_setup',
    graceDays: Number.isFinite(rawGraceDays) && rawGraceDays >= 0 ? Math.trunc(rawGraceDays) : 3,
    graceUntil: currentBilling.graceUntil ?? null,
    currentPeriodEnd: currentBilling.currentPeriodEnd ?? null,
    lastPaymentAt: currentBilling.lastPaymentAt ?? null,
    lastPaymentId: asTrimmedString(currentBilling.lastPaymentId),
    lastPaymentStatus: asTrimmedString(currentBilling.lastPaymentStatus),
    lastWebhookEventId: asTrimmedString(currentBilling.lastWebhookEventId),
    lastWebhookEvent: asTrimmedString(currentBilling.lastWebhookEvent),
    lastWebhookAt: currentBilling.lastWebhookAt ?? null,
    delinquencyStartedAt: currentBilling.delinquencyStartedAt ?? null,
    blockReason: asTrimmedString(currentBilling.blockReason),
    webhookReady: currentBilling.webhookReady === true,
  };
}

function billingStatusAllowsAccess(status: string): boolean {
  const normalized = status.trim().toLowerCase();
  return normalized === 'active' ||
    normalized === 'paid' ||
    normalized === 'received' ||
    normalized === 'confirmed' ||
    normalized === 'trialing' ||
    normalized === 'in_grace';
}

function billingAccessState(
  commercial: Record<string, unknown>,
): { allowAccess: boolean; message: string; status: string } {
  const billing = asRecord(commercial.billingIntegration);
  const provider = asTrimmedString(billing.provider).toLowerCase();
  const accessManagedByGateway = billing.accessManagedByGateway === true;
  const status = asTrimmedString(billing.status) || 'pending_setup';

  if (!accessManagedByGateway || !provider || provider === 'manual') {
    return { allowAccess: true, message: '', status };
  }

  if (billingStatusAllowsAccess(status)) {
    return { allowAccess: true, message: '', status };
  }

  const graceUntilValue = billing.graceUntil;
  const graceUntilMillis = graceUntilValue instanceof admin.firestore.Timestamp
    ? graceUntilValue.toMillis()
    : graceUntilValue instanceof Date
      ? graceUntilValue.getTime()
      : Number.NaN;
  if (Number.isFinite(graceUntilMillis) && graceUntilMillis >= Date.now()) {
    return {
      allowAccess: true,
      message: 'Pagamento em regularizacao dentro do prazo de carencia.',
      status: 'in_grace',
    };
  }

  return {
    allowAccess: false,
    message: asTrimmedString(billing.blockReason) || 'A empresa possui pendencia financeira.',
    status,
  };
}

function buildDefaultCommercialSettings(
  current: Record<string, unknown>,
): Record<string, unknown> {
  const inferredCompanyId =
    asTrimmedString(current.companyId) ||
    asTrimmedString(current.id);
  const currentCommercial = commercialSettings(current);
  const seatsIncluded = Number(currentCommercial.seatsIncluded ?? 3) || 3;
  const contractedAppUsers =
    Number(currentCommercial.contractedAppUsers ?? seatsIncluded) || seatsIncluded;
  const baseSystemPriceCents =
    Number(currentCommercial.baseSystemPriceCents ?? currentCommercial.monthlyPriceCents ?? 0) || 0;
  const extraAppUserPriceCents =
    Number(currentCommercial.extraAppUserPriceCents ?? 0) || 0;
  const additionalAppUsers = Math.max(0, contractedAppUsers - seatsIncluded);
  const calculatedMonthlyPriceCents =
    baseSystemPriceCents + additionalAppUsers * extraAppUserPriceCents;
  const normalizedPlan = (() => {
    const rawPlan = asTrimmedString(currentCommercial.plan).toLowerCase();
    if (rawPlan === 'equipe') return 'equipe';
    if (rawPlan === 'solo') return 'solo';
    return Number(contractedAppUsers) > 1 ? 'equipe' : 'solo';
  })();
  const normalizedBusinessTier = normalizedPlan === 'solo' ? 'mei' : 'empresa';
  const billingIntegration = buildDefaultBillingIntegration(currentCommercial);
  const defaults = {
    plan: normalizedPlan,
    businessTier: normalizedBusinessTier,
    lifecycleStatus:
      asTrimmedString(currentCommercial.lifecycleStatus) || 'trial',
    billingStatus: asTrimmedString(currentCommercial.billingStatus) || 'trialing',
    allowLogin: currentCommercial.allowLogin !== false,
    requiresApproval: currentCommercial.requiresApproval === true,
    approvalStatus:
      asTrimmedString(currentCommercial.approvalStatus) || 'auto_approved',
    seatsIncluded,
    contractedAppUsers,
    baseSystemPriceCents,
    extraAppUserPriceCents,
    pricingModel:
      asTrimmedString(currentCommercial.pricingModel) || 'base_plus_app_users',
    monthlyPriceCents:
      Number(currentCommercial.monthlyPriceCents ?? calculatedMonthlyPriceCents) ||
      calculatedMonthlyPriceCents,
    calculatedMonthlyPriceCents,
    accessControlMode:
      asTrimmedString(currentCommercial.accessControlMode) || 'standard',
    activationRequired: currentCommercial.activationRequired === true,
    activationStatus:
      asTrimmedString(currentCommercial.activationStatus) ||
      (currentCommercial.activationRequired === true ? 'pending_code' : 'not_required'),
    activationCodeLast4: asTrimmedString(currentCommercial.activationCodeLast4),
    activationCodeIssuedAt: currentCommercial.activationCodeIssuedAt,
    activationCodeExpiresAt: currentCommercial.activationCodeExpiresAt,
    activationReleasedAt: currentCommercial.activationReleasedAt,
    activationReleasedByCodeId: asTrimmedString(currentCommercial.activationReleasedByCodeId),
    billingIntegration,
    platformNote: asTrimmedString(currentCommercial.platformNote),
  };

  if (isSupremePlatformCompany(inferredCompanyId)) {
    const supremeCommercial = {
      ...currentCommercial,
      ...defaults,
      plan: 'supreme',
      businessTier: 'platform',
      lifecycleStatus: 'released',
      billingStatus: 'active',
      allowLogin: true,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired: false,
      activationStatus: 'released',
      activationCodeLast4: '',
      activationCodeIssuedAt: null,
      activationCodeExpiresAt: null,
      activationReleasedAt: null,
      activationReleasedByCodeId: '',
      billingIntegration: {
        ...billingIntegration,
        accessManagedByGateway: false,
        status: 'active',
        blockReason: '',
      },
    };
    return omitUndefinedForFirestore(supremeCommercial) as Record<string, unknown>;
  }

  return omitUndefinedForFirestore({
    ...currentCommercial,
    ...defaults,
  }) as Record<string, unknown>;
}

function normalizeActivationCode(value: unknown): string {
  return asTrimmedString(value).toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function hashActivationCode(value: unknown): string {
  return crypto.createHash('sha256').update(normalizeActivationCode(value)).digest('hex');
}

function generateActivationCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(12);
  const chars = Array.from(bytes).map((byte) => alphabet[byte % alphabet.length]).join('');
  return `PC-${chars.slice(0, 4)}-${chars.slice(4, 8)}-${chars.slice(8, 12)}`;
}

function activationCodeLast4(value: unknown): string {
  const normalized = normalizeActivationCode(value);
  return normalized.slice(-4);
}

function timestampToIsoString(value: unknown): string {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  return asTrimmedString(value);
}

function parseTimestampLike(value: unknown): admin.firestore.Timestamp | null {
  if (value == null) return null;
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value instanceof Date) return admin.firestore.Timestamp.fromDate(value);
  const parsed = new Date(String(value));
  if (Number.isNaN(parsed.getTime())) return null;
  return admin.firestore.Timestamp.fromDate(parsed);
}

function webhookTokenFromRequest(req: functions.https.Request): string {
  const headers = req.headers;
  const direct = headers['asaas-access-token'] ?? headers['access_token'] ?? headers['access-token'];
  if (Array.isArray(direct)) return asTrimmedString(direct[0]);
  if (direct != null) return asTrimmedString(direct);
  const authorization = headers.authorization;
  const authValue = Array.isArray(authorization) ? authorization[0] : authorization;
  const authText = asTrimmedString(authValue);
  if (authText.toLowerCase().startsWith('bearer ')) {
    return authText.slice(7).trim();
  }
  return '';
}

async function asaasRequest(
  cfg: AsaasConfig,
  path: string,
  init?: {
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
    body?: Record<string, unknown>;
  },
): Promise<Record<string, unknown>> {
  const response = await fetch(`${cfg.baseUrl}${path}`, {
    method: init?.method ?? 'GET',
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      access_token: cfg.apiKey,
      'user-agent': 'PontoCerto/AsaasIntegration',
    },
    body: init?.body ? JSON.stringify(init.body) : undefined,
  });

  const rawText = await response.text();
  const payload = rawText ? asRecord(JSON.parse(rawText)) : {};
  if (!response.ok) {
    const errors = Array.isArray(payload.errors) ? payload.errors : [];
    const firstError = errors.length > 0 ? asRecord(errors[0]) : {};
    const description =
      asTrimmedString(firstError.description) ||
      asTrimmedString(payload.message) ||
      `Erro Asaas ${response.status}.`;
    throw new functions.https.HttpsError('internal', description);
  }
  return payload;
}

async function syncAsaasSubscriptionForCommercialSettings(params: {
  commercial: Record<string, unknown>;
  companyId: string;
}): Promise<Record<string, unknown>> {
  const billing = asRecord(params.commercial.billingIntegration);
  const provider = asTrimmedString(billing.provider).toLowerCase();
  const subscriptionId = asTrimmedString(billing.subscriptionId);
  const customerId = asTrimmedString(billing.customerId);
  if (provider !== 'asaas' || !subscriptionId || !customerId) {
    return billing;
  }

  const cfg = assertAsaasConfigured();
  const nextDueDateTs =
    parseTimestampLike(billing.currentPeriodEnd) ??
    admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
  const description =
    `Plano ${asTrimmedString(params.commercial.plan)} | ${params.companyId}`;
  const result = await asaasRequest(
    cfg,
    `/subscriptions/${encodeURIComponent(subscriptionId)}`,
    {
      method: 'PUT',
      body: {
        customer: customerId,
        billingType: asaasBillingType(billing.billingType),
        cycle: asaasSubscriptionCycle(billing.cycle),
        value: toAsaasMoneyValue(params.commercial.monthlyPriceCents),
        nextDueDate: toIsoDateString(nextDueDateTs.toDate()),
        description,
        externalReference:
          asTrimmedString(billing.externalReference) || params.companyId,
        updatePendingPayments: true,
      },
    },
  );

  return {
    ...billing,
    billingType: asaasBillingType(billing.billingType),
    cycle: asaasSubscriptionCycle(billing.cycle),
    status: asTrimmedString(result.status).toLowerCase() || asTrimmedString(billing.status),
    currentPeriodEnd:
      parseTimestampLike(result.nextDueDate) ?? billing.currentPeriodEnd ?? null,
    lastWebhookAt: billing.lastWebhookAt ?? null,
  };
}

function billingChargeSortTime(payment: Record<string, unknown>): number {
  const value =
    parseTimestampLike(payment.dueDate) ??
    parseTimestampLike(payment.clientPaymentDate) ??
    parseTimestampLike(payment.dateCreated);
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  return 0;
}

function selectAsaasRenewalPayment(payments: Record<string, unknown>[]): Record<string, unknown> {
  const priorities = ['OVERDUE', 'PENDING', 'CONFIRMED', 'RECEIVED'];
  for (const status of priorities) {
    const matches = payments
      .filter((item) => asTrimmedString(item.status).toUpperCase() === status)
      .sort((a, b) => billingChargeSortTime(a) - billingChargeSortTime(b));
    if (matches.length > 0) {
      return matches[0];
    }
  }

  return payments.sort((a, b) => billingChargeSortTime(b) - billingChargeSortTime(a))[0] ?? {};
}

function primaryAsaasPaymentUrl(payment: Record<string, unknown>): string {
  return (
    asTrimmedString(payment.invoiceUrl) ||
    asTrimmedString(payment.bankSlipUrl) ||
    asTrimmedString(payment.transactionReceiptUrl)
  );
}

function nextCancellationAccessDeadline(
  billing: Record<string, unknown>,
): admin.firestore.Timestamp {
  const currentPeriodEnd = parseTimestampLike(billing.currentPeriodEnd);
  if (currentPeriodEnd instanceof admin.firestore.Timestamp) {
    return currentPeriodEnd;
  }
  const graceDays = Number(billing.graceDays ?? 3) || 3;
  return admin.firestore.Timestamp.fromMillis(
    Date.now() + Math.max(0, graceDays) * 24 * 60 * 60 * 1000,
  );
}

function asaasEventPaymentData(payload: Record<string, unknown>): Record<string, unknown> {
  return asRecord(payload.payment);
}

function asaasEventSubscriptionData(payload: Record<string, unknown>): Record<string, unknown> {
  return asRecord(payload.subscription);
}

async function resolveCompanyIdFromAsaasPayload(
  payload: Record<string, unknown>,
): Promise<string> {
  const payment = asaasEventPaymentData(payload);
  const subscription = asaasEventSubscriptionData(payload);

  const externalReference = asTrimmedString(
    payment.externalReference || subscription.externalReference || payload.externalReference,
  );
  if (externalReference.startsWith('comp_')) {
    return externalReference;
  }

  const subscriptionId = asTrimmedString(payment.subscription || subscription.id);
  if (subscriptionId) {
    const bySubscription = await admin
      .firestore()
      .collection('company_settings')
      .where('commercialSettings.billingIntegration.subscriptionId', '==', subscriptionId)
      .limit(1)
      .get();
    if (!bySubscription.empty) {
      return asTrimmedString(bySubscription.docs[0].id);
    }
  }

  const customerId = asTrimmedString(payment.customer || subscription.customer);
  if (customerId) {
    const byCustomer = await admin
      .firestore()
      .collection('company_settings')
      .where('commercialSettings.billingIntegration.customerId', '==', customerId)
      .limit(1)
      .get();
    if (!byCustomer.empty) {
      return asTrimmedString(byCustomer.docs[0].id);
    }
  }

  return '';
}

function billingStatusFromAsaasEvent(
  eventName: string,
  paymentData: Record<string, unknown>,
): { status: string; markPaid: boolean; blockReason: string } {
  const statusRaw = asTrimmedString(paymentData.status).toUpperCase();
  const event = eventName.trim().toUpperCase();

  if (
    event.includes('RECEIVED') ||
    event.includes('CONFIRMED') ||
    statusRaw === 'RECEIVED' ||
    statusRaw === 'CONFIRMED' ||
    statusRaw === 'RECEIVED_IN_CASH'
  ) {
    return { status: 'paid', markPaid: true, blockReason: '' };
  }

  if (event.includes('OVERDUE') || statusRaw === 'OVERDUE') {
    return {
      status: 'overdue',
      markPaid: false,
      blockReason: 'Pagamento em atraso no Asaas.',
    };
  }

  if (
    event.includes('DELETED') ||
    event.includes('RESTORED') ||
    statusRaw === 'DELETED' ||
    statusRaw === 'CANCELLED'
  ) {
    return {
      status: 'canceled',
      markPaid: false,
      blockReason: 'Cobranca cancelada no Asaas.',
    };
  }

  if (
    event.includes('REFUNDED') ||
    statusRaw === 'REFUNDED' ||
    statusRaw === 'REFUND_REQUESTED' ||
    event.includes('CHARGEBACK')
  ) {
    return {
      status: 'delinquent',
      markPaid: false,
      blockReason: 'Pagamento estornado ou contestado no Asaas.',
    };
  }

  if (statusRaw === 'PENDING' || event.includes('CREATED') || event.includes('UPDATED')) {
    return {
      status: 'pending_payment',
      markPaid: false,
      blockReason: 'Aguardando pagamento no Asaas.',
    };
  }

  return {
    status: statusRaw ? statusRaw.toLowerCase() : 'pending_payment',
    markPaid: false,
    blockReason: 'Status financeiro pendente no Asaas.',
  };
}

function httpStatusFromError(error: unknown): number {
  const code = asTrimmedString(asRecord(error).code).toLowerCase();
  if (code === 'unauthenticated') return 401;
  if (code === 'permission-denied') return 403;
  if (code === 'not-found') return 404;
  if (code === 'invalid-argument') return 400;
  if (code === 'failed-precondition') return 412;
  if (code === 'resource-exhausted') return 429;
  return 500;
}

const HEAVY_RUNTIME = functions.runWith({
  timeoutSeconds: 120,
  memory: '1GB',
});

function runtimeSummaryRef(companyId: string): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('company_runtime_summary').doc(companyId);
}

function paymentSummaryBucket(
  data: Record<string, unknown>,
): 'pendingPayrollCents' | 'paidPayrollCents' | 'confirmedPayrollCents' | 'contestedPayrollCents' | null {
  const status = asTrimmedString(data.status).toUpperCase();
  if (status === 'PENDING') return 'pendingPayrollCents';
  if (status === 'PAID') return 'paidPayrollCents';
  if (status === 'CONFIRMED') return 'confirmedPayrollCents';
  if (status === 'CONTESTED') return 'contestedPayrollCents';
  return null;
}

function paymentSummaryAmount(data: Record<string, unknown>): number {
  const direct = Number(data.netCents ?? data.valorCents ?? data.grossCents ?? 0);
  if (!Number.isFinite(direct)) return 0;
  return Math.max(0, Math.trunc(direct));
}

function debtSummaryBucket(
  data: Record<string, unknown>,
): 'openDebtsCents' | 'settledDebtsCents' | 'openAdvancesCents' | 'settledAdvancesCents' | null {
  const status = asTrimmedString(data.status).toUpperCase();
  const type = asTrimmedString(data.type).toUpperCase();

  if (type === 'ADVANCE') {
    if (status === 'OPEN') return 'openAdvancesCents';
    if (status === 'SETTLED') return 'settledAdvancesCents';
    return null;
  }

  if (status === 'OPEN') return 'openDebtsCents';
  if (status === 'SETTLED') return 'settledDebtsCents';
  return null;
}

function debtSummaryAmount(data: Record<string, unknown>): number {
  const direct = Number(data.amountCents ?? data.valorCents ?? 0);
  if (!Number.isFinite(direct)) return 0;
  return Math.max(0, Math.trunc(direct));
}

async function applyRuntimeSummaryDelta(
  tx: FirebaseFirestore.Transaction,
  companyId: string,
  section: 'finance',
  bucketBefore: string | null,
  amountBefore: number,
  bucketAfter: string | null,
  amountAfter: number,
  currentSectionData?: Record<string, unknown>,
): Promise<void> {
  const ref = runtimeSummaryRef(companyId);
  const sectionData = currentSectionData ?? asRecord((await tx.get(ref)).data()?.[section]);
  const next = { ...sectionData };

  if (bucketBefore) {
    const currentValue = Number(next[bucketBefore] ?? 0);
    next[bucketBefore] = Math.max(
      0,
      Math.trunc((Number.isFinite(currentValue) ? currentValue : 0) - amountBefore),
    );
  }

  if (bucketAfter) {
    const currentValue = Number(next[bucketAfter] ?? 0);
    next[bucketAfter] = Math.max(
      0,
      Math.trunc((Number.isFinite(currentValue) ? currentValue : 0) + amountAfter),
    );
  }

  next.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  tx.set(
    ref,
    {
      companyId,
      [section]: next,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function readRuntimeSummarySection(
  tx: FirebaseFirestore.Transaction,
  companyId: string,
  section: 'finance',
): Promise<Record<string, unknown>> {
  const snap = await tx.get(runtimeSummaryRef(companyId));
  return asRecord(asRecord(snap.data())[section]);
}

function financeMovementSummaryFields(
  data: Record<string, unknown>,
): {
  totalBucket: 'companyReceivablesCents' | 'companyPayablesCents' | null;
  paidBucket: 'companyReceivablesReceivedCents' | 'companyPayablesPaidCents' | null;
  amount: number;
} {
  const sourceModule = asTrimmedString(data.sourceModule).toLowerCase();
  if (sourceModule === 'payments' || sourceModule === 'debts') {
    return { totalBucket: null, paidBucket: null, amount: 0 };
  }

  const type = asTrimmedString(data.type).toUpperCase();
  const paymentStatus = asTrimmedString(data.paymentStatus).toUpperCase();
  const amount = Math.max(0, Math.trunc(Number(data.amountCents ?? 0) || 0));

  if (type === 'INCOME') {
    return {
      totalBucket: 'companyReceivablesCents',
      paidBucket: paymentStatus === 'PAID' ? 'companyReceivablesReceivedCents' : null,
      amount,
    };
  }

  if (type === 'EXPENSE') {
    return {
      totalBucket: 'companyPayablesCents',
      paidBucket: paymentStatus === 'PAID' ? 'companyPayablesPaidCents' : null,
      amount,
    };
  }

  return { totalBucket: null, paidBucket: null, amount: 0 };
}

async function applyFinanceMovementSummaryDelta(
  tx: FirebaseFirestore.Transaction,
  companyId: string,
  beforeData: Record<string, unknown>,
  afterData: Record<string, unknown>,
): Promise<void> {
  const ref = runtimeSummaryRef(companyId);
  const snap = await tx.get(ref);
  const current = asRecord(snap.data());
  const finance = { ...asRecord(current.finance) };

  function addToBucket(stringKey: string | null, amount: number, multiplier: 1 | -1): void {
    if (!stringKey || amount <= 0) return;
    const currentValue = Number(finance[stringKey] ?? 0);
    finance[stringKey] = Math.max(
      0,
      Math.trunc((Number.isFinite(currentValue) ? currentValue : 0) + amount * multiplier),
    );
  }

  const before = financeMovementSummaryFields(beforeData);
  const after = financeMovementSummaryFields(afterData);

  addToBucket(before.totalBucket, before.amount, -1);
  addToBucket(before.paidBucket, before.amount, -1);
  addToBucket(after.totalBucket, after.amount, 1);
  addToBucket(after.paidBucket, after.amount, 1);

  const receivables = Number(finance.companyReceivablesCents ?? 0) || 0;
  const receivablesReceived = Number(finance.companyReceivablesReceivedCents ?? 0) || 0;
  const payables = Number(finance.companyPayablesCents ?? 0) || 0;
  const payablesPaid = Number(finance.companyPayablesPaidCents ?? 0) || 0;

  finance.companyReceivablesPendingCents = Math.max(0, Math.trunc(receivables - receivablesReceived));
  finance.companyPayablesPendingCents = Math.max(0, Math.trunc(payables - payablesPaid));
  finance.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  tx.set(
    ref,
    {
      companyId,
      finance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/**
 * Numero exibido na prefeitura / Sefin: nomes de campo variam (NFSe, DPS, municipio, nacional).
 */
function extractFocusOfficialNfseNumber(r: Record<string, unknown>): string {
  const directKeys = [
    'numero_nfse',
    'numeroNfse',
    'numero_nfse_substituida',
    'numero_nfse_substituta',
    'numero_nfs_e',
    'numero_nfs',
    'numeroNfs',
    'numeroNota',
    'numero_nota',
    'numeroNotaFiscal',
    'numero_nota_fiscal',
    'numero',
    'nNF',
    'nNFSe',
    'nfseNumber',
    'numeroDPS',
    'numeroDps',
    'numero_dps',
    'num_dps',
    'numDps',
    'invoiceNumber',
    'nfse_numero',
  ];
  for (const k of directKeys) {
    const v = asTrimmedString((r as Record<string, unknown>)[k]);
    if (v) {
      return v;
    }
  }

  const nestedKeys = [
    'nfse',
    'Nfse',
    'nfs_e',
    'nfs-e',
    'nota',
    'notaFiscal',
    'nota_fiscal',
    'notaFiscalServico',
    'nota_fiscal_servico',
    'dps',
    'DPS',
    'nfe',
    'Nfe',
    'dados_nfse',
    'dps_gerada',
    'resposta',
    'response',
    'body',
    'data',
  ];
  for (const nest of nestedKeys) {
    const sub = asRecord((r as Record<string, unknown>)[nest]);
    if (Object.keys(sub).length === 0) {
      continue;
    }
    const v = extractFocusOfficialNfseNumber(sub);
    if (v) {
      return v;
    }
  }
  return '';
}

function coalesceFocusNfseStatusRawForNormalize(r: Record<string, unknown>): string {
  return (
    asTrimmedString(r.status) ||
    asTrimmedString((r as any).situacao) ||
    asTrimmedString((r as any).Situacao) ||
    asTrimmedString((r as any).situacao_nfe) ||
    asTrimmedString((r as any).situacaoNfe) ||
    asTrimmedString((r as any).situacao_nfse) ||
    asTrimmedString((r as any).estado) ||
    (typeof (r as any).codigo_situacao === 'number'
      ? String((r as any).codigo_situacao)
      : '') ||
    (typeof (r as any).codigoSituacao === 'number'
      ? String((r as any).codigoSituacao)
      : '') ||
    ''
  );
}

function fiscalInvoiceSummaryFields(
  data: Record<string, unknown>,
): {
  countBucket:
    | 'draftInvoicesCount'
    | 'approvedInvoicesCount'
    | 'canceledInvoicesCount'
    | 'processingInvoicesCount'
    | null;
  grossAmountCents: number;
} {
  const status = asTrimmedString(data.status).toUpperCase();
  const lastAttemptStatus = asTrimmedString(data.lastEmissionAttemptStatus).toUpperCase();
  const officialFromDoc = asTrimmedString(data.officialNumber);
  const fromOfficialResponse = extractFocusOfficialNfseNumber(
    asRecord((data as Record<string, unknown>).officialResponse),
  );
  const officialNumber = officialFromDoc || fromOfficialResponse;
  const hasOfficialNumber = officialNumber.length > 0;
  const lastSuccess = lastAttemptStatus === 'SUCCESS';
  const service = asRecord((data as Record<string, unknown>).service);
  const billing = asRecord((data as Record<string, unknown>).billing);
  const fromAmount = Math.trunc(Number(data.amountCents ?? 0) || 0);
  const fromGross = Math.trunc(Number(service.grossAmountCents ?? 0) || 0);
  const fromBillingFinal = Math.trunc(Number(billing.finalAmountCents ?? 0) || 0);
  const grossAmountCents = Math.max(0, fromAmount, fromGross, fromBillingFinal);

  if (status === 'CANCELED' || status === 'CANCELLED') {
    return { countBucket: 'canceledInvoicesCount', grossAmountCents: 0 };
  }
  // Registro oficial autorizado: APPROVED e legado EMITTED entram no mesmo bucket.
  const isIssuedLike = status === 'EMITTED' || status === 'APPROVED';
  if (isIssuedLike && hasOfficialNumber) {
    return {
      countBucket: 'approvedInvoicesCount',
      grossAmountCents,
    };
  }
  if (lastSuccess && hasOfficialNumber) {
    return {
      countBucket: 'approvedInvoicesCount',
      grossAmountCents,
    };
  }
  if (isIssuedLike && !hasOfficialNumber) {
    return { countBucket: 'processingInvoicesCount', grossAmountCents: 0 };
  }
  if (lastSuccess && !hasOfficialNumber && grossAmountCents > 0) {
    return {
      countBucket: 'approvedInvoicesCount',
      grossAmountCents,
    };
  }
  if (
    status === 'PROCESSANDO' ||
    status === 'PROCESSING' ||
    status.startsWith('PROCESSANDO_') ||
    status.startsWith('PROCESSING_') ||
    lastAttemptStatus === 'PROCESSING' ||
    lastAttemptStatus.startsWith('PROCESSING_')
  ) {
    return { countBucket: 'processingInvoicesCount', grossAmountCents: 0 };
  }
  if (
    status === 'DRAFT' ||
    status === 'FAILED' ||
    status === 'REJECTED' ||
    lastAttemptStatus === 'FAILED' ||
    lastAttemptStatus === 'CANCEL_FAILED' ||
    lastAttemptStatus === 'QUERY_FAILED'
  ) {
    return { countBucket: 'draftInvoicesCount', grossAmountCents: 0 };
  }
  return { countBucket: 'draftInvoicesCount', grossAmountCents: 0 };
}

async function rebuildFiscalInvoiceRuntimeSummary(companyId: string): Promise<void> {
  const snapshot = await admin
    .firestore()
    .collection('service_invoices')
    .where('companyId', '==', companyId)
    .get();

  let draftInvoicesCount = 0;
  let approvedInvoicesCount = 0;
  let canceledInvoicesCount = 0;
  let processingInvoicesCount = 0;
  let emittedGrossAmountCents = 0;

  for (const doc of snapshot.docs) {
    const summary = fiscalInvoiceSummaryFields(asRecord(doc.data()));
    if (summary.countBucket === 'draftInvoicesCount') draftInvoicesCount += 1;
    if (summary.countBucket === 'approvedInvoicesCount') {
      approvedInvoicesCount += 1;
      emittedGrossAmountCents += summary.grossAmountCents;
    }
    if (summary.countBucket === 'canceledInvoicesCount') canceledInvoicesCount += 1;
    if (summary.countBucket === 'processingInvoicesCount') processingInvoicesCount += 1;
  }

  await runtimeSummaryRef(companyId).set(
    {
      companyId,
      fiscal: {
        draftInvoicesCount,
        emittedInvoicesCount: admin.firestore.FieldValue.delete(),
        approvedInvoicesCount,
        canceledInvoicesCount,
        processingInvoicesCount,
        emittedGrossAmountCents,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function companyAccessState(settingsData: Record<string, unknown>): {
  allowLogin: boolean;
  lifecycleStatus: string;
  approvalStatus: string;
  message: string;
} {
  const inferredCompanyId =
    asTrimmedString(settingsData.companyId) || asTrimmedString(settingsData.id);
  if (isSupremePlatformCompany(inferredCompanyId)) {
    return {
      allowLogin: true,
      lifecycleStatus: 'released',
      approvalStatus: 'approved',
      message: '',
    };
  }
  const commercial = buildDefaultCommercialSettings(settingsData);
  const lifecycleStatus = asTrimmedString(commercial.lifecycleStatus) || 'trial';
  const approvalStatus = asTrimmedString(commercial.approvalStatus) || 'auto_approved';
  const billingAccess = billingAccessState(commercial);
  const allowLogin = commercial.allowLogin !== false &&
    lifecycleStatus !== 'suspended' &&
    lifecycleStatus !== 'inactive' &&
    lifecycleStatus !== 'blocked' &&
    !(commercial.requiresApproval === true && approvalStatus !== 'approved') &&
    billingAccess.allowAccess;

  let message = '';
  if (commercial.allowLogin === false) {
    message = 'A empresa esta temporariamente desativada para acesso.';
  } else if (lifecycleStatus === 'suspended') {
    message = 'A empresa esta suspensa temporariamente.';
  } else if (lifecycleStatus === 'inactive' || lifecycleStatus === 'blocked') {
    message = 'A empresa esta inativa no momento.';
  } else if (commercial.requiresApproval === true && approvalStatus !== 'approved') {
    message = 'A empresa ainda aguarda aprovacao da plataforma.';
  } else if (!billingAccess.allowAccess) {
    message = billingAccess.message;
  } else if (billingAccess.message.length > 0) {
    message = billingAccess.message;
  }

  return {
    allowLogin,
    lifecycleStatus,
    approvalStatus,
    message,
  };
}

function assertPlatformAdmin(
  claims: Claims,
  userProfile: Record<string, unknown>,
): void {
  const email = asTrimmedString(userProfile.email).toLowerCase();
  const allowed = platformAdminEmails();
  const companyAllowed = isSupremePlatformCompany(claims.companyId);
  const emailAllowed = !!email && allowed.includes(email);
  if (claims.role !== 'OWNER' || (!companyAllowed && !emailAllowed)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Apenas a administracao da plataforma pode executar esta operacao.',
    );
  }
}

function assistantThreadTitleFromMessage(message: string): string {
  const normalized = message.replace(/\s+/g, ' ').trim();
  if (!normalized) return 'Nova conversa';
  if (normalized.length <= 72) return normalized;
  return `${normalized.slice(0, 69).trim()}...`;
}

function normalizeAssistantRoute(route: unknown): string {
  const value = asTrimmedString(route);
  return value.startsWith('/') ? value.slice(0, 80) : value.slice(0, 80);
}

function buildAssistantFeatureInventory(): string {
  return [
    'Inventario real do sistema nesta versao:',
    '- Assistente: chat para orientacao operacional sobre o proprio Ponto Certo.',
    '- Empresa: cadastro da empresa, configuracao fiscal, configuracao da OpenAI, contador e controles do assistente.',
    '- Clientes: cadastro, consulta e revisao de clientes e tomadores.',
    '- Tarefas: tarefas operacionais ligadas ao dia a dia da empresa.',
    '- Ordens de servico: criacao, acompanhamento, atualizacao e exclusao.',
    '- Faturamento: faturamento recorrente e geracao de cobrancas internas refletidas no financeiro.',
    '- Financeiro: entradas, saidas, movimentos financeiros e acompanhamento da empresa.',
    '- Fiscal: readiness fiscal, configuracao Focus, sincronizacao e emissao de NFS-e.',
    '- Funcionarios: funcionarios, equipe operacional e contadores vinculados.',
    '- Trabalhista: folha, documentos e geracao de PDF; o documento de contrato de funcionario hoje deve ser tratado como "Contrato simples".',
    '- Documentos: canal operacional de solicitacoes entre contador, empresa e funcionarios, com pedidos separados e anexos por solicitacao.',
    '- Propostas: propostas comerciais com geracao e abertura de PDF.',
    '- Contratos: contratos comerciais cadastrados no sistema.',
    '- Clausulas contratuais: base documental da empresa.',
    '- Catalogo de servicos: servicos usados na operacao e no fiscal.',
    '- Materiais: materiais cadastrados.',
    '- Relatorios: relatorios operacionais e gerenciais.',
    '- Pagamentos: pagamentos.',
    '- Dividas: dividas.',
    '- Ponto: ponto.',
    '- Justificativas: justificativas.',
    '- Configuracoes: configuracoes gerais.',
    '- Plataforma: painel supremo da plataforma, so para a empresa suprema.',
    '- Observabilidade: so para a empresa suprema.',
    '- Auditoria: trilha de auditoria.',
    'Capacidades reais de documentos e PDF nesta versao:',
    '- proposta comercial: ja existe PDF no fluxo de propostas.',
    '- contrato comercial ligado a proposta: ja existe PDF no fluxo de propostas/contratos.',
    '- contrato simples de funcionario: ja existe geracao de PDF no modulo trabalhista.',
    '- Documentos: pedidos podem ser enviados para a empresa ou para funcionarios especificos, com PDF e imagem anexados por solicitacao.',
    'Regra critica: se o usuario perguntar sobre algo fora dessa lista, diga claramente que esse modulo ou fluxo nao esta confirmado nesta versao do sistema.',
  ].join('\n');
}

function buildAssistantRouteGuide(route: string): string {
  switch (route) {
    case '/workforce':
      return [
        'Guia da tela atual:',
        '- voce esta no modulo trabalhista.',
        '- contratos de funcionario devem ser orientados como "Contrato simples".',
        '- nao cite upload de imagem para assinatura; o fluxo atual usa registro de assinatura manual ou digital com dados do ato.',
      ].join('\n');
    case '/documents':
      return [
        'Guia da tela atual:',
        '- voce esta na area de solicitacoes de documentos.',
        '- cada pedido deve ser tratado como solicitacao separada com itens pedidos e documentos recebidos.',
        '- o contador pode pedir direto para a empresa ou para funcionarios especificos.',
        '- a empresa pode encaminhar uma solicitacao para funcionarios.',
        '- funcionarios veem no app apenas as solicitacoes encaminhadas para eles.',
      ].join('\n');
    case '/fiscal':
      return [
        'Guia da tela atual:',
        '- voce esta no modulo fiscal.',
        '- priorize orientacao sobre configuracao, sincronizacao Focus, readiness e emissao de NFS-e.',
      ].join('\n');
    default:
      return [
        'Guia da tela atual:',
        '- responda com base apenas nos modulos e fluxos confirmados do inventario.',
      ].join('\n');
  }
}

function buildAssistantFaqGuide(): string {
  return [
    'Respostas-base que devem ser priorizadas quando a pergunta combinar com estes temas:',
    '- contrato de funcionario: orientar para Trabalhista e chamar o documento pelo nome real "Contrato simples". Informar que hoje existe geracao de PDF nesse fluxo.',
    '- proposta comercial em pdf: orientar para Propostas e informar que ja existem botoes para abrir PDF e compartilhar PDF.',
    '- documentos: orientar como canal de solicitacao, envio e conferencia de documentos por pedido, com anexos separados por solicitacao.',
    '- criar tarefa: orientar para Tarefas, usando o nome real do botao "Criar". Informar os campos reais: Nome, Descricao, Cliente, CPF ou CNPJ do cliente, Data da execucao e, quando for empresa, Direcionar para funcionario.',
    '- configuracao da OpenAI: orientar para Empresa.',
    '- observabilidade: orientar para Observabilidade apenas quando o contexto for da empresa suprema.',
  ].join('\n');
}

function buildAssistantModuleResponseGuide(): string {
  return [
    'Guia de resposta por modulo real do produto:',
    '- Assistente: orientar sobre uso do sistema e proximos passos, sem inventar automacoes inexistentes.',
    '- Empresa: responder sobre dados cadastrais, perfil operacional, configuracao da OpenAI, governanca do contador e do assistente.',
    '- Clientes: responder sobre cadastro, documento, cidade e tomador.',
    '- Tarefas: responder sobre execucao operacional, lista de tarefas e distribuicao por responsavel.',
    '- Ordens de servico: responder sobre abertura, andamento, finalizacao e exclusao.',
    '- Faturamento: responder sobre perfis recorrentes e cobrancas internas geradas no financeiro.',
    '- Financeiro: responder sobre contas a pagar, contas a receber, caixa, vencimentos, pagamentos, dividas e movimentos.',
    '- Fiscal: responder sobre readiness fiscal, integracao real, servicos fiscais, tomador, NFS-e oficial e emissao fiscal real.',
    '- Funcionarios: responder sobre equipe operacional, equipe ativa, inativa e contadores vinculados.',
    '- Trabalhista: responder sobre folha, fechamento mensal, documentos da folha, contratos com funcionarios e historico de contratos.',
    '- Propostas: responder sobre propostas e contratos e, quando aplicavel, mencionar PDF ja existente nesse fluxo.',
    '- Contratos: responder como parte do fluxo de propostas e contratos ja existente.',
    '- Clausulas: responder sobre base contratual e PDFs de clausulas quando o contexto pedir.',
    '- Documentos: responder como canal de pedidos entre contador, empresa e funcionarios, com envio e conferencia de PDF/imagem por solicitacao.',
    '- Catalogo: responder sobre servicos cadastrados.',
    '- Materiais: responder sobre materiais cadastrados.',
    '- Relatorios: responder sobre relatorios operacionais e gerenciais ja presentes.',
    '- Pagamentos e Dividas: responder como controles financeiros especificos.',
    '- Ponto e Justificativas: responder como rotinas de registro e justificativa.',
    '- Observabilidade e Plataforma: responder so para a empresa suprema.',
    'Regra de linguagem: prefira sempre os nomes reais das telas como "Fiscal", "Trabalhista", "Propostas e contratos", "Documentos", "Empresa" e "Ordens de servico".',
  ].join('\n');
}

function buildAssistantBusinessContextGuide(
  companySettings: Record<string, unknown>,
  userProfile: Record<string, unknown>,
): string {
  const companyData = asRecord(
    companySettings.companyData || userProfile.companyData,
  );
  const companyType = asTrimmedString(companyData.companyType);
  const companyPlan = asTrimmedString(companyData.companyPlan);
  const businessCategory = asTrimmedString(companyData.businessCategory);
  const mainCnaeDescription = asTrimmedString(companyData.mainCnaeDescription);
  const mainCnae = asTrimmedString(companyData.mainCnae);
  const companySize = asTrimmedString(companyData.companySize);
  const legalNature = asTrimmedString(companyData.legalNature);
  const employeeRole = asTrimmedString(userProfile.role);
  const employeeCargo = asTrimmedString(userProfile.cargo);
  const employeeNickname = asTrimmedString(userProfile.apelido);
  const employeeCompensationType = asTrimmedString(userProfile.compensationType);

  const companyDescriptors = [
    companyType && `tipo=${companyType}`,
    companyPlan && `plano=${companyPlan}`,
    businessCategory && `categoria=${businessCategory}`,
    mainCnaeDescription && `atividade=${mainCnaeDescription}`,
    mainCnae && `cnae=${mainCnae}`,
    companySize && `porte=${companySize}`,
    legalNature && `natureza=${legalNature}`,
  ].filter(Boolean);

  const userDescriptors = [
    employeeRole && `papel=${employeeRole}`,
    employeeCargo && `cargo=${employeeCargo}`,
    employeeNickname && `apelido=${employeeNickname}`,
    employeeCompensationType && `remuneracao=${employeeCompensationType}`,
  ].filter(Boolean);

  return [
    'Regra de personalizacao por empresa e usuario:',
    '- trate cada conversa como unica para esta empresa e este usuario.',
    '- use primeiro o cadastro da empresa para entender o ramo, a forma de prestacao de servico e o contexto operacional.',
    '- use o cadastro do usuario para entender o papel dele no processo, como owner, gestor, contador, administrativo, equipe de campo ou operacional.',
    '- nunca misture orientacoes de outro perfil, outra empresa ou outra area de atuacao.',
    '- quando a duvida envolver a area de atuacao da empresa, responda com base no cadastro atual, especialmente categoria do negocio, CNAE principal e descricao da atividade.',
    '- quando a duvida envolver o trabalho do usuario, responda com base no papel e no cargo registrados para ele.',
    '- se faltar detalhe no cadastro para responder com seguranca, diga isso claramente, assuma apenas o que estiver salvo e peca complemento objetivo ao usuario.',
    '- voce pode se prontificar a buscar no proprio cadastro, nos modulos ativos e no contexto atual tudo o que ajude a orientar melhor este usuario, mas sem inventar dado que nao recebeu.',
    '- se a duvida estiver relacionada a operacao da empresa e nao estiver totalmente coberta pelo cadastro, voce pode complementar a orientacao com conhecimento geral confiavel do seu modelo, desde que deixe claro quando estiver inferindo.',
    '- quando a resposta depender de validacao externa oficial, como regra fiscal, Receita, eSocial, NFS-e, FGTS, prefeitura, banco ou obrigacao legal, trate a necessidade de fonte oficial como obrigatoria.',
    '- nunca diga que consultou a web, portal oficial ou fonte externa em tempo real se nenhuma ferramenta real de busca tiver sido usada nesta chamada.',
    '- quando faltar confirmacao externa real, responda com cautela, diga o que e orientacao geral e recomende conferencia na fonte oficial competente.',
    '- nunca generalize uma empresa de servico como se fosse comercio, e nunca generalize um contador como se fosse dono da operacao.',
    `Contexto identificado da empresa: ${companyDescriptors.length > 0 ? companyDescriptors.join(' | ') : 'cadastro operacional resumido nao informado nesta chamada'}.`,
    `Contexto identificado do usuario: ${userDescriptors.length > 0 ? userDescriptors.join(' | ') : 'perfil detalhado do usuario nao informado nesta chamada'}.`,
  ].join('\n');
}

function buildAssistantInstructions(params: {
  claims: Claims;
  userProfile: Record<string, unknown>;
  companySettings: Record<string, unknown>;
  route: string;
  screenLabel: string;
  systemIssuesSummary?: string;
  runtimeIncidentsSummary?: string;
}): string {
  const companyName = asTrimmedString(
    params.userProfile.companyName ??
      asRecord(params.userProfile.companyData).nomeFantasia ??
      asRecord(params.userProfile.companyData).razaoSocial,
  );
  const fiscalRouting = asRecord(params.companySettings.fiscalRouting);
  const fiscalIntegration = asRecord(params.companySettings.fiscalRealIntegration);
  const financeMode = asTrimmedString(params.companySettings.financeMode) || 'default';
  const fiscalMode = asTrimmedString(params.companySettings.fiscalMode) || 'default';
  const workforceMode = asTrimmedString(params.companySettings.workforceMode) || 'default';
  const routeType = asTrimmedString(fiscalRouting.routeType);
  const focusApi = asTrimmedString(
    fiscalIntegration.focusNfseApi ?? fiscalRouting.focusNfseApi,
  );
  const companyProfile = asTrimmedString(
    params.companySettings.companyOperationalProfile,
  ) || 'small_business';
  const featureInventory = buildAssistantFeatureInventory();
  const routeGuide = buildAssistantRouteGuide(params.route);
  const faqGuide = buildAssistantFaqGuide();
  const moduleResponseGuide = buildAssistantModuleResponseGuide();
  const businessContextGuide = buildAssistantBusinessContextGuide(
    params.companySettings,
    params.userProfile,
  );

  return [
    'Voce e o Assistente Inteligente do sistema Ponto Certo.',
    'Sua base principal de verdade deve seguir a documentacao oficial do sistema: parte visual, parte funcional, arquitetura tecnica e memoria oficial atual.',
    'Responda sempre somente em portugues do Brasil, de forma objetiva, pratica e segura.',
    'Nunca use ingles, espanhol ou nomes estrangeiros na resposta final quando existir equivalente em portugues.',
    'Use os nomes reais das telas em portugues como resposta principal.',
    'Nao cite rotas tecnicas entre barras, como /tasks, /workforce ou /documents, a menos que o usuario peca explicitamente.',
    'Nunca invente acesso a dados que nao recebeu nesta chamada.',
    'Nunca invente modulo, menu, integracao ou funcionalidade que nao esteja confirmada nesta instrucao.',
    'Se a pergunta pedir algo que nao esteja explicitamente confirmado, diga isso e oriente apenas pelo que existe hoje.',
    'Quando houver risco fiscal, financeiro, juridico ou de seguranca, deixe isso explicito.',
    'Explique o uso do sistema com base no contexto da tela atual quando isso ajudar.',
    isSupremePlatformCompany(params.claims.companyId)
      ? 'Para a empresa suprema, voce tambem atua como apoio de monitoramento operacional: pode resumir incidentes recentes, sugerir diagnostico e indicar a correcao segura recomendada.'
      : 'Para empresas clientes comuns, voce deve focar em orientacao funcional e nao expor diagnosticos internos profundos da plataforma.',
    `Empresa atual: ${companyName || params.claims.companyId}.`,
    `Perfil do usuario: ${params.claims.role}.`,
    `Tela atual: ${params.screenLabel || 'Assistente Inteligente'} (${params.route || '/assistant'}).`,
    `Perfil operacional da empresa: ${companyProfile}.`,
    `Modos ativos: financeiro=${financeMode}, fiscal=${fiscalMode}, trabalhista=${workforceMode}.`,
    `Rota fiscal conhecida: ${routeType || 'nao mapeada'}, Focus API=${focusApi || 'nao definido'}.`,
    featureInventory,
    routeGuide,
    faqGuide,
    moduleResponseGuide,
    businessContextGuide,
    params.systemIssuesSummary
      ? `Problemas conhecidos da empresa: ${params.systemIssuesSummary}`
      : 'Problemas conhecidos da empresa: nenhum resumo ativo nesta chamada.',
    params.runtimeIncidentsSummary
      ? `Incidentes recentes da empresa: ${params.runtimeIncidentsSummary}`
      : 'Incidentes recentes da empresa: nenhum resumo ativo nesta chamada.',
    'Seu papel aqui e orientar o uso do sistema, sugerir proximos passos operacionais e ajudar a redigir documentos.',
    'Ao responder passo a passo, cite apenas os nomes reais das telas em portugues, como Trabalhista, Documentos, Fiscal, Financeiro, Clientes ou Empresa.',
    'Nao altere dados diretamente e nao diga que executou acoes administrativas se nenhuma acao foi feita.',
    'Antes de orientar, alinhe a resposta ao perfil da empresa e ao papel do usuario nesta empresa.',
    'Se o usuario perguntar algo sobre a propria area de atuacao, use o cadastro atual como base principal e deixe explicito quando estiver se apoiando em CNAE, categoria do negocio ou descricao da atividade.',
    'Nunca confunda respostas entre dono, contador, administrativo e equipe operacional.',
    'Se a pergunta sair do que esta no cadastro, mas continuar ligada a operacao real desta empresa, complemente com conhecimento geral prudente e deixe claro o que e inferencia.',
    'Se o tema exigir confirmacao externa oficial e voce nao tiver ferramenta real de busca nesta chamada, diga isso explicitamente e recomende validacao na fonte oficial competente.',
  ].join('\n');
}

async function buildSystemIssuesSummary(companyId: string): Promise<string> {
  const snap = await admin
    .firestore()
    .collection('system_issues')
    .where('companyId', '==', companyId)
    .get();

  if (snap.empty) return '';

  const orderedDocs = [...snap.docs].sort((a, b) => {
    const aData = asRecord(a.data());
    const bData = asRecord(b.data());
    const aLast = aData.lastSeenAt instanceof admin.firestore.Timestamp
      ? aData.lastSeenAt.toMillis()
      : 0;
    const bLast = bData.lastSeenAt instanceof admin.firestore.Timestamp
      ? bData.lastSeenAt.toMillis()
      : 0;
    return bLast - aLast;
  });

  const lines = orderedDocs.slice(0, 5).map((doc) => {
    const data = asRecord(doc.data());
    const title = asTrimmedString(data.title) || 'problema sem titulo';
    const status = asTrimmedString(data.status) || 'open';
    const fixStatus = asTrimmedString(data.fixStatus) || 'pending';
    const occurrences = Number(data.occurrenceCount ?? 0) || 0;
    return `${title} [status=${status}; fix=${fixStatus}; ocorrencias=${occurrences}]`;
  });
  return lines.join(' | ');
}

async function buildRuntimeIncidentsSummary(companyId: string): Promise<string> {
  const snap = await admin
    .firestore()
    .collection('runtime_incidents')
    .where('companyId', '==', companyId)
    .get();

  if (snap.empty) return '';

  const orderedDocs = [...snap.docs].sort((a, b) => {
    const aData = asRecord(a.data());
    const bData = asRecord(b.data());
    const aLast = aData.updatedAt instanceof admin.firestore.Timestamp
      ? aData.updatedAt.toMillis()
      : 0;
    const bLast = bData.updatedAt instanceof admin.firestore.Timestamp
      ? bData.updatedAt.toMillis()
      : 0;
    return bLast - aLast;
  });

  const lines = orderedDocs.slice(0, 5).map((doc) => {
    const data = asRecord(doc.data());
    const source = asTrimmedString(data.source) || 'runtime';
    const category = asTrimmedString(data.category) || 'runtime';
    const status = asTrimmedString(data.status) || 'open';
    const message = asTrimmedString(data.message).replace(/\s+/g, ' ').slice(0, 120) ||
      'incidente sem mensagem';
    return `${category}/${source} [status=${status}] ${message}`;
  });
  return lines.join(' | ');
}

async function writeBackendRuntimeIncident(params: {
  companyId: string;
  reporterUserId: string;
  reporterName: string;
  reporterRole: string;
  source: string;
  category: string;
  severity?: string;
  message: string;
  stackTrace?: string;
  screenLabel?: string;
  route?: string;
  metadata?: Record<string, unknown>;
}): Promise<string> {
  const incidentRef = runtimeIncidentRef(admin.firestore().collection('runtime_incidents').doc().id);
  const baseData: Record<string, unknown> = {
    companyId: params.companyId,
    reporterUserId: params.reporterUserId,
    reporterName: params.reporterName || 'Assistente Inteligente',
    reporterRole: params.reporterRole || 'SYSTEM',
    source: params.source,
    category: params.category,
    severity: params.severity || 'error',
    status: 'open',
    message: params.message,
    stackTrace: params.stackTrace || '',
    screenLabel: params.screenLabel || params.route || 'Assistente Inteligente',
    route: params.route || '/assistant',
    resolutionNote: '',
    autoFixStatus: 'idle',
    autoFixAttempts: 0,
    metadata: params.metadata ?? {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const analysis = analyzeRuntimeIncidentHeuristics(baseData);
  await incidentRef.set({
    ...baseData,
    assistantSummary: analysis.summary,
    recommendedAction: analysis.recommendedAction,
    recommendedActionType: analysis.recommendedActionType,
    autoFixEligible: analysis.autoFixEligible,
    humanApprovalRequired: analysis.humanApprovalRequired,
  });
  return incidentRef.id;
}

async function createOpenAiResponse(params: {
  config: AssistantConfig;
  instructions: string;
  message: string;
  previousResponseId?: string;
  metadata: Record<string, string>;
}): Promise<Record<string, unknown>> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${params.config.apiKey}`,
    },
    body: JSON.stringify({
      model: params.config.model,
      temperature: 0.3,
      messages: [
        {
          role: 'system',
          content: params.instructions,
        },
        {
          role: 'user',
          content: params.message,
        },
      ],
    }),
  });

  const payload = (await response.json()) as Record<string, unknown>;
  if (!response.ok) {
    const errorData = asRecord(payload.error);
    const message =
      asTrimmedString(errorData.message) ||
      'Falha ao consultar o Assistente Inteligente.';
    throw new functions.https.HttpsError('internal', message);
  }

  const choices = Array.isArray(payload.choices) ? payload.choices : [];
  const firstChoice =
    choices.length > 0 ? asRecord(choices[0]) : ({} as Record<string, unknown>);
  const reply = asTrimmedString(asRecord(firstChoice.message).content);

  return {
    id: asTrimmedString(payload.id),
    model: asTrimmedString(payload.model) || params.config.model,
    usage: asRecord(payload.usage),
    output_text: reply,
  };
}

function extractAssistantReply(payload: Record<string, unknown>): string {
  const direct = asTrimmedString(payload.output_text);
  if (direct) return direct;

  const preferredValues: string[] = [];
  const output = Array.isArray(payload.output) ? payload.output : [];
  for (const item of output) {
    const record = asRecord(item);
    const content = Array.isArray(record.content) ? record.content : [];
    for (const part of content) {
      const piece = asRecord(part);
      const candidates = [
        asTrimmedString(piece.output_text),
        asTrimmedString(piece.text),
        asTrimmedString(asRecord(piece.text).value),
        asTrimmedString(piece.value),
        asTrimmedString(piece.refusal),
      ].filter(Boolean);
      preferredValues.push(...candidates);
    }
  }

  if (preferredValues.length > 0) {
    return preferredValues.join('\n').trim();
  }

  return '';
}

function summarizeAssistantPayloadForLogs(payload: Record<string, unknown>): Record<string, unknown> {
  const output = Array.isArray(payload.output) ? payload.output : [];
  return {
    id: asTrimmedString(payload.id),
    model: asTrimmedString(payload.model),
    status: asTrimmedString(payload.status),
    outputTextPresent: !!asTrimmedString(payload.output_text),
    outputCount: output.length,
    outputSummary: output.slice(0, 3).map((item) => {
      const record = asRecord(item);
      const content = Array.isArray(record.content) ? record.content : [];
      return {
        type: asTrimmedString(record.type),
        role: asTrimmedString(record.role),
        contentTypes: content.slice(0, 5).map((part) => {
          const piece = asRecord(part);
          return asTrimmedString(piece.type) || 'unknown';
        }),
        contentPreview: content.slice(0, 2).map((part) => {
          const piece = asRecord(part);
          return (
            asTrimmedString(piece.output_text) ||
            asTrimmedString(piece.text) ||
            asTrimmedString(asRecord(piece.text).value) ||
            asTrimmedString(piece.value) ||
            asTrimmedString(piece.refusal) ||
            ''
          ).slice(0, 160);
        }),
      };
    }),
  };
}

function buildAssistantFallbackReply(payload: Record<string, unknown>): string {
  const summary = summarizeAssistantPayloadForLogs(payload);
  const status = asTrimmedString(summary.status) || 'sem status';
  const model = asTrimmedString(summary.model) || 'modelo nao informado';
  const outputCount = Number(summary.outputCount ?? 0) || 0;
  return [
    'O assistente consumiu a chamada, mas nao retornou texto utilizavel nesta tentativa.',
    `Modelo: ${model}.`,
    `Status: ${status}.`,
    `Itens de saida: ${outputCount}.`,
    'Tente perguntar de forma mais curta e objetiva.',
  ].join(' ');
}

function normalizeOperationNatureCode(value: unknown): string {
  const text = asTrimmedString(value);
  if (!text) return '1';
  if (/^[0-9]+$/.test(text)) {
    return text;
  }
  const normalized = text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
  if (
    normalized.includes('fora do municipio') ||
    normalized.includes('local da execucao') ||
    normalized.includes('local da incidencia') ||
    normalized.includes('tomador')
  ) {
    return '2';
  }
  return '1';
}

function maskSecret(value: string): string {
  if (!value) return '';
  if (value.length <= 6) return '***';
  return `${value.substring(0, 3)}***${value.substring(value.length - 3)}`;
}

function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof functions.https.HttpsError) {
    return error.message || fallback;
  }
  if (error instanceof Error) {
    return error.message || fallback;
  }
  const text = String(error ?? '').trim();
  return text || fallback;
}

/** Texto concatenado para classificar falhas IAM (mensagem as vezes nao esta em Error.message). */
function collectErrorTextDeep(error: unknown): string {
  const chunks: string[] = [];
  const push = (s: string) => {
    const t = String(s ?? '').trim();
    if (!t || chunks.some((existing) => existing.includes(t))) {
      return;
    }
    chunks.push(t);
  };
  push(errorMessage(error, ''));
  if (error && typeof error === 'object') {
    const any = error as Record<string, unknown>;
    for (const k of ['message', 'code', 'status', 'details'] as const) {
      const v = any[k];
      if (typeof v === 'string') {
        push(v);
      }
    }
    const ei = any['errorInfo'];
    if (ei && typeof ei === 'object') {
      const r = ei as Record<string, unknown>;
      if (typeof r['message'] === 'string') {
        push(r['message']);
      }
      if (typeof r['code'] === 'string') {
        push(r['code']);
      }
    }
    try {
      push(JSON.stringify(error));
    } catch (_) {
      /* ignored */
    }
  }
  return chunks.join('\n').toLowerCase();
}

/** createCustomToken / algumas operacoes Admin Auth exigem signBlob no runtime das Functions. */
function isLikelyFirebaseAdminIamSigningError(error: unknown): boolean {
  const blob = collectErrorTextDeep(error);
  return (
    blob.includes('signblob') ||
    blob.includes('service_account_token_creator') ||
    blob.includes('iam.serviceaccounts.sign') ||
    blob.includes('serviceaccounttokencreator') ||
    /permission[^\n]*iam\.serviceaccounts/i.test(blob)
  );
}

function runtimeIncidentRef(incidentId: string): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('runtime_incidents').doc(incidentId);
}

function systemIssueRef(issueId: string): FirebaseFirestore.DocumentReference {
  return admin.firestore().collection('system_issues').doc(issueId);
}

function buildSystemIssueFingerprint(incidentData: Record<string, unknown>): string {
  const companyId = asTrimmedString(incidentData.companyId);
  const source = asTrimmedString(incidentData.source).toLowerCase();
  const category = asTrimmedString(incidentData.category).toLowerCase();
  const screenLabel = asTrimmedString(incidentData.screenLabel).toLowerCase();
  const message = asTrimmedString(incidentData.message)
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .slice(0, 180);
  return [companyId, source, category, screenLabel, message].join('|');
}

type RuntimeIncidentAnalysis = {
  summary: string;
  recommendedAction: string;
  recommendedActionType: string;
  autoFixEligible: boolean;
  humanApprovalRequired: boolean;
  severity: string;
};

function analyzeRuntimeIncidentHeuristics(
  incidentData: Record<string, unknown>,
): RuntimeIncidentAnalysis {
  const message = asTrimmedString(incidentData.message).toLowerCase();
  const source = asTrimmedString(incidentData.source).toLowerCase();
  const category = asTrimmedString(incidentData.category).toLowerCase();
  const stack = asTrimmedString(incidentData.stackTrace).toLowerCase();
  const joined = `${message} ${source} ${category} ${stack}`;

  if (
    joined.includes('focus') ||
    joined.includes('provision') ||
    joined.includes('nfse') ||
    joined.includes('certificado') ||
    joined.includes('token da focus') ||
    joined.includes('municipio')
  ) {
    return {
      summary:
        'Falha classificada como fiscal/integracao. O caminho mais seguro e reprocessar o provisionamento fiscal da empresa antes de qualquer nova emissao.',
      recommendedAction:
        'Reprocessar a automacao fiscal da empresa e revisar token, certificado e rota fiscal recomendada.',
      recommendedActionType: 'refresh_fiscal_provisioning',
      autoFixEligible: true,
      humanApprovalRequired: false,
      severity: 'warning',
    };
  }

  if (
    joined.includes('permission') ||
    joined.includes('permissao') ||
    joined.includes('permission-denied') ||
    joined.includes('custom claims') ||
    joined.includes('unauthenticated')
  ) {
    return {
      summary:
        'Falha classificada como permissao/acesso. O sistema nao deve tentar corrigir isso sozinho sem revisao humana.',
      recommendedAction:
        'Revisar perfil, claims e regras de acesso da empresa antes de repetir a operacao.',
      recommendedActionType: 'review_permissions',
      autoFixEligible: false,
      humanApprovalRequired: true,
      severity: 'warning',
    };
  }

  if (
    joined.includes('timeout') ||
    joined.includes('socketexception') ||
    joined.includes('network') ||
    joined.includes('connection') ||
    joined.includes('fetch')
  ) {
    return {
      summary:
        'Falha classificada como conectividade temporaria. A recomendacao e repetir a operacao apos conferir internet e disponibilidade do servico externo.',
      recommendedAction:
        'Tentar novamente a operacao apos validar conectividade e disponibilidade do integrador.',
      recommendedActionType: 'retry_manual',
      autoFixEligible: false,
      humanApprovalRequired: true,
      severity: 'warning',
    };
  }

  if (
    joined.includes('openai') ||
    joined.includes('api key') ||
    joined.includes('token da openai') ||
    joined.includes('assistente nao configurado')
  ) {
    return {
      summary:
        'Falha classificada como configuracao do assistente. Nao ha correcao automatica segura sem revisar a chave e a franquia da empresa.',
      recommendedAction:
        'Revisar o token da OpenAI e a governanca do assistente na tela da empresa.',
      recommendedActionType: 'review_assistant_token',
      autoFixEligible: false,
      humanApprovalRequired: true,
      severity: 'warning',
    };
  }

  return {
    summary:
      'Falha classificada como incidente generico de aplicacao. O sistema registrou a ocorrencia, mas ainda nao ha playbook automatico seguro para este caso.',
    recommendedAction:
      'Analisar a mensagem, a tela e o stack trace antes de decidir uma acao manual.',
    recommendedActionType: 'manual_review',
    autoFixEligible: false,
    humanApprovalRequired: true,
    severity: asTrimmedString(incidentData.severity) || 'error',
  };
}

function focusProviderErrorMessage(
  data: Record<string, unknown>,
  fallback: string,
): string {
  const direct =
    asTrimmedString(data.mensagem) ||
    asTrimmedString(data.message) ||
    asTrimmedString(data.erro) ||
    asTrimmedString(data.error);
  const details = data.erros ?? data.errors ?? data.detalhes ?? data.details;
  const detailText = focusProviderErrorDetailsText(details);
  const rawMessage = direct || detailText || fallback;
  const classified = classifyFocusProviderError(rawMessage, detailText);
  return classified || rawMessage;
}

function focusProviderErrorDetailsText(details: unknown): string {
  if (Array.isArray(details)) {
    const text = details
      .map((item) => {
        if (typeof item === 'string') return item.trim();
        if (item && typeof item === 'object') {
          const record = item as Record<string, unknown>;
          return [
            asTrimmedString(record.codigo),
            asTrimmedString(record.code),
            asTrimmedString(record.mensagem),
            asTrimmedString(record.message),
            asTrimmedString(record.erro),
            asTrimmedString(record.error),
            asTrimmedString(record.campo),
          ]
            .filter((value) => value.length > 0)
            .join(' ');
        }
        return '';
      })
      .filter((item) => item.length > 0)
      .join(' | ');
    if (text) return text;
  }

  if (details && typeof details === 'object') {
    const text = Object.entries(details as Record<string, unknown>)
      .map(([key, value]) => `${key}: ${asTrimmedString(value)}`)
      .filter((item) => item.length > 2)
      .join(' | ');
    if (text) return text;
  }

  return '';
}

function classifyFocusProviderError(rawMessage: string, detailsText = ''): string {
  const raw = asTrimmedString(rawMessage);
  if (!raw) return '';

  const normalized = normalizeFocusText(`${raw} ${detailsText}`);
  const codeMatch = raw.match(/\bE\d{4}\b/i);
  const code = codeMatch ? codeMatch[0].toUpperCase() : '';
  const detailSuffix =
    raw && raw !== detailsText ? ` Detalhe Focus: ${raw}` : '';

  if (
    code === 'E0310' ||
    normalized.includes('codigo de tributacao nacional') ||
    normalized.includes('codigo_tributacao_nacional_iss') ||
    normalized.includes('ctribnac') ||
    normalized.includes('nbs')
  ) {
    return (
      'Codigo de tributacao nacional do ISS invalido para a NFS-e Nacional. ' +
      'Revise o servico com codigo nacional no padrao XX.XX.XX e CNAE com 7 digitos.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('codigo_tributario_municipio') ||
    normalized.includes('codigo tributario municipio') ||
    normalized.includes('ctribmun')
  ) {
    return (
      'Codigo tributario municipal invalido para a prefeitura configurada. ' +
      'Revise o codigo municipal do servico conforme o cadastro aceito pela Focus para esse municipio.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('item_lista_servico') ||
    normalized.includes('item lista servico') ||
    normalized.includes('lista de servico')
  ) {
    return (
      'Item da lista de servico invalido. Revise a classificacao do servico conforme LC 116 e a rota fiscal da empresa.' +
      detailSuffix
    );
  }

  if (normalized.includes('cnae')) {
    return (
      'CNAE invalido para emissao. Revise o CNAE principal do servico no padrao de 7 digitos.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('inscricao municipal') ||
    normalized.includes('inscricao_municipal') ||
    normalized.includes('im do prestador')
  ) {
    return (
      'Inscricao municipal do prestador invalida ou nao habilitada no provedor. ' +
      'Revise o cadastro fiscal da empresa antes de emitir.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('certificado') ||
    normalized.includes('a1') ||
    normalized.includes('cnpj do certificado')
  ) {
    return (
      'Certificado digital invalido, expirado ou divergente do CNPJ da empresa. ' +
      'Revise o certificado A1 e a senha cadastrada na Focus.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('logradouro_tomador') ||
    normalized.includes('numero_tomador') ||
    normalized.includes('endereco do tomador') ||
    (normalized.includes('tomador') && normalized.includes('numero')) ||
    (normalized.includes('bairro') && normalized.includes('element'))
  ) {
    return (
      'Endereco do tomador incompleto para o layout fiscal exigido. ' +
      'Revise logradouro, numero, bairro, CEP e municipio do cliente.' +
      detailSuffix
    );
  }

  if (normalized.includes('cno') || normalized.includes('obra')) {
    return (
      'Dados da obra invalidos ou incompletos para esse codigo de servico. ' +
      'Revise CNO e endereco da obra antes de emitir.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('duplic') ||
    normalized.includes('ja existe') ||
    normalized.includes('já existe') ||
    (normalized.includes('referencia') && normalized.includes('existe'))
  ) {
    return (
      'Ja existe uma solicitacao fiscal com essa referencia na Focus. ' +
      'Consulte a nota existente antes de tentar reenviar.' +
      detailSuffix
    );
  }

  if (normalized.includes('processando') || normalized.includes('processing')) {
    return (
      'A nota ainda esta em processamento na Focus. Aguarde a conciliacao e atualize o status antes de reenviar.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('aliquot') ||
    normalized.includes('alíquota') ||
    normalized.includes('aliquota') ||
    (normalized.includes('iss') && (normalized.includes('minim') || normalized.includes('1,8') || normalized.includes('1.8') || normalized.includes('180'))) ||
    (normalized.includes('simples') && normalized.includes('retid'))
  ) {
    return (
      'Regra de aliquota do ISS incompativel com a retencao e o regime. ' +
      'No Simples com ISS retido na NFS-e Nacional, a aliquota do municipio nao pode ficar abaixo de 1,80%.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('inss') ||
    normalized.includes('previd') ||
    normalized.includes('contribut') ||
    normalized.includes('valor_cp') ||
    normalized.includes('csll') ||
    normalized.includes('cofins') ||
    normalized.includes('pis') ||
    normalized.includes('reten')
  ) {
    return (
      'A Focus rejeitou valores de retencoes (INSS/CP, federais ou congeneres) ou regras incompativeis. ' +
      'Revise retencao de INSS, base e valores com o contador, e a consistencia de valor liquido x ISS/INSS.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('autentic') ||
    normalized.includes('autoriz') ||
    normalized.includes('nao autori') ||
    normalized.includes('token') ||
    normalized.includes('chave de api') ||
    normalized.includes('forbidden') ||
    normalized.includes('nao informado') && normalized.includes('ambiente') ||
    normalized.includes('produc') && (normalized.includes('habilit') || normalized.includes('homolog')) ||
    (normalized.includes('http') && (normalized.includes('401') || normalized.includes('403') || normalized.includes('429')))
  ) {
    return (
      'Falha de autenticacao, token ou habilitacao de ambiente na Focus. ' +
      'Verifique o token, se o ambiente (homologacao x producao) bate com o contrato, e tente de novo com intervalo (limite/429).' +
      detailSuffix
    );
  }

  if (normalized.includes('ibge') || (normalized.includes('municipio') && normalized.includes('nao encont'))) {
    return (
      'Cidade, UF ou codigo de municipio (IBGE) nao puderam ser resolvidos para a Focus. ' +
      'Ajuste nome do municipio, sigla e CEP, sem abreviacoes ambiguas.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('time') ||
    normalized.includes('timeout') ||
    normalized.includes('etimedout') ||
    normalized.includes('econnreset') ||
    normalized.includes('indispon')
  ) {
    return (
      'Houve falha de rede ou o servico da Focus nao respondeu a tempo. ' +
      'Aguarde e consulte a nota; evite reenvio duplicado no mesmo id/referencia.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('competenc') ||
    normalized.includes('data de') ||
    normalized.includes('nao e permitid') && normalized.includes('data')
  ) {
    return (
      'A Focus rejeitou data de emissao ou de competencia. Ajuste competencia, fuso/horario e o calendario fiscal do municipio.' +
      detailSuffix
    );
  }

  if (
    normalized.includes('schema') ||
    normalized.includes('not expected') ||
    normalized.includes('element') ||
    normalized.includes('xml')
  ) {
    return (
      'A Focus rejeitou o layout da NFS-e por combinacao invalida de campos. ' +
      'Revise a preparacao da nota conforme a rota municipal ou nacional da empresa.' +
      detailSuffix
    );
  }

  return '';
}

function extractFocusRejectionErrorCode(
  data: Record<string, unknown>,
  messageForUser: string,
): string {
  const fromUser = (messageForUser || '').match(/\bE\d{4}\b/i);
  if (fromUser) {
    return fromUser[0].toUpperCase();
  }
  const detailStr = focusProviderErrorDetailsText(
    data?.erros ?? data?.errors ?? data?.detalhes ?? data?.details,
  );
  const fromDetails = (detailStr || '').match(/\bE\d{4}\b/i);
  if (fromDetails) {
    return fromDetails[0].toUpperCase();
  }
  const rawCode =
    asTrimmedString((data as Record<string, unknown>).codigo) ||
    asTrimmedString((data as Record<string, unknown>).code);
  const fromRoot = rawCode.match(/\bE\d{4}\b/i);
  if (fromRoot) {
    return fromRoot[0].toUpperCase();
  }
  return 'UNKNOWN';
}

/**
 * Contagem anonima (sem empresa) para priorizar ajustes de mensagem/checagens.
 * documento: fiscal_telemetry_v1/aggregates/{yyyy-mm-dd}__E####__municipal|national
 */
function recordFocusRejectionTelemetry(params: {
  httpStatus: number;
  data: Record<string, unknown>;
  messageForUser: string;
  apiMode: 'municipal' | 'national';
}): void {
  const code = extractFocusRejectionErrorCode(params.data, params.messageForUser);
  void (async () => {
    try {
      const d = new Date();
      const dayKey = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(
        d.getUTCDate(),
      ).padStart(2, '0')}`;
      const id = `${dayKey}__${code}__${params.apiMode}`.replace(/[/#]/g, '_');
      await admin
        .firestore()
        .doc(`fiscal_telemetry_v1/aggregates/${id}`)
        .set(
          {
            dayKey,
            errorCode: code,
            apiMode: params.apiMode,
            count: admin.firestore.FieldValue.increment(1),
            lastHttpStatus: params.httpStatus,
            lastAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
    } catch (e) {
      functions.logger.warn('fiscal_telemetry_v1 aggregate write failed', {
        err: String(e),
      });
    }
  })();
}

function providerIsFocus(provider: string): boolean {
  const normalized = provider
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
  return normalized.includes('focus');
}

function normalizeFocusText(value: unknown): string {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function focusNfseApiMode(setup: Record<string, unknown>): 'municipal' | 'national' {
  const explicit =
    normalizeFocusText(setup.focusNfseApi) ||
    normalizeFocusText(setup.nfseApiMode) ||
    normalizeFocusText(setup.focusEmissionMode);
  if (
    explicit.includes('nacional') ||
    explicit.includes('national') ||
    explicit.includes('nfsen')
  ) {
    return 'national';
  }

  const provider = normalizeFocusText(setup.provider);
  if (provider.includes('nacional') || provider.includes('nfsen')) {
    return 'national';
  }
  return 'municipal';
}

function focusProviderLabel(setup: Record<string, unknown>): string {
  return focusNfseApiMode(setup) === 'national'
    ? 'Focus NFe Nacional'
    : 'Focus NFe';
}

function normalizeOfficialInvoiceStatus(
  rawStatus: unknown,
  provider: unknown,
  fallback = 'DRAFT',
): string {
  const providerText = normalizeFocusText(provider);
  const status = normalizeFocusText(rawStatus);
  if (!status) return fallback;

  if (providerText.includes('focus')) {
    if (
      status === 'processando' ||
      status === 'processing' ||
      status === 'em_processamento' ||
      status === 'pendente'
    ) {
      return 'PROCESSING';
    }
    if (
      status === 'autorizado' ||
      status === 'autorizada' ||
      status === 'autorizados' ||
      status === 'autorizadas' ||
      status === 'authorized' ||
      status === 'aprovada' ||
      status === 'aprovado' ||
      status === 'aprovados' ||
      status === 'aprovadas'
    ) {
      return 'APPROVED';
    }
    if (
      status === 'emitido' ||
      status === 'emitida' ||
      status === 'emitidos' ||
      status === 'emitidas' ||
      status === 'concluida' ||
      status === 'concluido' ||
      status === 'disponivel' ||
      status === 'registrada' ||
      status === 'registrado' ||
      status === 'succeeded' ||
      status === 'success' ||
      status === 'concluidos'
    ) {
      return 'APPROVED';
    }
    if (status === 'cancelado' || status === 'cancelada' || status === 'canceled') {
      return 'CANCELED';
    }
    if (
      status === 'erro' ||
      status === 'error' ||
      status === 'rejeitado' ||
      status === 'rejeitada' ||
      status === 'failed'
    ) {
      return 'FAILED';
    }
  }

  return asUpperStatus(status, fallback);
}

function focusServerBase(environment: string): string {
  return environment.trim().toLowerCase() === 'producao'
    ? 'https://api.focusnfe.com.br'
    : 'https://homologacao.focusnfe.com.br';
}

function focusAuthHeader(token: string): string {
  return `Basic ${Buffer.from(`${token}:`).toString('base64')}`;
}

async function focusRequest(params: {
  token: string;
  environment: string;
  path: string;
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: Record<string, unknown>;
}): Promise<{ status: number; data: Record<string, unknown> }> {
  const token = asTrimmedString(params.token);
  if (!token) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Token da Focus NFe nao configurado.',
    );
  }

  const response = await fetch(`${focusServerBase(params.environment)}${params.path}`, {
    method: params.method ?? 'GET',
    headers: {
      authorization: focusAuthHeader(token),
      'content-type': 'application/json',
    },
    body: params.body ? JSON.stringify(params.body) : undefined,
  });

  const rawText = await response.text();
  let data: Record<string, unknown> = {};
  if (rawText.trim().length > 0) {
    try {
      data = asRecord(JSON.parse(rawText));
    } catch (_) {
      data = { rawText };
    }
  }

  if (!response.ok && response.status != 422 && response.status != 400) {
    const message =
      asTrimmedString(data.mensagem) ||
      asTrimmedString(data.message) ||
      asTrimmedString(data.erro) ||
      rawText.trim();
    throw new functions.https.HttpsError(
      'internal',
      message || `Falha na Focus NFe (${response.status}).`,
    );
  }

  return { status: response.status, data };
}

async function focusRequestAny(params: {
  token: string;
  environment: string;
  path: string;
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: Record<string, unknown>;
  accept?: string;
  contentType?: string;
}): Promise<{status: number; data: unknown; rawText: string; headers: Headers}> {
  const token = asTrimmedString(params.token);
  if (!token) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Token da Focus NFe nao configurado.',
    );
  }

  const response = await fetch(`${focusServerBase(params.environment)}${params.path}`, {
    method: params.method ?? 'GET',
    headers: {
      authorization: focusAuthHeader(token),
      accept: params.accept || 'application/json',
      ...(params.contentType
        ? {'content-type': params.contentType}
        : {}),
    },
    body: params.body ? JSON.stringify(params.body) : undefined,
  });

  const rawText = await response.text();
  let data: unknown = {};
  if (rawText.trim().length > 0) {
    const contentType = response.headers.get('content-type') || '';
    if (
      contentType.toLowerCase().includes('application/json') ||
      rawText.trim().startsWith('{') ||
      rawText.trim().startsWith('[')
    ) {
      try {
        data = JSON.parse(rawText);
      } catch (_) {
        data = {rawText};
      }
    } else {
      data = rawText;
    }
  }

  if (!response.ok && response.status != 422 && response.status != 400) {
    const dataRecord = asRecord(data);
    const message =
      asTrimmedString(dataRecord.mensagem) ||
      asTrimmedString(dataRecord.message) ||
      asTrimmedString(dataRecord.erro) ||
      rawText.trim();
    throw new functions.https.HttpsError(
      'internal',
      message || `Falha na Focus NFe (${response.status}).`,
    );
  }

  return {status: response.status, data, rawText, headers: response.headers};
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function saoPauloDateParts(date: Date): Record<string, string> {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  });
  const parts = formatter.formatToParts(date);
  const map: Record<string, string> = {};
  for (const part of parts) {
    if (part.type !== 'literal') {
      map[part.type] = part.value;
    }
  }
  return map;
}

function formatSaoPauloDateTime(date: Date): string {
  const parts = saoPauloDateParts(date);
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}-03:00`;
}

function formatSaoPauloDate(date: Date): string {
  const parts = saoPauloDateParts(date);
  return `${parts.year}-${parts.month}-${parts.day}`;
}

/**
 * Preenchimento do DPS: opSimpNac deve ser coerente com o cadastro do Simples Nacional
 * (erro Sefin E0160). O catalogo/linha do servico pode dizer "Simples" e o CNPJ ser MEI
 * (ou o inverso); a Receita compara o prestador. Por isso o regime do emitente
 * (empresa) prevalece quando preenchido; a linha so entra se o emitente nao tiver
 * regime util (ou so placeholder).
 */
function resolveFocusNationalTaxRegimeForSimples(
  invoiceTaxRegime: string,
  emitterTaxRegime: string,
): string {
  const em = asTrimmedString(emitterTaxRegime);
  if (em.length > 0) {
    return em;
  }
  const inv = asTrimmedString(invoiceTaxRegime);
  const invNorm = normalizeFocusText(inv);
  const looksPlaceholder =
    invNorm.includes('validar com contador') ||
    invNorm === 'a definir' ||
    invNorm === '-' ||
    invNorm === 'nao informado' ||
    invNorm === 'regime a validar';
  if (inv.length > 0 && !looksPlaceholder) {
    return inv;
  }
  return inv;
}

function readFocusNationalSimplesNacionalOverride(
  tax: Record<string, unknown>,
): 1 | 2 | 3 | null {
  const v =
    (tax as { opcaoSimplesNacional?: unknown; simplesNacionalOption?: unknown })
      .opcaoSimplesNacional ?? (tax as { simplesNacionalOption?: unknown })
      .simplesNacionalOption;
  if (v == null) {
    return null;
  }
  const n = Number(v);
  if (n === 1 || n === 2 || n === 3) {
    return n;
  }
  return null;
}

function taxRegimeTextForFocusSimpleOverride(code: 1 | 2 | 3): string {
  if (code === 2) {
    return 'mei';
  }
  if (code === 3) {
    return 'simples nacional';
  }
  return 'lucro presumido';
}

/**
 * Corpo + complemento (sem banco) e rodape com dados bancarios do emitente (fiscal).
 */
function buildFocusInvoiceServiceDescription(
  data: Record<string, unknown>,
  service: Record<string, unknown>,
  emitter: Record<string, unknown>,
): string {
  const baseServiceDesc =
    asTrimmedString(
      (data as { fiscalServiceBaseDescription?: unknown })
        .fiscalServiceBaseDescription,
    ) || asTrimmedString(service.description || data.serviceDescription);
  const serviceComplement = asTrimmedString(
    (data as { serviceDescriptionComplement?: unknown })
      .serviceDescriptionComplement,
  );
  const serviceBodyNoBank = [baseServiceDesc, serviceComplement]
    .filter((s) => s.length > 0)
    .join('\n\n');
  const paymentBank = asTrimmedString(
    (emitter as { fiscalPaymentBankInfo?: unknown }).fiscalPaymentBankInfo,
  );
  return paymentBank
    ? serviceBodyNoBank
      ? `${serviceBodyNoBank}\n\n${paymentBank}`
      : paymentBank
    : serviceBodyNoBank;
}

function focusNationalSimpleOptionCode(taxRegime: string): number {
  const normalized = normalizeFocusText(taxRegime);
  if (normalized.includes('mei')) return 2;
  if (normalized.includes('simples')) return 3;
  return 1;
}

function focusNationalSimpleTaxRegimeCode(taxRegime: string): number | null {
  const normalized = normalizeFocusText(taxRegime);
  if (normalized.includes('simples')) {
    return 1;
  }
  return null;
}

function normalizeFocusNationalRetainedIssRate(params: {
  issRate: number;
  issRetained: boolean;
  taxRegime: string;
}): number {
  const simpleOptionCode = focusNationalSimpleOptionCode(params.taxRegime);
  const simpleTaxRegimeCode = focusNationalSimpleTaxRegimeCode(params.taxRegime);
  const requiresNationalMinimumRate =
    params.issRetained &&
    simpleOptionCode === 3 &&
    simpleTaxRegimeCode === 1;
  if (!requiresNationalMinimumRate) {
    return params.issRate;
  }
  return Math.max(params.issRate, 1.8);
}

async function resolveFocusMunicipalityCode(params: {
  token: string;
  environment: string;
  city: string;
  state: string;
}): Promise<string> {
  const city = asTrimmedString(params.city);
  const state = asTrimmedString(params.state).toUpperCase();
  if (!city || !state) return '';
  const query = new URLSearchParams({
    nome_municipio: city,
    sigla_uf: state,
  });
  const response = await focusRequest({
    token: params.token,
    environment: params.environment,
    path: `/v2/municipios?${query.toString()}`,
  });
  const raw = response.data;
  if (Array.isArray(raw)) {
    const first = raw[0];
    if (first && typeof first === 'object') {
      return asTrimmedString((first as Record<string, unknown>).codigo_municipio);
    }
  }
  return '';
}

function focusRegimeTributario(companyData: Record<string, unknown>): string {
  const regime = asTrimmedString(companyData.regimeTributario).toLowerCase();
  if (regime.includes('simples') || regime.includes('mei')) return '1';
  if (regime.includes('lucro presumido')) return '2';
  return '3';
}

function companyIsServiceBusiness(companyData: Record<string, unknown>): boolean {
  if (companyData.inscricaoEstadualDispensada === true) {
    return true;
  }
  const businessCategory = asTrimmedString(companyData.businessCategory).toLowerCase();
  if (businessCategory === 'service') {
    return true;
  }
  const mainCnaeDescription = asTrimmedString(companyData.mainCnaeDescription).toLowerCase();
  return mainCnaeDescription.includes('servic');
}

function inferCompanyTaxRegime(companyData: Record<string, unknown>): string {
  const explicit = asTrimmedString(companyData.regimeTributario);
  if (explicit) return explicit;
  const legalNature = asTrimmedString(companyData.legalNature).toLowerCase();
  const companySize = asTrimmedString(companyData.companySize).toLowerCase();
  if (legalNature.includes('mei')) return 'MEI / Simples Nacional';
  if (companySize.includes('micro') || companySize.includes('pequeno')) {
    return 'Simples Nacional';
  }
  return 'Regime a validar com contador';
}

function classifyDirectSignupCompany(params: {
  legalNature: unknown;
  companySize: unknown;
  mainCnaeDescription?: unknown;
}): {
  companyType: 'MEI' | 'EMPRESA';
  companyPlan: 'SOLO' | 'EQUIPE';
  businessTier: 'mei' | 'empresa';
  seatsIncluded: number;
  reason: string;
  validationLabel: string;
} {
  const legalNature = normalizeFocusText(params.legalNature);
  const companySize = normalizeFocusText(params.companySize);
  const mainCnaeDescription = normalizeFocusText(params.mainCnaeDescription);
  const legalNatureSignals = [
    'microempreendedor individual',
    'mei',
  ];
  const companySizeSignals = [
    'microempreendedor individual',
  ];
  const isMei =
    legalNatureSignals.some((item) => legalNature.includes(item)) ||
    companySizeSignals.some((item) => companySize.includes(item));

  if (isMei) {
    return {
      companyType: 'MEI',
      companyPlan: 'SOLO',
      businessTier: 'mei',
      seatsIncluded: 1,
      reason:
        'Classificacao oficial do CNPJ indica MEI. O sistema aplica fluxo Solo com 1 acesso base.',
      validationLabel:
        'Validacao oficial: natureza juridica e porte retornados na consulta do CNPJ.',
    };
  }

  return {
    companyType: 'EMPRESA',
    companyPlan: 'EQUIPE',
    businessTier: 'empresa',
    seatsIncluded: 3,
    reason:
      mainCnaeDescription
        ? `O CNPJ nao foi identificado como MEI. O sistema trata a empresa como operacao de equipe e usa o plano Equipe. CNAE principal lido: ${mainCnaeDescription}.`
        : 'O CNPJ nao foi identificado como MEI. O sistema trata a empresa como operacao de equipe e usa o plano Equipe.',
    validationLabel:
      'Validacao oficial: natureza juridica, porte e atividade principal retornados na consulta do CNPJ.',
  };
}

function buildEmitterPayloadFromCompanyData(
  companyData: Record<string, unknown>,
): Record<string, unknown> {
  const legalName =
    asTrimmedString(companyData.razaoSocial) ||
    asTrimmedString(companyData.nomeFantasia);
  const tradeName = asTrimmedString(companyData.nomeFantasia);
  const cnpj = asTrimmedString(companyData.cnpj);
  const stateRegistration = asTrimmedString(companyData.inscricaoEstadual);
  const municipalRegistration = sanitizeMunicipalRegistrationFromCnpj(
    companyData.inscricaoMunicipal,
    companyData,
  );
  const email = asTrimmedString(companyData.email).toLowerCase();
  const phone = asTrimmedString(companyData.telefone);
  const zipCode = asTrimmedString(companyData.cep);
  const street = asTrimmedString(companyData.rua || companyData.endereco);
  const number = asTrimmedString(companyData.numero);
  const complement = asTrimmedString(companyData.complemento);
  const neighborhood = asTrimmedString(companyData.bairro);
  const city = asTrimmedString(companyData.cidade);
  const state = asTrimmedString(companyData.estado).toUpperCase();
  const mainCnae = asTrimmedString(companyData.mainCnae);
  const mainCnaeDescription = asTrimmedString(companyData.mainCnaeDescription);
  const legalNature = asTrimmedString(companyData.legalNature);
  const taxRegime = inferCompanyTaxRegime(companyData);
  const municipalCode = companyIbgeCode(companyData);

  return {
    legalName,
    tradeName,
    razaoSocial: legalName,
    nomeFantasia: tradeName,
    cnpj,
    document: cnpj,
    stateRegistration,
    inscricaoEstadual: stateRegistration,
    municipalRegistration,
    inscricaoMunicipal: municipalRegistration,
    email,
    phone,
    telefone: phone,
    zipCode,
    cep: zipCode,
    street,
    logradouro: street,
    number,
    complement,
    complemento: complement,
    neighborhood,
    bairro: neighborhood,
    city,
    state,
    codigoMunicipio: municipalCode,
    mainCnae,
    mainCnaeDescription,
    legalNature,
    taxRegime,
  };
}

async function buildFocusCompanyPayload(params: {
  companyData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
  token: string;
  environment: string;
  certificateBase64?: string;
}): Promise<Record<string, unknown>> {
  const companyData = params.companyData;
  const settingsData = params.settingsData;
  const setup = asRecord(settingsData.fiscalRealIntegration);
  const certificate = asRecord(settingsData.fiscalCertificate);
  const nfseApiMode = focusNfseApiMode(setup);
  const municipalityCode =
    asTrimmedString(companyData.codigoMunicipio) ||
    asTrimmedString(companyData.cityCode) ||
    (await resolveFocusMunicipalityCode({
      token: params.token,
      environment: params.environment,
      city: asTrimmedString(companyData.cidade),
      state: asTrimmedString(companyData.estado),
    })) ||
    companyIbgeCode(companyData);
  const nationalEnabled = nfseApiMode === 'national';

  const payload: Record<string, unknown> = {
    nome: asTrimmedString(companyData.razaoSocial || companyData.nomeFantasia),
    nome_fantasia: asTrimmedString(companyData.nomeFantasia),
    cnpj: onlyDigits(companyData.cnpj),
    inscricao_municipal: sanitizeMunicipalRegistrationFromCnpj(
      companyData.inscricaoMunicipal,
      companyData,
    ),
    cep: onlyDigits(companyData.cep),
    bairro: asTrimmedString(companyData.bairro),
    logradouro: asTrimmedString(companyData.rua || companyData.endereco),
    numero: asTrimmedString(companyData.numero),
    complemento: asTrimmedString(companyData.complemento),
    municipio: asTrimmedString(companyData.cidade),
    codigo_municipio: municipalityCode,
    uf: asTrimmedString(companyData.estado).toUpperCase(),
    email: asTrimmedString(companyData.email).toLowerCase(),
    telefone: onlyDigits(companyData.telefone),
    regime_tributario: focusRegimeTributario(companyData),
    habilita_nfse: !nationalEnabled,
    habilita_nfsen: nationalEnabled,
    habilita_nfsen_homologacao: nationalEnabled,
    habilita_nfsen_producao: nationalEnabled,
  };

  if (!companyIsServiceBusiness(companyData)) {
    payload.inscricao_estadual = asTrimmedString(companyData.inscricaoEstadual);
  }

  if (params.certificateBase64 && params.certificateBase64.trim().length > 0) {
    payload.arquivo_certificado_base64 = params.certificateBase64.trim();
  }
  if (asTrimmedString(certificate.password)) {
    payload.senha_certificado = asTrimmedString(certificate.password);
  }
  if (asTrimmedString(certificate.loginResponsavel)) {
    payload.login_responsavel = asTrimmedString(certificate.loginResponsavel);
  }
  if (asTrimmedString(certificate.senhaResponsavel)) {
    payload.senha_responsavel = asTrimmedString(certificate.senhaResponsavel);
  }

  return payload;
}

async function downloadCertificateBase64(
  settingsData: Record<string, unknown>,
): Promise<string> {
  const certificate = asRecord(settingsData.fiscalCertificate);
  const storagePath = asTrimmedString(certificate.storagePath);
  if (!storagePath) return '';
  const [bytes] = await admin.storage().bucket().file(storagePath).download();
  return Buffer.from(bytes).toString('base64');
}

async function syncFocusCompany(params: {
  claims: Claims;
  companyData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
}): Promise<Record<string, unknown>> {
  const setup = asRecord(params.settingsData.fiscalRealIntegration);
  const certificate = asRecord(params.settingsData.fiscalCertificate);
  const platformFocus = obterConfigFocusPlatform();
  const token = asTrimmedString(setup.apiToken) || platformFocus.apiToken;
  const environment = asTrimmedString(setup.environment) || platformFocus.environment || 'homologacao';
  const focusCompanyId = asTrimmedString(params.settingsData.focusCompanyId);
  const certificateBase64 = await downloadCertificateBase64(params.settingsData);
  const payload = await buildFocusCompanyPayload({
    companyData: params.companyData,
    settingsData: params.settingsData,
    token,
    environment,
    certificateBase64,
  });

  const response = await focusRequest({
    token,
    environment,
    method: focusCompanyId ? 'PUT' : 'POST',
    path: focusCompanyId ? `/v2/empresas/${focusCompanyId}` : '/v2/empresas',
    body: payload,
  });

  const result = response.data;
  await admin
    .firestore()
    .collection('company_settings')
    .doc(params.claims.companyId)
    .set(
      {
        focusCompanyId: asTrimmedString(result.id || focusCompanyId),
        focusCompanyTokenPreview: maskSecret(token),
        focusCompanySyncAt: admin.firestore.FieldValue.serverTimestamp(),
        focusCompanyResponse: result,
        fiscalCertificate: {
          ...certificate,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
          validUntil: asTrimmedString(result.certificado_valido_ate),
          validFrom: asTrimmedString(result.certificado_valido_de),
          certificateCnpj: asTrimmedString(result.certificado_cnpj),
        },
      },
      { merge: true },
    );

  await writeAudit({
    claims: params.claims,
    module: 'fiscal',
    action: 'focus_company_sync',
    entityPath: 'company_settings',
    entityId: params.claims.companyId,
    before: null,
    after: {
      focusCompanyId: asTrimmedString(result.id || focusCompanyId),
      certificado_valido_ate: asTrimmedString(result.certificado_valido_ate),
      certificado_cnpj: asTrimmedString(result.certificado_cnpj),
    },
  });

  return result;
}

/** Pre-check emissao Focus; o app espelha em `lib/.../focus_official_issue_readiness.dart`. */
function validateInvoiceReadinessForOfficialIssue(params: {
  invoiceData: FirebaseFirestore.DocumentData;
  settingsData: Record<string, unknown>;
}): void {
  const data = params.invoiceData;
  const settingsData = params.settingsData;
  const emitter = asRecord(data.emitter);
  const customer = asRecord(data.customer);
  const service = asRecord(data.service);
  const tax = asRecord(data.tax);
  const setup = asRecord(settingsData.fiscalRealIntegration);
  const certificate = asRecord(settingsData.fiscalCertificate);
  const homologationChecklist = asRecord(settingsData.fiscalHomologationChecklist);
  const focusApiMode = focusNfseApiMode(setup);
  const missing: string[] = [];

  const provider = asTrimmedString(setup.provider);
  if (!provider) missing.push('provedor fiscal');
  if (
    providerIsFocus(provider) &&
    !asTrimmedString(setup.apiToken) &&
    !asTrimmedString(obterConfigFocusPlatform().apiToken)
  ) {
    missing.push('token da Focus NFe');
  }
  if (!providerIsFocus(provider) && !asTrimmedString(setup.apiBaseUrl)) {
    missing.push('Base URL da integracao fiscal');
  }

  const emitterDocument = onlyDigits(emitter.cnpj || emitter.document);
  if (emitterDocument.length !== 14) missing.push('CNPJ do emitente');
  if (!emitterInscricaoMunicipal(emitter)) {
    missing.push('inscricao municipal do emitente');
  }
  if (!asTrimmedString(emitter.city)) missing.push('cidade do emitente');
  if (!asTrimmedString(emitter.state)) missing.push('UF do emitente');

  if (providerIsFocus(provider)) {
    if (!asTrimmedString(certificate.storagePath)) {
      missing.push('certificado digital');
    }
    if (!asTrimmedString(certificate.password)) {
      missing.push('senha do certificado digital');
    }
  }

  const customerDocument = onlyDigits(customer.document);
  if (customerDocument.length !== 11 && customerDocument.length !== 14) {
    missing.push('CPF/CNPJ do tomador');
  }
  if (!asTrimmedString(customer.legalName || data.clientName)) {
    missing.push('razao social/nome do tomador');
  }
  if (!asTrimmedString(customer.city)) missing.push('cidade do tomador');
  if (!asTrimmedString(customer.state)) missing.push('UF do tomador');

  const amountCents = Number(data.amountCents ?? service.grossAmountCents ?? 0);
  if (!(amountCents > 0)) missing.push('valor da nota');
  if (!asTrimmedString(buildFocusInvoiceServiceDescription(asRecord(data), service, emitter))) {
    missing.push('descricao do servico');
  }
  if (!onlyDigits(service.serviceCode || service.municipalServiceCode)) {
    missing.push('item da lista de servico');
  }
  if (!onlyDigits(service.municipalServiceCode) && focusApiMode !== 'national') {
    missing.push('codigo tributario municipal');
  }
  const nationalIssCodeForChecks =
    focusApiMode === 'national'
      ? focusNationalTaxCode({
          service,
          emitter,
          invoiceData: data,
        })
      : '';
  if (focusApiMode === 'national' && !nationalIssCodeForChecks) {
    missing.push('codigo de tributacao nacional do ISS');
  }

  if (focusApiMode === 'national' && nationalIssCodeForChecks) {
    if (FOCUS_NATIONAL_OBRA_REQUIRED_TAX_CODES.has(nationalIssCodeForChecks)) {
      const workSite = asRecord(service.workSite || data.workSite);
      const cno = onlyDigits(workSite.cno || workSite.cno_obra || workSite.cnoObra || '');
      if (cno.length === 0) {
        missing.push('CNO da obra obrigatorio para este codigo de tributacao nacional (grupo obra)');
      }
    }
    const taxRegime = asTrimmedString(tax.taxRegime).toLowerCase();
    const issRetained = Boolean(tax.issRetained);
    const rawIssRate = asFocusDecimal(tax.issRate);
    const requiresMinRetainedIss =
      issRetained &&
      focusNationalSimpleOptionCode(taxRegime) === 3 &&
      focusNationalSimpleTaxRegimeCode(taxRegime) === 1;
    if (requiresMinRetainedIss && rawIssRate < 1.8) {
      missing.push('aliquota minima 1,80% para Simples com ISS retido (NFS-e Nacional)');
    }
  }

  const inssCents = Number(tax.inssAmountCents ?? 0);
  if (inssCents < 0) {
    missing.push('valor de INSS nao pode ser negativo');
  }

  const operationNature = normalizeOperationNatureCode(tax.operationNature);
  if (!operationNature) {
    missing.push('natureza da operacao fiscal valida');
  }

  const environment = asTrimmedString(setup.environment).toLowerCase();
  if (environment === 'producao') {
    if (homologationChecklist.companyBaseReviewed !== true) {
      missing.push('checklist: cadastro base revisado');
    }
    if (homologationChecklist.certificateValidated !== true) {
      missing.push('checklist: certificado validado');
    }
    if (homologationChecklist.matrixValidated !== true) {
      missing.push('checklist: matriz fiscal conferida');
    }
    if (homologationChecklist.providerConnectionValidated !== true) {
      missing.push('checklist: conexao com provedor validada');
    }
    if (homologationChecklist.pilotInvoiceValidated !== true) {
      missing.push('checklist: emissao piloto validada');
    }
    if (homologationChecklist.productionAuthorized !== true) {
      missing.push('checklist: producao autorizada');
    }
  }

  if (missing.length > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Emissao oficial bloqueada. Ajuste: ${missing.join(', ')}.`,
    );
  }
}

function normalizeInvoiceRefreshAttemptStatus(status: string): string {
  const normalizedStatus = status.toUpperCase();
  if (normalizedStatus === 'PROCESSANDO' || normalizedStatus === 'PROCESSING') {
    return 'PROCESSING';
  }
  if (normalizedStatus === 'CANCELED') {
    return 'CANCELED';
  }
  if (normalizedStatus === 'EMITTED' || normalizedStatus === 'APPROVED') {
    return 'SUCCESS';
  }
  if (normalizedStatus === 'FAILED') {
    return 'QUERY_FAILED';
  }
  return 'QUERY_SUCCESS';
}

async function persistOfficialInvoiceStatus(params: {
  invoiceRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  invoiceData: FirebaseFirestore.DocumentData;
  providerResponse: Record<string, unknown>;
}): Promise<{
  status: string;
  officialNumber: string;
  officialPortalUrl: string;
  protocol: string;
  lastAttemptStatus: string;
}> {
  const providerMap = asRecord(params.providerResponse);
  const rawStatus =
    coalesceFocusNfseStatusRawForNormalize(providerMap) ||
    asTrimmedString(params.providerResponse.status);
  const status = asUpperStatus(
    normalizeOfficialInvoiceStatus(
      rawStatus,
      params.providerResponse.provider,
      asTrimmedString(params.invoiceData.status) || 'DRAFT',
    ),
    asTrimmedString(params.invoiceData.status) || 'DRAFT',
  );
  const officialNumber =
    extractFocusOfficialNfseNumber(providerMap) ||
    asTrimmedString(params.providerResponse.officialNumber) ||
    asTrimmedString(params.providerResponse.invoiceNumber) ||
    asTrimmedString(params.providerResponse.number) ||
    asTrimmedString(params.providerResponse.nfseNumber) ||
    asTrimmedString(params.invoiceData.officialNumber);
  const officialPortalUrl =
    asTrimmedString(params.providerResponse.officialPortalUrl) ||
    asTrimmedString(params.providerResponse.portalUrl) ||
    asTrimmedString(params.providerResponse.url) ||
    asTrimmedString(params.invoiceData.officialPortalUrl);
  const protocol =
    asTrimmedString(params.providerResponse.protocol) ||
    asTrimmedString(params.providerResponse.receipt) ||
    asTrimmedString(params.providerResponse.requestId) ||
    asTrimmedString(params.invoiceData.officialProtocol);
  const lastAttemptStatus = normalizeInvoiceRefreshAttemptStatus(status);

  await params.invoiceRef.set(
    {
      status,
      officialNumber,
      officialPortalUrl,
      officialProtocol: protocol,
      officialProvider: asTrimmedString(params.providerResponse.provider),
      officialEnvironment: asTrimmedString(params.providerResponse.environment),
      lastEmissionAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEmissionAttemptStatus: lastAttemptStatus,
      lastEmissionError: admin.firestore.FieldValue.delete(),
      officialResponse: params.providerResponse,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    status,
    officialNumber,
    officialPortalUrl,
    protocol,
    lastAttemptStatus,
  };
}

async function mergeFiscalHomologationChecklist(params: {
  companyId: string;
  patch: Record<string, unknown>;
}): Promise<void> {
  const settingsRef = admin.firestore().collection('company_settings').doc(params.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const current = asRecord(settingsData.fiscalHomologationChecklist);
  await settingsRef.set(
    {
      fiscalHomologationChecklist: {
        ...current,
        ...params.patch,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function buildFiscalOperationalPendingItems(params: {
  companyData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
}): Record<string, unknown>[] {
  const companyData = params.companyData;
  const settingsData = params.settingsData;
  const setup = asRecord(settingsData.fiscalRealIntegration);
  const certificate = asRecord(settingsData.fiscalCertificate);
  const checklist = asRecord(settingsData.fiscalHomologationChecklist);
  const routing = asRecord(settingsData.fiscalRouting);
  const provisioning = asRecord(settingsData.focusProvisioning);
  const controlRoot = asRecord(settingsData.fiscalPendingControl);
  const items: Record<string, unknown>[] = [];

  const pushItem = (input: {
    code: string;
    title: string;
    description: string;
    category: string;
    severity?: string;
    documentRequired?: boolean;
    defaultOwner?: string;
  }): void => {
    const control = asRecord(controlRoot[input.code]);
    items.push({
      code: input.code,
      title: input.title,
      description: input.description,
      category: input.category,
      severity: input.severity ?? 'high',
      documentRequired: input.documentRequired === true,
      owner:
        asTrimmedString(control.owner) ||
        asTrimmedString(input.defaultOwner) ||
        (input.documentRequired === true ? 'company' : 'platform'),
      status: asTrimmedString(control.status) || 'pending',
      note: asTrimmedString(control.note),
      updatedAt: timestampToIsoString(control.updatedAt),
    });
  };

  const provider = asTrimmedString(setup.provider).toLowerCase();
  const environment = asTrimmedString(setup.environment).toLowerCase();
  const focusCompanyId = asTrimmedString(settingsData.focusCompanyId);
  const certFile = asTrimmedString(certificate.fileName);
  const certValidUntil = asTrimmedString(certificate.validUntil);
  const certPassword = asTrimmedString(certificate.password);
  const provisioningMissing = Array.isArray(provisioning.missing)
    ? provisioning.missing.map((item) => asTrimmedString(item)).filter((item) => item)
    : [];

  if (!asTrimmedString(companyData.cnpj)) {
    pushItem({
      code: 'cnpj_missing',
      title: 'CNPJ ausente',
      description: 'A empresa esta sem CNPJ preenchido na base cadastral.',
      category: 'cadastro',
      severity: 'critical',
      defaultOwner: 'platform',
    });
  }
  if (!asTrimmedString(companyData.inscricaoMunicipal)) {
    pushItem({
      code: 'municipal_registration_missing',
      title: 'Inscricao municipal pendente',
      description: 'A Focus exige inscricao municipal para completar a configuracao da empresa.',
      category: 'cadastro',
      severity: 'critical',
      defaultOwner: 'company',
    });
  }
  if (!asTrimmedString(companyData.cidade)) {
    pushItem({
      code: 'city_missing',
      title: 'Cidade nao informada',
      description: 'A cidade da empresa precisa estar registrada para definir a rota fiscal correta.',
      category: 'cadastro',
      severity: 'critical',
      defaultOwner: 'company',
    });
  }
  if (!asTrimmedString(companyData.estado)) {
    pushItem({
      code: 'state_missing',
      title: 'UF nao informada',
      description: 'A UF da empresa precisa estar preenchida para integracao fiscal.',
      category: 'cadastro',
      severity: 'critical',
      defaultOwner: 'company',
    });
  }
  if (routing.requiresManualReview === true) {
    pushItem({
      code: 'manual_review_required',
      title: 'Rota fiscal exige revisao manual',
      description: 'A deteccao automatica da prefeitura ou da modalidade fiscal precisa de revisao da plataforma.',
      category: 'configuracao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (!provider) {
    pushItem({
      code: 'provider_missing',
      title: 'Provedor fiscal nao definido',
      description: 'Defina o provedor fiscal da empresa antes de liberar emissao oficial.',
      category: 'configuracao',
      severity: 'critical',
      defaultOwner: 'platform',
    });
  }
  if (!environment) {
    pushItem({
      code: 'environment_missing',
      title: 'Ambiente fiscal nao definido',
      description: 'Escolha homologacao ou producao para a operacao fiscal da empresa.',
      category: 'configuracao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (!asTrimmedString(setup.municipalCode)) {
    pushItem({
      code: 'municipal_code_missing',
      title: 'Codigo fiscal base pendente',
      description:
        asTrimmedString(setup.focusNfseApi).toLowerCase() === 'national'
          ? 'Informe o codigo fiscal nacional/base para esta empresa.'
          : 'Informe o codigo municipal base da emissao.',
      category: 'configuracao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (providerIsFocus(asTrimmedString(setup.provider))) {
    if (
      !asTrimmedString(setup.apiToken) &&
      !asTrimmedString(obterConfigFocusPlatform().apiToken)
    ) {
      pushItem({
        code: 'api_token_missing',
        title: 'Token da integracao fiscal ausente',
        description:
          'Para Focus: configure o token no cadastro da empresa ou o token global da plataforma (empresa suprema / FOCUS_API_TOKEN).',
        category: 'configuracao',
        severity: 'critical',
        defaultOwner: 'platform',
      });
    }
  } else {
    if (!asTrimmedString(setup.apiToken)) {
      pushItem({
        code: 'api_token_missing',
        title: 'Token da integracao fiscal ausente',
        description: 'A integracao nao conseguira sincronizar com o provedor sem token/API key.',
        category: 'configuracao',
        severity: 'critical',
        defaultOwner: 'platform',
      });
    }
  }
  if (provider.includes('focus') && !focusCompanyId) {
    pushItem({
      code: 'focus_sync_missing',
      title: 'Empresa ainda nao sincronizada na Focus',
      description: 'A sincronizacao da empresa com a Focus precisa concluir antes da operacao oficial.',
      category: 'integracao',
      severity: 'critical',
      defaultOwner: 'platform',
    });
  }
  if (!certFile) {
    pushItem({
      code: 'certificate_file_missing',
      title: 'Certificado digital nao enviado',
      description: 'A empresa precisa enviar o certificado digital A1 para concluir a implantacao fiscal.',
      category: 'documento',
      severity: 'critical',
      documentRequired: true,
      defaultOwner: 'company',
    });
  }
  if (!certPassword) {
    pushItem({
      code: 'certificate_password_missing',
      title: 'Senha do certificado pendente',
      description: 'A senha do certificado nao foi registrada e bloqueia a sincronizacao automatica.',
      category: 'documento',
      severity: 'critical',
      documentRequired: true,
      defaultOwner: 'company',
    });
  }
  if (!asTrimmedString(setup.certificateRef)) {
    pushItem({
      code: 'certificate_ref_missing',
      title: 'Referencia operacional do certificado pendente',
      description: 'Registre a referencia do certificado para o controle operacional da empresa.',
      category: 'configuracao',
      severity: 'medium',
      defaultOwner: 'platform',
    });
  }
  if (!certValidUntil) {
    pushItem({
      code: 'certificate_validity_missing',
      title: 'Validade do certificado nao validada',
      description: 'A vigencia do certificado precisa ser validada antes da liberacao em producao.',
      category: 'documento',
      severity: 'high',
      documentRequired: true,
      defaultOwner: 'platform',
    });
  }
  if (!asTrimmedString(setup.lastHomologationNote)) {
    pushItem({
      code: 'homologation_note_missing',
      title: 'Observacao de homologacao pendente',
      description: 'Registre o resumo da homologacao para manter o readiness documentado.',
      category: 'homologacao',
      severity: 'medium',
      defaultOwner: 'platform',
    });
  }
  if (checklist.companyBaseReviewed !== true) {
    pushItem({
      code: 'check_company_base',
      title: 'Cadastro base nao revisado',
      description: 'Confirme CNPJ, inscricao municipal, endereco e municipio da empresa.',
      category: 'homologacao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (checklist.certificateValidated !== true) {
    pushItem({
      code: 'check_certificate',
      title: 'Certificado ainda nao validado',
      description: 'Valide o certificado recebido antes da liberacao oficial.',
      category: 'homologacao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (checklist.matrixValidated !== true) {
    pushItem({
      code: 'check_matrix',
      title: 'Matriz fiscal pendente',
      description: 'Revise regras fiscais, servicos padrao e CNAE antes da emissao oficial.',
      category: 'homologacao',
      severity: 'medium',
      defaultOwner: 'platform',
    });
  }
  if (checklist.providerConnectionValidated !== true) {
    pushItem({
      code: 'check_provider_connection',
      title: 'Conexao com provedor nao validada',
      description: 'A integracao com a Focus ainda nao foi validada operacionalmente.',
      category: 'integracao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (checklist.pilotInvoiceValidated !== true) {
    pushItem({
      code: 'check_pilot_invoice',
      title: 'Emissao piloto ainda nao validada',
      description: 'A empresa precisa passar por uma emissao piloto antes da liberacao em producao.',
      category: 'homologacao',
      severity: 'high',
      defaultOwner: 'platform',
    });
  }
  if (environment === 'producao' && checklist.productionAuthorized !== true) {
    pushItem({
      code: 'check_production_authorization',
      title: 'Producao ainda nao autorizada',
      description: 'Mesmo em producao, a autorizacao final ainda nao foi registrada no checklist.',
      category: 'homologacao',
      severity: 'critical',
      defaultOwner: 'platform',
    });
  }

  for (const missing of provisioningMissing) {
    const code = `focus_missing_${missing.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
    if (items.some((item) => asTrimmedString(item.code) === code)) continue;
    pushItem({
      code,
      title: `Focus pendente: ${missing}`,
      description: `A automacao da Focus indicou a ausencia de "${missing}".`,
      category: 'integracao',
      severity: 'high',
      defaultOwner: missing.includes('certificado') ? 'company' : 'platform',
      documentRequired: missing.includes('certificado'),
    });
  }

  return items;
}

function buildFiscalPlatformSnapshot(params: {
  companyId: string;
  ownerUid: string;
  ownerData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
}): Record<string, unknown> {
  const ownerData = params.ownerData;
  const settingsData = params.settingsData;
  const companyData =
    mapCompanyData(settingsData.companyData) ||
    mapCompanyData(ownerData.companyData) ||
    {};
  const setup = asRecord(settingsData.fiscalRealIntegration);
  const certificate = asRecord(settingsData.fiscalCertificate);
  const checklist = asRecord(settingsData.fiscalHomologationChecklist);
  const provisioning = asRecord(settingsData.focusProvisioning);
  const communication = asRecord(settingsData.fiscalPendingCommunication);
  const pendingItems = buildFiscalOperationalPendingItems({
    companyData,
    settingsData,
  });
  const criticalPending = pendingItems.filter(
    (item) => asTrimmedString(item.severity) === 'critical',
  ).length;
  const documentPending = pendingItems.filter(
    (item) => item.documentRequired === true,
  ).length;
  const checklistCompleted = [
    checklist.companyBaseReviewed === true,
    checklist.certificateValidated === true,
    checklist.matrixValidated === true,
    checklist.providerConnectionValidated === true,
    checklist.pilotInvoiceValidated === true,
    checklist.productionAuthorized === true,
  ].filter((item) => item).length;

  const overallStatus =
    asTrimmedString(provisioning.status) === 'ERROR'
      ? 'ERROR'
      : pendingItems.length === 0
        ? 'READY'
        : criticalPending > 0
          ? 'BLOCKED'
          : 'PENDING';

  return {
    companyId: params.companyId,
    ownerUid: params.ownerUid,
    ownerName: asTrimmedString(ownerData.nome),
    ownerEmail: asTrimmedString(ownerData.email).toLowerCase(),
    companyName:
      asTrimmedString(ownerData.companyName) ||
      asTrimmedString(asRecord(ownerData.companyData).nomeFantasia) ||
      asTrimmedString(asRecord(ownerData.companyData).razaoSocial),
    companyDocument:
      asTrimmedString(companyData.cnpj) ||
      asTrimmedString(companyData.cpf),
    city: asTrimmedString(companyData.cidade),
    state: asTrimmedString(companyData.estado),
    focusProvisioningStatus: asTrimmedString(provisioning.status) || 'PENDING',
    focusProvisioningError: asTrimmedString(provisioning.lastError),
    focusProvisioningMissing: Array.isArray(provisioning.missing)
      ? provisioning.missing
      : [],
    focusCompanyId: asTrimmedString(settingsData.focusCompanyId),
    fiscalEnvironment: asTrimmedString(setup.environment),
    fiscalProvider: asTrimmedString(setup.provider),
    focusNfseApi: asTrimmedString(setup.focusNfseApi),
    municipalCode: asTrimmedString(setup.municipalCode),
    certificateRef: asTrimmedString(setup.certificateRef),
    lastHomologationNote: asTrimmedString(setup.lastHomologationNote),
    certificateFileName: asTrimmedString(certificate.fileName),
    certificateValidUntil: asTrimmedString(certificate.validUntil),
    checklistCompleted,
    checklistTotal: 6,
    pendingCount: pendingItems.length,
    criticalPendingCount: criticalPending,
    documentPendingCount: documentPending,
    overallStatus,
    pendingItems,
    lastPendingEmailAt: timestampToIsoString(communication.lastSentAt),
    lastPendingEmailTo: asTrimmedString(communication.lastSentTo),
    lastPendingEmailSummary: asTrimmedString(communication.summary),
  };
}

async function syncPlatformCompanyDataPatch(params: {
  companyId: string;
  companyDataPatch: Record<string, unknown>;
}): Promise<void> {
  const patchEntries = Object.entries(params.companyDataPatch).filter(
    ([, value]) => value !== undefined,
  );
  if (patchEntries.length === 0) return;
  const companyDataPatch = Object.fromEntries(patchEntries);
  const settingsRef = admin.firestore().collection('company_settings').doc(params.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const currentCompanyData = asRecord(settingsData.companyData);
  const nextCompanyData = {
    ...currentCompanyData,
    ...companyDataPatch,
  };
  await settingsRef.set(
    {
      companyData: nextCompanyData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const usersSnap = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', params.companyId)
    .get();
  if (usersSnap.empty) return;

  let batch = admin.firestore().batch();
  let count = 0;
  for (const doc of usersSnap.docs) {
    const data = asRecord(doc.data());
    const currentUserCompanyData = asRecord(data.companyData);
    batch.set(
      doc.ref,
      {
        companyData: {
          ...currentUserCompanyData,
          ...companyDataPatch,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = admin.firestore().batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

async function validateInvoiceSourceTaskConsistency(params: {
  invoiceData: FirebaseFirestore.DocumentData;
  claims: Claims;
}): Promise<void> {
  const sourceTask = asRecord(params.invoiceData.sourceTask);
  const sourceTaskId =
    asTrimmedString(sourceTask.id) ||
    asTrimmedString(params.invoiceData.sourceTaskId);
  if (!sourceTaskId) return;

  const taskSnap = await admin.firestore().collection('tasks').doc(sourceTaskId).get();
  if (!taskSnap.exists) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A tarefa vinculada a nota nao foi encontrada.',
    );
  }

  const taskData = taskSnap.data() ?? {};
  assertCompany(String(taskData.companyId ?? ''), params.claims);

  const taskCustomerId = asTrimmedString(taskData.clienteId);
  const taskCustomerDocument = onlyDigits(taskData.clienteDocumento);
  const invoiceCustomerId = asTrimmedString(params.invoiceData.customerId);
  const invoiceCustomer = asRecord(params.invoiceData.customer);
  const invoiceCustomerDocument = onlyDigits(
    invoiceCustomer.document || params.invoiceData.clientDocument,
  );

  if (
    taskCustomerId &&
    invoiceCustomerId &&
    taskCustomerId !== invoiceCustomerId
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A tarefa vinculada pertence a um cliente diferente do tomador da nota.',
    );
  }

  if (
    taskCustomerDocument &&
    invoiceCustomerDocument &&
    taskCustomerDocument !== invoiceCustomerDocument
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'O documento do cliente da tarefa nao confere com o tomador da nota.',
    );
  }
}

async function ensureFinanceMovementForInvoice(params: {
  invoiceRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  invoiceId: string;
  invoiceData: FirebaseFirestore.DocumentData;
  claims: Claims;
  status: string;
  officialNumber: string;
}): Promise<string> {
  const normalizedStatus = params.status.toUpperCase();
  if (normalizedStatus !== 'EMITTED' && params.officialNumber.trim().length === 0) {
    return asTrimmedString(params.invoiceData.financeMovementId);
  }

  const currentMovementId = asTrimmedString(params.invoiceData.financeMovementId);
  if (currentMovementId) return currentMovementId;

  const billing = asRecord(params.invoiceData.billing);
  const service = asRecord(params.invoiceData.service);
  const sourceTask = asRecord(params.invoiceData.sourceTask);
  const fromBilling = Math.trunc(Number(billing.finalAmountCents ?? 0) || 0);
  const fromInvoice = Math.trunc(Number(params.invoiceData.amountCents ?? 0) || 0);
  const fromServiceGross = Math.trunc(Number(service.grossAmountCents ?? 0) || 0);
  const amountCents = Math.max(0, fromBilling, fromInvoice, fromServiceGross);
  if (!(amountCents > 0)) return '';

  const issueDateRaw = params.invoiceData.issueDate;
  const serviceDateRaw = params.invoiceData.serviceDate;
  const issueDate =
    issueDateRaw instanceof admin.firestore.Timestamp
      ? issueDateRaw.toDate()
      : new Date();
  const dueDate =
    serviceDateRaw instanceof admin.firestore.Timestamp
      ? serviceDateRaw.toDate()
      : issueDate;
  const clientName = asTrimmedString(params.invoiceData.clientName) || 'Cliente';
  const serviceDescription =
    asTrimmedString(params.invoiceData.serviceDescription) || 'Servico';

  const movementRef = admin.firestore().collection('finance_movements').doc();
  await movementRef.set({
    companyId: params.claims.companyId,
    ownerUserId: '__COMPANY__',
    title: `NFS-e ${clientName}`,
    category: 'client_income',
    type: 'INCOME',
    amountCents,
    date: admin.firestore.Timestamp.fromDate(issueDate),
    dueDate: admin.firestore.Timestamp.fromDate(dueDate),
    paymentStatus: 'PENDING',
    notes:
      `Origem fiscal: nota ${params.invoiceId} | Servico: ${serviceDescription}` +
      (asTrimmedString(sourceTask.id)
        ? ` | Tarefa: ${asTrimmedString(sourceTask.id)}`
        : ''),
    sourceModule: 'fiscal',
    sourceInvoiceId: params.invoiceId,
    sourceTaskId: asTrimmedString(sourceTask.id) || null,
    sourceCustomerId: asTrimmedString(params.invoiceData.customerId) || null,
    sourceCustomerName: clientName,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await params.invoiceRef.set(
    {
      financeMovementId: movementRef.id,
      financeLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims: params.claims,
    module: 'fiscal',
    action: 'invoice_linked_to_finance',
    entityPath: 'service_invoices',
    entityId: params.invoiceId,
    before: null,
    after: {
      financeMovementId: movementRef.id,
      sourceModule: 'fiscal',
    },
  });

  return movementRef.id;
}

function paymentFinanceMovementDocId(paymentId: string): string {
  return `payment_${paymentId}`;
}

function debtFinanceMovementDocId(debtId: string): string {
  return `debt_${debtId}`;
}

function paymentMovementFinancialStatus(
  status: string,
): 'PENDING' | 'PAID' {
  const normalized = status.toUpperCase();
  if (normalized === 'PAID' || normalized === 'CONFIRMED') {
    return 'PAID';
  }
  return 'PENDING';
}

function paymentMovementDateFromData(
  data: Record<string, unknown>,
): Date {
  const paidAt = data.paidAt;
  if (paidAt instanceof admin.firestore.Timestamp) {
    return paidAt.toDate();
  }
  const confirmationAt = data.confirmationAt;
  if (confirmationAt instanceof admin.firestore.Timestamp) {
    return confirmationAt.toDate();
  }
  const dueDate = data.dueDate;
  if (dueDate instanceof admin.firestore.Timestamp) {
    return dueDate.toDate();
  }
  return new Date();
}

async function syncFinanceMovementForPayment(params: {
  paymentRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  paymentId: string;
  paymentData: FirebaseFirestore.DocumentData;
  claims: Claims;
}): Promise<string> {
  const payment = asRecord(params.paymentData);
  const companyId = asTrimmedString(payment.companyId) || params.claims.companyId;
  const employeeId = asTrimmedString(payment.employeeId);
  const status = asTrimmedString(payment.status).toUpperCase();
  const netCents = Math.max(0, Math.trunc(Number(payment.netCents ?? 0) || 0));
  const movementRef = admin
    .firestore()
    .collection('finance_movements')
    .doc(paymentFinanceMovementDocId(params.paymentId));

  if (!companyId || !employeeId || netCents <= 0 || status === 'CANCELED') {
    await movementRef.delete().catch(() => undefined);
    await params.paymentRef.set(
      {
        financeMovementId: admin.firestore.FieldValue.delete(),
        financeLinkedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return '';
  }

  const movementSnap = await movementRef.get();
  const competenceYear = Math.trunc(Number(payment.competenceYear ?? 0) || 0);
  const competenceMonth = Math.trunc(Number(payment.competenceMonth ?? 0) || 0);
  const competenceLabel =
    competenceYear > 0 && competenceMonth > 0
      ? `${String(competenceMonth).padStart(2, '0')}/${competenceYear}`
      : 'Competencia sem data';
  const dueDateRaw = payment.dueDate;

  await movementRef.set(
    {
      companyId,
      ownerUserId: '__COMPANY__',
      title: `Folha ${competenceLabel}`,
      category: 'payroll_expense',
      type: 'EXPENSE',
      amountCents: netCents,
      date: admin.firestore.Timestamp.fromDate(paymentMovementDateFromData(payment)),
      dueDate:
        dueDateRaw instanceof admin.firestore.Timestamp
          ? dueDateRaw
          : null,
      paymentStatus: paymentMovementFinancialStatus(status),
      notes:
        `Origem trabalhista: pagamento ${params.paymentId}` +
        ` | Colaborador: ${employeeId}` +
        ` | Competencia: ${competenceLabel}`,
      sourceModule: 'payments',
      sourcePaymentId: params.paymentId,
      sourceEmployeeId: employeeId,
      createdAt: movementSnap.exists
        ? movementSnap.get('createdAt') ?? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await params.paymentRef.set(
    {
      financeMovementId: movementRef.id,
      financeLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return movementRef.id;
}

function debtMovementShape(
  type: string,
): {
  titlePrefix: string;
  category: string;
  movementType: 'INCOME' | 'EXPENSE';
} {
  if (type.toUpperCase() === 'ADVANCE') {
    return {
      titlePrefix: 'Adiantamento',
      category: 'employee_advance',
      movementType: 'EXPENSE',
    };
  }
  return {
    titlePrefix: 'Cobranca interna',
    category: 'employee_debt',
    movementType: 'INCOME',
  };
}

async function syncFinanceMovementForDebt(params: {
  debtRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  debtId: string;
  debtData: FirebaseFirestore.DocumentData;
  claims: Claims;
}): Promise<string> {
  const debt = asRecord(params.debtData);
  const companyId = asTrimmedString(debt.companyId) || params.claims.companyId;
  const employeeId = asTrimmedString(debt.employeeId);
  const type = asTrimmedString(debt.type).toUpperCase();
  const status = asTrimmedString(debt.status).toUpperCase();
  const amountCents = Math.max(0, Math.trunc(Number(debt.amountCents ?? 0) || 0));
  const movementRef = admin
    .firestore()
    .collection('finance_movements')
    .doc(debtFinanceMovementDocId(params.debtId));

  if (!companyId || !employeeId || amountCents <= 0 || status === 'CANCELED') {
    await movementRef.delete().catch(() => undefined);
    await params.debtRef.set(
      {
        financeMovementId: admin.firestore.FieldValue.delete(),
        financeLinkedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return '';
  }

  const movementSnap = await movementRef.get();
  const shape = debtMovementShape(type);
  const dueDateRaw = debt.dueDate;
  const titleBase = asTrimmedString(debt.title) || 'Obrigacao interna';
  const movementDate =
    debt.settledAt instanceof admin.firestore.Timestamp
      ? debt.settledAt.toDate()
      : dueDateRaw instanceof admin.firestore.Timestamp
        ? dueDateRaw.toDate()
        : new Date();

  await movementRef.set(
    {
      companyId,
      ownerUserId: '__COMPANY__',
      title: `${shape.titlePrefix}: ${titleBase}`,
      category: shape.category,
      type: shape.movementType,
      amountCents,
      date: admin.firestore.Timestamp.fromDate(movementDate),
      dueDate:
        dueDateRaw instanceof admin.firestore.Timestamp
          ? dueDateRaw
          : null,
      paymentStatus: status === 'SETTLED' ? 'PAID' : 'PENDING',
      notes:
        `Origem obrigacao interna: ${params.debtId}` +
        ` | Colaborador: ${employeeId}` +
        ` | Tipo: ${type}`,
      sourceModule: 'debts',
      sourceDebtId: params.debtId,
      sourceEmployeeId: employeeId,
      createdAt: movementSnap.exists
        ? movementSnap.get('createdAt') ?? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await params.debtRef.set(
    {
      financeMovementId: movementRef.id,
      financeLinkedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return movementRef.id;
}

async function persistInvoiceAttemptFailure(params: {
  invoiceRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  invoiceId: string;
  claims: Claims;
  attemptStatus: string;
  fallbackMessage: string;
  auditAction: string;
  error: unknown;
}): Promise<string> {
  const message = errorMessage(params.error, params.fallbackMessage);
  await params.invoiceRef.set(
    {
      lastEmissionAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEmissionAttemptStatus: params.attemptStatus,
      lastEmissionError: message,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await writeAudit({
    claims: params.claims,
    module: 'fiscal',
    action: params.auditAction,
    entityPath: 'service_invoices',
    entityId: params.invoiceId,
    before: null,
    after: {
      lastAttemptStatus: params.attemptStatus,
      error: message,
    },
  });
  return message;
}

async function buildFocusInvoicePayload(params: {
  invoiceId: string;
  invoiceData: FirebaseFirestore.DocumentData;
  token: string;
  environment: string;
}): Promise<Record<string, unknown>> {
  const data = params.invoiceData;
  const emitter = asRecord(data.emitter);
  const customer = asRecord(data.customer);
  const service = asRecord(data.service);
  const tax = asRecord(data.tax);
  const issueDateRaw = data.issueDate;
  const issueDate =
    issueDateRaw instanceof admin.firestore.Timestamp
      ? issueDateRaw.toDate()
      : new Date();
  const companyMunicipalityCode =
    asTrimmedString(emitter.codigoMunicipio) ||
    (await resolveFocusMunicipalityCode({
      token: params.token,
      environment: params.environment,
      city: asTrimmedString(emitter.city),
      state: asTrimmedString(emitter.state),
    })) ||
    knownMunicipalityIbgeCodeByLocation(emitter.city, emitter.state);
  const customerMunicipalityCode =
    (await resolveFocusMunicipalityCode({
      token: params.token,
      environment: params.environment,
      city: asTrimmedString(customer.city),
      state: asTrimmedString(customer.state),
    })) ||
    knownMunicipalityIbgeCodeByLocation(customer.city, customer.state);

  const customerDocument = onlyDigits(customer.document);
  const amountCents = Number(data.amountCents ?? service.grossAmountCents ?? 0);
  const deductionsCents = Number(tax.deductionsCents ?? 0);
  const taxableBaseCents = Number(tax.taxableBaseCents ?? Math.max(amountCents - deductionsCents, 0));
  const issAmountCents = Number(tax.issAmountCents ?? 0);
  const issRetainedAmountCents = Boolean(tax.issRetained) ? issAmountCents : 0;
  const inssAmountCents = Number(tax.inssAmountCents ?? 0);
  const otherRetentionsCents = Number(tax.otherRetentionsCents ?? 0);
  const netAmountCents = Number(tax.netAmountCents ?? amountCents);
  const issRate = asFocusDecimal(tax.issRate);
  const serviceCode = onlyDigits(service.serviceCode || service.municipalServiceCode);
  const municipalTaxCode = onlyDigits(service.municipalServiceCode);
  const taxRegime = asTrimmedString(tax.taxRegime).toLowerCase();

  return {
    data_emissao: formatSaoPauloDateTime(issueDate),
    natureza_operacao: normalizeOperationNatureCode(tax.operationNature),
    incentivador_cultural: false,
    optante_simples_nacional:
        taxRegime.includes('simples') || taxRegime.includes('mei'),
    status: '1',
    prestador: {
      cnpj: onlyDigits(emitter.cnpj || emitter.document),
      inscricao_municipal: emitterInscricaoMunicipal(emitter),
      codigo_municipio: companyMunicipalityCode,
    },
    tomador: {
      ...(customerDocument.length == 14 ? { cnpj: customerDocument } : {}),
      ...(customerDocument.length == 11 ? { cpf: customerDocument } : {}),
      razao_social: asTrimmedString(customer.legalName || data.clientName),
      email: asTrimmedString(customer.email),
      endereco: {
        bairro: asTrimmedString(customer.neighborhood),
        cep: onlyDigits(customer.zipCode),
        codigo_municipio: customerMunicipalityCode,
        logradouro: asTrimmedString(customer.street),
        numero: asTrimmedString(customer.number),
        uf: asTrimmedString(customer.state).toUpperCase(),
      },
    },
    servico: {
      aliquota: issRate.toFixed(2),
      base_calculo: (taxableBaseCents / 100).toFixed(2),
      discriminacao: buildFocusInvoiceServiceDescription(
        asRecord(data),
        service,
        emitter,
      ),
      iss_retido: Boolean(tax.issRetained),
      item_lista_servico: serviceCode,
      codigo_tributario_municipio: municipalTaxCode,
      valor_inss: (inssAmountCents / 100).toFixed(2),
      valor_iss: (issAmountCents / 100).toFixed(2),
      valor_iss_retido: (issRetainedAmountCents / 100).toFixed(2),
      outras_retencoes: (otherRetentionsCents / 100).toFixed(2),
      valor_liquido: (netAmountCents / 100).toFixed(2),
      valor_servicos: (amountCents / 100).toFixed(2),
    },
    referencia: params.invoiceId,
  };
}

/** LC 116: mesmo ajuste 4/5/6+ do app. 1–3 digitos nao se resolvem de forma fidedigna. */
function tryParseNationalLc116SixDigits(input: string): string | null {
  let d = onlyDigits(String(input ?? ''));
  if (d.length === 0) return null;
  if (d.length > 6) d = d.substring(0, 6);
  if (d.length === 5) d = `0${d}`;
  if (d.length === 4) d = `00${d}`;
  if (d.length !== 6) return null;
  return d;
}

function formatNationalLc116Dotted(sixDigits: string): string {
  if (sixDigits.length !== 6) return sixDigits;
  return `${sixDigits.substring(0, 2)}.${sixDigits.substring(2, 4)}.${sixDigits.substring(4, 6)}`;
}

const FOCUS_NATIONAL_OBRA_REQUIRED_TAX_CODES = new Set([
  '070201',
  '070202',
  '070401',
  '070501',
  '070502',
  '070601',
  '070602',
  '070701',
  '070801',
  '071701',
  '071901',
  '141403',
  '141404',
]);

/**
 * Em NFSe Nacional, o tomador e o emitente de item devem bater: codigo
 * nacional no servico e (quando houver) no municipal no mesmo `XX.XX.XX`
 * resolvido a partir de 4-6 digitos ou do codigo nacional salvo.
 */
function alignNationalServiceCodesOnInvoiceService(
  service: Record<string, unknown>,
): void {
  const s = tryParseNationalLc116SixDigits(
    asTrimmedString(service.serviceCode),
  );
  const m = tryParseNationalLc116SixDigits(
    asTrimmedString(service.municipalServiceCode),
  );
  const pick = s || m;
  if (pick) {
    const dotted = formatNationalLc116Dotted(pick);
    service.serviceCode = dotted;
    service.municipalServiceCode = dotted;
    return;
  }
  const natPref = onlyDigits(
    String(
      service.codigoTributacaoNacionalIss ||
        service.nationalTaxCode ||
        service.nationalServiceCode ||
        service.nationalIssTaxCode ||
        '',
    ),
  );
  if (natPref.length >= 6) {
    const six = natPref.substring(0, 6);
    const dotted = formatNationalLc116Dotted(six);
    service.serviceCode = dotted;
    service.municipalServiceCode = dotted;
  }
}

function focusNationalTaxCode(params: {
  service: Record<string, unknown>;
  emitter: Record<string, unknown>;
  invoiceData: FirebaseFirestore.DocumentData;
}): string {
  const service = params.service;
  const preferred = onlyDigits(
    service.codigoTributacaoNacionalIss ||
      service.nationalTaxCode ||
      service.nationalServiceCode ||
      service.nationalIssTaxCode,
  );
  // Only accept valid 6-digit national codes. Short/partial values (e.g. "702")
  // must be ignored to avoid Focus E0310.
  if (preferred.length >= 6) {
    return preferred.substring(0, 6);
  }

  // Fallback: many clients store the NFSe Nacional subitem directly on serviceCode
  // (e.g. 07.02.02 -> 070202). Accept when it matches the 6-digit national pattern.
  const serviceCodeDigits = onlyDigits(
    service.serviceCode ||
      service.itemListaServico ||
      service.item_lista_servico ||
      service.municipalServiceCode ||
      '',
  );
  if (serviceCodeDigits.length > 0) {
    const padded =
      serviceCodeDigits.length === 5
        ? `0${serviceCodeDigits}`
        : serviceCodeDigits.length === 4
        ? `00${serviceCodeDigits}`
        : serviceCodeDigits;
    if (padded.length >= 6) {
      const candidate = padded.substring(0, 6);
      if (/^\d{6}$/.test(candidate)) return candidate;
    }
  }

  const cnae = onlyDigits(service.cnae || params.emitter.mainCnae);
  const description = slugifyFiscalText(
    service.description || params.invoiceData.serviceDescription,
  );

  if (cnae === '4321500') {
    if (description.includes('instal')) return '070202';
    // Manutencao eletrica predial costuma ser classificada em familia 07 (edificacoes).
    // Para evitar sugestao errada (E0310 / classificacao incorreta), so sugerimos 07.05.01
    // quando houver indicios de edificacao/predial; caso contrario exigimos codigo explicito.
    const isPredial =
      description.includes('predial') ||
      description.includes('edific') ||
      description.includes('predi') ||
      description.includes('imovel') ||
      description.includes('condomin') ||
      description.includes('quadro') ||
      description.includes('instalacao') ||
      description.includes('instal');
    if (description.includes('manut') && isPredial) return '070501';
  }

  if (cnae.length === 7) {
    const p2 = cnae.substring(0, 2);
    if (p2 === '62') {
      return '010501';
    }
    if (p2 === '70' || p2 === '69' || p2 === '65' || p2 === '74') {
      return '171001';
    }
    if (p2 === '86') {
      return '100101';
    }
    if (p2 === '85') {
      return '080201';
    }
    if (p2 === '47') {
      return '171001';
    }
    if (p2 === '95') {
      return '140101';
    }
    if (p2 === '43' || p2 === '45' || p2 === '46') {
      return '140101';
    }
  }

  return '';
}

async function buildFocusNationalInvoicePayload(params: {
  invoiceId: string;
  invoiceData: FirebaseFirestore.DocumentData;
  token: string;
  environment: string;
}): Promise<Record<string, unknown>> {
  const data = params.invoiceData;
  const emitter = asRecord(data.emitter);
  const customer = asRecord(data.customer);
  const service = asRecord(data.service);
  alignNationalServiceCodesOnInvoiceService(service);
  const tax = asRecord(data.tax);
  const issueDateRaw = data.issueDate;
  const serviceDateRaw = data.serviceDate;
  const issueDate =
    issueDateRaw instanceof admin.firestore.Timestamp
      ? issueDateRaw.toDate()
      : new Date();
  const serviceDate =
    serviceDateRaw instanceof admin.firestore.Timestamp
      ? serviceDateRaw.toDate()
      : issueDate;
  const companyMunicipalityCode =
    asTrimmedString(emitter.codigoMunicipio) ||
    (await resolveFocusMunicipalityCode({
      token: params.token,
      environment: params.environment,
      city: asTrimmedString(emitter.city),
      state: asTrimmedString(emitter.state),
    })) ||
    knownMunicipalityIbgeCodeByLocation(emitter.city, emitter.state);
  const customerMunicipalityCode =
    (await resolveFocusMunicipalityCode({
      token: params.token,
      environment: params.environment,
      city: asTrimmedString(customer.city),
      state: asTrimmedString(customer.state),
    })) ||
    knownMunicipalityIbgeCodeByLocation(customer.city, customer.state);
  const municipalityPattern = /^\d{7}$/;
  if (!municipalityPattern.test(companyMunicipalityCode)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Nao foi possivel resolver o codigo IBGE (7 digitos) do municipio do emitente. Cidade/UF: "${asTrimmedString(emitter.city)}" / "${asTrimmedString(emitter.state)}".`,
    );
  }
  if (!municipalityPattern.test(customerMunicipalityCode)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Nao foi possivel resolver o codigo IBGE (7 digitos) do municipio do tomador. Cidade/UF: "${asTrimmedString(customer.city)}" / "${asTrimmedString(customer.state)}".`,
    );
  }
  const customerDocument = onlyDigits(customer.document);
  const customerZip = onlyDigits(customer.zipCode);
  const customerStreet = asTrimmedString(customer.street);
  const customerNumber = asTrimmedString(customer.number);
  const customerNeighborhood = asTrimmedString(customer.neighborhood);
  const customerComplement = asTrimmedString(customer.complement);
  const hasAnyCustomerAddressPiece =
    customerZip.length > 0 ||
    customerStreet.length > 0 ||
    customerNumber.length > 0 ||
    customerNeighborhood.length > 0;
  if (hasAnyCustomerAddressPiece && customerNumber.length === 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Endereco do tomador incompleto: informe o NUMERO do tomador (campo "Numero") para emitir no padrao nacional.',
    );
  }
  const amountCents = Number(data.amountCents ?? service.grossAmountCents ?? 0);
  const deductionsCents = Number(tax.deductionsCents ?? 0);
  const taxableBaseCents = Number(
    tax.taxableBaseCents ?? Math.max(amountCents - deductionsCents, 0),
  );
  const savedIssAmountCents = Number(tax.issAmountCents ?? 0);
  const inssAmountCents = Number(tax.inssAmountCents ?? 0);
  const otherRetentionsCents = Number(tax.otherRetentionsCents ?? 0);
  const rawNetAmountCents = Number(tax.netAmountCents ?? amountCents);
  const rawIssRate = asFocusDecimal(tax.issRate);
  const taxRegime = asTrimmedString(
    resolveFocusNationalTaxRegimeForSimples(
      asTrimmedString(tax.taxRegime),
      asTrimmedString(emitter.taxRegime),
    ),
  ).toLowerCase();
  const simplesOverride = readFocusNationalSimplesNacionalOverride(tax);
  const taxRegimeForFocusRules = simplesOverride != null
    ? taxRegimeTextForFocusSimpleOverride(simplesOverride)
    : taxRegime;
  const issRetained = Boolean(tax.issRetained);
  const issRate = normalizeFocusNationalRetainedIssRate({
    issRate: rawIssRate,
    issRetained,
    taxRegime: taxRegimeForFocusRules,
  });
  const issAmountCents = taxableBaseCents <= 0
    ? 0
    : Math.round((taxableBaseCents * issRate) / 100);
  const netAmountCents = issRetained
    ? Math.max(taxableBaseCents - issAmountCents - inssAmountCents - otherRetentionsCents, 0)
    : rawNetAmountCents;
  const nationalTaxCode = focusNationalTaxCode({
    service,
    emitter,
    invoiceData: data,
  });
  const workSite = asTrimmedRecord(service.workSite || data.workSite);
  const workSiteCno = onlyDigits(
    workSite.cno || workSite.cno_obra || workSite.cnoObra || '',
  );
  const requiresObraGroup = FOCUS_NATIONAL_OBRA_REQUIRED_TAX_CODES.has(nationalTaxCode);
  if (requiresObraGroup && workSiteCno.length === 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Para NFSe Nacional com codigo de tributacao nacional ${nationalTaxCode}, o CNO da obra e obrigatorio (grupo de obra).`,
    );
  }
  const nationalSimpleTaxRegimeCode = focusNationalSimpleTaxRegimeCode(
    taxRegimeForFocusRules,
  );
  const simpleOptionCode =
    simplesOverride ?? focusNationalSimpleOptionCode(taxRegimeForFocusRules);
  const competenceDate = formatSaoPauloDate(serviceDate);
  const municipalityServiceCode = onlyDigits(
    asTrimmedString(service.municipalServiceCode),
  );
  const municipalTaxCode =
    municipalityServiceCode.length === 3 ? municipalityServiceCode : '';
  const customerLegalName = asTrimmedString(customer.legalName || data.clientName);
  const workSiteMunicipalityCode =
    knownMunicipalityIbgeCodeByLocation(workSite.city, workSite.state) ||
    companyMunicipalityCode;
  const serviceMunicipalityCode =
    asTrimmedString(workSite.zipCode) && workSiteMunicipalityCode
      ? workSiteMunicipalityCode
      : companyMunicipalityCode;
  if (!municipalityPattern.test(serviceMunicipalityCode)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Nao foi possivel resolver o codigo IBGE (7 digitos) do municipio de prestacao. Emitente: "${asTrimmedString(emitter.city)}" / "${asTrimmedString(emitter.state)}". Obra: "${asTrimmedString(workSite.city)}" / "${asTrimmedString(workSite.state)}".`,
    );
  }
  const totalMunicipalTributes = (issAmountCents / 100).toFixed(2);
  const fullServiceDescription = buildFocusInvoiceServiceDescription(
    asRecord(data),
    service,
    emitter,
  );

  functions.logger.info('buildFocusNationalInvoicePayload fiscal fields', {
    invoiceId: params.invoiceId,
    taxRegime,
    taxRegimeForFocusRules,
    simplesOverride,
    simpleOptionCode,
    nationalSimpleTaxRegimeCode,
    issRetained,
    rawIssRate,
    normalizedIssRate: issRate,
    taxableBaseCents,
    issAmountCents,
    inssAmountCents,
    netAmountCents,
    nationalTaxCode,
    municipalTaxCode,
    serviceMunicipalityCode,
  });

  const requiresRetainedIssAliquot =
    issRetained && simpleOptionCode === 3 && nationalSimpleTaxRegimeCode === 1;
  const forbidsIssAliquotWithoutRetention =
    !issRetained && simpleOptionCode === 3 && nationalSimpleTaxRegimeCode === 1;
  if (requiresRetainedIssAliquot && issRate < 1.8) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A NFS-e Nacional exige aliquota minima de 1,80% para Simples Nacional com ISS retido.',
    );
  }

  return {
    referencia: params.invoiceId,
    ambiente: params.environment.trim().toLowerCase() === 'producao' ? 'producao' : 'homologacao',
    data_emissao: formatSaoPauloDateTime(issueDate),
    data_competencia: competenceDate,
    codigo_municipio_emissora: companyMunicipalityCode,
    codigo_municipio_prestacao: serviceMunicipalityCode,
    cnpj_prestador: onlyDigits(emitter.cnpj || emitter.document),
    inscricao_municipal_prestador: emitterInscricaoMunicipal(emitter),
    codigo_opcao_simples_nacional: String(simpleOptionCode),
    ...(nationalSimpleTaxRegimeCode != null
      ? { regime_tributario_simples_nacional: String(nationalSimpleTaxRegimeCode) }
      : {}),
    regime_especial_tributacao: '0',
    ...(customerDocument.length === 14 ? { cnpj_tomador: customerDocument } : {}),
    ...(customerDocument.length === 11 ? { cpf_tomador: customerDocument } : {}),
    razao_social_tomador: customerLegalName,
    codigo_municipio_tomador: customerMunicipalityCode,
    cep_tomador: customerZip,
    logradouro_tomador: customerStreet,
    numero_tomador: customerNumber,
    ...(customerComplement ? { complemento_tomador: customerComplement } : {}),
    ...(customerNeighborhood ? { bairro_tomador: customerNeighborhood } : {}),
    telefone_tomador: onlyDigits(customer.phone),
    email_tomador: asTrimmedString(customer.email).toLowerCase(),
    ...(nationalTaxCode ? { codigo_tributacao_nacional_iss: nationalTaxCode } : {}),
    // No fluxo nacional, nao enviamos codigo municipal derivado automaticamente.
    // O cTribMun so deve ser enviado quando houver codigo municipal validado
    // para o municipio de incidencia; do contrario, o proprio ambiente nacional
    // parametriza a tributacao a partir do codigo nacional do servico.
    codigo_cnae: onlyDigits(service.cnae),
    descricao_servico: fullServiceDescription,
    valor_servico: Number((amountCents / 100).toFixed(2)),
    tributacao_iss: '1',
    tipo_retencao_iss: issRetained ? '2' : '1',
    valor_deducoes: Number((deductionsCents / 100).toFixed(2)),
    base_calculo: Number((taxableBaseCents / 100).toFixed(2)),
    ...(!forbidsIssAliquotWithoutRetention
      ? {
        percentual_aliquota_relativa_municipio: Number(issRate.toFixed(2)),
        aliquota: Number(issRate.toFixed(2)),
      }
      : {}),
    valor_iss: Number((issAmountCents / 100).toFixed(2)),
    ...(issRetained
      ? { valor_iss_retido: Number((issAmountCents / 100).toFixed(2)) }
      : {}),
    ...(inssAmountCents > 0
      ? { valor_cp: Number((inssAmountCents / 100).toFixed(2)) }
      : {}),
    valor_liquido: Number((netAmountCents / 100).toFixed(2)),
    natureza_operacao: normalizeOperationNatureCode(tax.operationNature),
    valor_total_tributos_federais: '0.00',
    valor_total_tributos_estaduais: '0.00',
    valor_total_tributos_municipais: totalMunicipalTributes,
    // Alguns layouts do ambiente nacional rejeitam a tag derivada de
    // indicador_total_tributacao (indTotTrib). Omitimos o campo para manter
    // compatibilidade entre municipios/versoes sem mexer no fluxo municipal.
    ...(workSiteCno.length > 0 ? { cno_obra: workSiteCno } : {}),
    ...(() => {
      const zip = onlyDigits(workSite.zipCode);
      const street = asTrimmedString(workSite.street);
      const number = asTrimmedString(workSite.number);
      const neighborhood = asTrimmedString(workSite.neighborhood);
      const complement = asTrimmedString(workSite.complement);
      const hasAnyAddressPiece =
        zip.length > 0 || street.length > 0 || number.length > 0 || neighborhood.length > 0;

      // If user started filling obra address, require minimum schema-safe fields.
      // Emissor Nacional expects "nro" before "xBairro"; sending bairro without numero breaks schema.
      if (hasAnyAddressPiece && zip.length > 0 && number.length === 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Endereco da obra incompleto: informe o NUMERO da obra (campo "Numero") ou remova CEP/endereco da obra e envie apenas o CNO.',
        );
      }

      // Only send obra address when it is complete enough to satisfy schema.
      if (zip.length === 0 || street.length === 0 || number.length === 0) {
        return {};
      }

      return {
        cep_obra: zip,
        logradouro_obra: street,
        numero_obra: number,
        ...(complement ? { complemento_obra: complement } : {}),
        ...(neighborhood ? { bairro_obra: neighborhood } : {}),
        ...(workSiteMunicipalityCode ? { codigo_municipio_obra: workSiteMunicipalityCode } : {}),
      };
    })(),
  };
}

async function issueWithFocus(params: {
  setup: Record<string, unknown>;
  invoiceId: string;
  invoiceData: FirebaseFirestore.DocumentData;
  claims: Claims;
}): Promise<Record<string, unknown>> {
  const token = asTrimmedString(params.setup.apiToken);
  const environment = asTrimmedString(params.setup.environment) || 'homologacao';
  const apiMode = focusNfseApiMode(params.setup);
  const payload =
    apiMode === 'national'
      ? await buildFocusNationalInvoicePayload({
          invoiceId: params.invoiceId,
          invoiceData: params.invoiceData,
          token,
          environment,
        })
      : await buildFocusInvoicePayload({
          invoiceId: params.invoiceId,
          invoiceData: params.invoiceData,
          token,
          environment,
        });
  const pathBase = apiMode === 'national' ? '/v2/nfsen' : '/v2/nfse';
  if (apiMode === 'national') {
    delete (payload as any).codigo_tributacao_municipal_iss;
    delete (payload as any).codigo_tributario_municipio;
    const nationalCode = asTrimmedString((payload as any).codigo_tributacao_nacional_iss);
    const fiscalPayloadSummary = {
      codigo_tributacao_nacional_iss: nationalCode,
      codigo_tributacao_municipal_iss:
        (payload as any).codigo_tributacao_municipal_iss,
      codigo_tributario_municipio: (payload as any).codigo_tributario_municipio,
      codigo_opcao_simples_nacional: (payload as any).codigo_opcao_simples_nacional,
      regime_tributario_simples_nacional:
        (payload as any).regime_tributario_simples_nacional,
      tipo_retencao_iss: (payload as any).tipo_retencao_iss,
      percentual_aliquota_relativa_municipio:
        (payload as any).percentual_aliquota_relativa_municipio,
      aliquota: (payload as any).aliquota,
      base_calculo: (payload as any).base_calculo,
      valor_iss: (payload as any).valor_iss,
      valor_iss_retido: (payload as any).valor_iss_retido,
      valor_cp: (payload as any).valor_cp,
      valor_liquido: (payload as any).valor_liquido,
    };
    functions.logger.info('focus national payload summary', {
      invoiceId: params.invoiceId,
      companyId: params.claims.companyId,
      environment,
      codigo_tributacao_nacional_iss: nationalCode,
      fiscalPayloadSummaryJson: JSON.stringify(fiscalPayloadSummary),
      has_cno_obra: Boolean((payload as any).cno_obra),
      cno_obra_len: asTrimmedString((payload as any).cno_obra).length,
    });
  }

  const createResponse = await focusRequest({
    token,
    environment,
    method: 'POST',
    path: `${pathBase}?ref=${encodeURIComponent(params.invoiceId)}`,
    body: payload,
  });
  if (createResponse.status >= 400) {
    const errMsg = focusProviderErrorMessage(
      createResponse.data,
      'A Focus rejeitou a solicitacao de emissao da nota.',
    );
    recordFocusRejectionTelemetry({
      httpStatus: createResponse.status,
      data: createResponse.data,
      messageForUser: errMsg,
      apiMode: apiMode,
    });
    throw new functions.https.HttpsError('internal', errMsg);
  }

  let latest: Record<string, unknown> = {};
  for (let attempt = 0; attempt < 5; attempt += 1) {
    if (attempt === 0) {
      await delay(3500);
    } else {
      await delay(3500);
    }
    const query = await focusRequest({
      token,
      environment,
      path: `${pathBase}/${encodeURIComponent(params.invoiceId)}`,
    });
    latest = query.data;
    const latestMap = asRecord(latest);
    const rawStatus = coalesceFocusNfseStatusRawForNormalize(latestMap) || asTrimmedString(latestMap.status);
    const status = normalizeOfficialInvoiceStatus(
      rawStatus || latestMap.status,
      focusProviderLabel(params.setup),
      'PROCESSING',
    );
    if (status !== 'PROCESSING') {
      break;
    }
  }

  return {
    ...latest,
    provider: focusProviderLabel(params.setup),
    environment,
    endpoint: `${focusServerBase(environment)}${pathBase}/${params.invoiceId}`,
    tokenPreview: maskSecret(token),
  };
}

async function cancelWithFocus(params: {
  setup: Record<string, unknown>;
  invoiceId: string;
  claims: Claims;
}): Promise<Record<string, unknown>> {
  const token = asTrimmedString(params.setup.apiToken);
  const environment = asTrimmedString(params.setup.environment) || 'homologacao';
  const apiMode = focusNfseApiMode(params.setup);
  const pathBase = apiMode === 'national' ? '/v2/nfsen' : '/v2/nfse';
  const response = await focusRequest({
    token,
    environment,
    method: 'DELETE',
    path: `${pathBase}/${encodeURIComponent(params.invoiceId)}`,
  });
  return {
    ...response.data,
    provider: focusProviderLabel(params.setup),
    environment,
    endpoint: `${focusServerBase(environment)}${pathBase}/${params.invoiceId}`,
    tokenPreview: maskSecret(token),
  };
}

async function queryWithFocus(params: {
  setup: Record<string, unknown>;
  invoiceId: string;
  claims: Claims;
}): Promise<Record<string, unknown>> {
  const token = asTrimmedString(params.setup.apiToken);
  const environment = asTrimmedString(params.setup.environment) || 'homologacao';
  const apiMode = focusNfseApiMode(params.setup);
  const pathBase = apiMode === 'national' ? '/v2/nfsen' : '/v2/nfse';
  const response = await focusRequest({
    token,
    environment,
    path: `${pathBase}/${encodeURIComponent(params.invoiceId)}`,
  });
  return {
    ...response.data,
    provider: focusProviderLabel(params.setup),
    environment,
    endpoint: `${focusServerBase(environment)}${pathBase}/${params.invoiceId}`,
    tokenPreview: maskSecret(token),
  };
}

async function callFiscalProvider(params: {
  setup: Record<string, unknown>;
  operation: 'issue' | 'cancel' | 'query';
  invoiceId: string;
  invoiceData: FirebaseFirestore.DocumentData;
  claims: Claims;
  reason?: string;
}): Promise<Record<string, unknown>> {
  const environment = asTrimmedString(params.setup.environment) || 'homologacao';
  const provider = asTrimmedString(params.setup.provider) || 'provedor_externo';
  if (providerIsFocus(provider)) {
    if (params.operation === 'issue') {
      return issueWithFocus({
        setup: params.setup,
        invoiceId: params.invoiceId,
        invoiceData: params.invoiceData,
        claims: params.claims,
      });
    }
    if (params.operation === 'cancel') {
      return cancelWithFocus({
        setup: params.setup,
        invoiceId: params.invoiceId,
        claims: params.claims,
      });
    }
    return queryWithFocus({
      setup: params.setup,
      invoiceId: params.invoiceId,
      claims: params.claims,
    });
  }

  const apiBaseUrl = asTrimmedString(params.setup.apiBaseUrl);
  if (!apiBaseUrl) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Base URL da integracao fiscal nao configurada.',
    );
  }

  const apiToken = asTrimmedString(params.setup.apiToken);
  const endpoint = apiBaseUrl.endsWith('/')
    ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
    : apiBaseUrl;

  const requestBody = {
    action:
      params.operation === 'issue'
        ? 'issue_nfse'
        : params.operation === 'cancel'
        ? 'cancel_nfse'
        : 'query_nfse',
    environment,
    provider,
    companyId: params.claims.companyId,
    invoiceId: params.invoiceId,
    reason: params.reason ?? '',
    invoice: params.invoiceData,
  };

  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'x-company-id': params.claims.companyId,
    'x-fiscal-environment': environment,
    'x-fiscal-provider': provider,
  };
  if (apiToken) {
    headers.authorization = `Bearer ${apiToken}`;
    headers['x-api-token'] = apiToken;
  }

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(requestBody),
    });
  } catch (error: unknown) {
    throw new functions.https.HttpsError(
      'unavailable',
      `Falha ao conectar no endpoint fiscal: ${String(error)}`,
    );
  }

  const rawText = await response.text();
  let parsed: Record<string, unknown> = {};
  if (rawText.trim().length > 0) {
    try {
      parsed = asRecord(JSON.parse(rawText));
    } catch (_) {
      parsed = { rawText };
    }
  }

  if (!response.ok) {
    const providerMessage =
      asTrimmedString(parsed.message) ||
      asTrimmedString(parsed.error) ||
      rawText.trim();
    throw new functions.https.HttpsError(
      'internal',
      providerMessage.length > 0
          ? providerMessage
          : `Falha fiscal no provedor (${response.status}).`,
    );
  }

  return {
    httpStatus: response.status,
    ...parsed,
    provider,
    environment,
    endpoint,
    tokenPreview: maskSecret(apiToken),
  };
}

async function writeAudit(params: {
  claims: Claims;
  module: string;
  action: string;
  entityPath: string;
  entityId: string;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  tx?: FirebaseFirestore.Transaction;
}): Promise<void> {
  const ref = admin.firestore().collection('audit_logs').doc();
  const payload: FirebaseFirestore.DocumentData = {
    companyId: params.claims.companyId,
    actorUserId: params.claims.uid,
    actorRole: params.claims.role,
    module: params.module,
    action: params.action,
    entityPath: params.entityPath,
    entityId: params.entityId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (params.before) payload.before = params.before;
  if (params.after) payload.after = params.after;

  if (params.tx) {
    params.tx.set(ref, payload);
    return;
  }

  await ref.set(payload);
}

function ensureEmployeeOwner(paymentOrDebtEmployeeId: string, claims: Claims): void {
  if (claims.role !== 'EMPLOYEE') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas EMPLOYEE pode executar esta acao.');
  }
  if (paymentOrDebtEmployeeId !== claims.employeeId) {
    throw new functions.https.HttpsError('permission-denied', 'Operacao permitida apenas para o proprio registro.');
  }
}

function mapCompanyData(data: unknown): Record<string, unknown> | null {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
  return data as Record<string, unknown>;
}

function slugifyFiscalText(value: unknown): string {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function knownMunicipalityIbgeCodeByLocation(cityValue: unknown, stateValue: unknown): string {
  const city = slugifyFiscalText(cityValue);
  const state = slugifyFiscalText(stateValue);
  // Hidrolândia-GO (IBGE) and tolerance for "goias"
  if (city === 'hidrolandia' && (state === 'go' || state === 'goias')) return '5209705';
  // Hidrolândia-CE (IBGE)
  if (city === 'hidrolandia' && (state === 'ce' || state === 'ceara')) return '2305230';
  // Brasília-DF (IBGE) and tolerance for variations ("DF - Distrito Federal", etc.)
  const isDf = state === 'df' || state.includes('df') || state.includes('distrito_federal');
  if (city === 'brasilia' && isDf) return '5300108';
  if (city === 'goiania' && state === 'go') return '5208707';
  return '';
}

function asTrimmedRecord(value: unknown): Record<string, unknown> {
  return asRecord(value);
}

function companyIbgeCode(companyData: Record<string, unknown>): string {
  const explicit = asTrimmedString(
    companyData.codigoMunicipio ||
      companyData.cityCode ||
      companyData.ibgeCode ||
      companyData.codigoIbge,
  );
  if (explicit) return explicit;
  return knownMunicipalityIbgeCodeByLocation(
    companyData.cidade || companyData.city || companyData.municipio,
    companyData.estado || companyData.state || companyData.uf,
  );
}

/** Prestador: app historico gravava apenas municipalRegistration no emitter. */
function emitterInscricaoMunicipal(emitter: Record<string, unknown>): string {
  const direct = asTrimmedString(emitter.inscricaoMunicipal);
  if (direct) return direct;
  return asTrimmedString(emitter.municipalRegistration);
}

function isKnownNationalNfseMunicipality(companyData: Record<string, unknown>): boolean {
  const city = slugifyFiscalText(companyData.cidade || companyData.city || companyData.municipio);
  const state = slugifyFiscalText(companyData.estado || companyData.state || companyData.uf);
  const ibge = companyIbgeCode(companyData);
  return (
    (city === 'hidrolandia' && state === 'go') ||
    ibge === '5209705'
  );
}

async function resolveFiscalMunicipalityRoute(
  companyData: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const ibge = companyIbgeCode(companyData);
  const city = asTrimmedString(
    companyData.cidade || companyData.city || companyData.municipio,
  );
  const state = asTrimmedString(companyData.estado || companyData.state || companyData.uf)
    .toUpperCase();
  const slug = `${slugifyFiscalText(state)}_${slugifyFiscalText(city)}`;

  const routeDocIds = [
    ...(ibge ? [`ibge_${ibge}`] : []),
    ...(slug !== '_' ? [slug] : []),
  ];

  for (const docId of routeDocIds) {
    const snap = await admin
      .firestore()
      .collection('fiscal_municipality_routes')
      .doc(docId)
      .get();
    if (snap.exists) {
      return {
        found: true,
        source: 'firestore_route',
        ...(snap.data() ?? {}),
      };
    }
  }

  if (isKnownNationalNfseMunicipality(companyData)) {
    return {
      found: true,
      source: 'built_in_rule',
      routeType: 'focus_national',
      provider: 'Focus NFe',
      focusNfseApi: 'national',
      detectionReason:
        'Municipio identificado como aderente ao ambiente nacional da NFSe.',
    };
  }

  return {
    found: false,
    source: 'default_rule',
  };
}

async function buildRecommendedFiscalSetup(params: {
  companyId: string;
  companyData: Record<string, unknown>;
  currentSettings: Record<string, unknown>;
}): Promise<{
  routing: Record<string, unknown>;
  realIntegration: Record<string, unknown>;
  fiscalFeatures: Record<string, unknown>;
}> {
  const companyData = params.companyData;
  const currentSettings = params.currentSettings;
  const platformFocus = obterConfigFocusPlatform();
  const currentIntegration = asRecord(currentSettings.fiscalRealIntegration);
  const currentRouting = asRecord(currentSettings.fiscalRouting);
  const currentFeatures = asRecord(currentSettings.fiscalFeatures);
  const municipalRoute = await resolveFiscalMunicipalityRoute(companyData);
  const serviceBusiness = companyIsServiceBusiness(companyData);
  const city = asTrimmedString(
    companyData.cidade || companyData.city || companyData.municipio,
  );
  const state = asTrimmedString(companyData.estado || companyData.state || companyData.uf)
    .toUpperCase();
  const ibgeCode = companyIbgeCode(companyData);
  const routeType = asTrimmedString(municipalRoute.routeType) ||
    (serviceBusiness ? 'focus_municipal' : 'manual_review');
  const focusApi =
    asTrimmedString(municipalRoute.focusNfseApi) ||
    (routeType === 'focus_national' ? 'national' : 'municipal');
  const recommendedProvider =
    asTrimmedString(municipalRoute.provider) ||
    (serviceBusiness ? 'Focus NFe' : 'Prefeitura direta');
  const requiresManualReview =
    !city ||
    !state ||
    routeType === 'manual_review' ||
    currentRouting.manualOverride === true;
  const municipalCode =
    asTrimmedString(currentIntegration.municipalCode) ||
    asTrimmedString(
      companyData.mainCnae ||
        companyData.codigoServicoPadrao ||
        companyData.defaultServiceCode,
    );
  const hasCompanyToken = asTrimmedString(currentIntegration.apiToken).length > 0;
  const hasPlatformToken = asTrimmedString(platformFocus.apiToken).length > 0;
  const useFocus = recommendedProvider.toLowerCase().includes('focus');
  const usesPlatformFocusToken =
    useFocus && !hasCompanyToken && hasPlatformToken;
  const providerShouldBeAutoFilled =
    !asTrimmedString(currentIntegration.provider) ||
    asTrimmedString(currentIntegration.provider) ===
      'Prefeitura / integrador a definir';

  const routing = {
    routeType,
    provider: recommendedProvider,
    focusNfseApi: recommendedProvider.toLowerCase().includes('focus')
      ? focusApi
      : '',
    city,
    state,
    ibgeCode,
    companyId: params.companyId,
    source: asTrimmedString(municipalRoute.source) || 'default_rule',
    detectionReason:
      asTrimmedString(municipalRoute.detectionReason) ||
      (serviceBusiness
        ? 'Empresa de servicos direcionada automaticamente para fluxo Focus multiempresa.'
        : 'Empresa fora do fluxo padrao automatico; revisar emissao manualmente.'),
    requiresManualReview,
    manualOverride: currentRouting.manualOverride === true,
    autoDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
    autoDetectionSource:
      asTrimmedString(municipalRoute.source) || 'backend_auto_setup',
  };

  const realIntegration = {
    environment:
      asTrimmedString(currentIntegration.environment) || platformFocus.environment || 'homologacao',
    provider: providerShouldBeAutoFilled
      ? recommendedProvider
      : asTrimmedString(currentIntegration.provider),
    focusNfseApi:
      recommendedProvider.toLowerCase().includes('focus')
        ? asTrimmedString(currentIntegration.focusNfseApi) || focusApi
        : '',
    municipalCode,
    certificateRef: asTrimmedString(currentIntegration.certificateRef),
    apiBaseUrl:
      asTrimmedString(currentIntegration.apiBaseUrl) ||
      (recommendedProvider.toLowerCase().includes('focus')
        ? 'https://homologacao.focusnfe.com.br'
        : ''),
    // Nunca persistir o token global da plataforma no Firestore (seguranca).
    apiToken: hasCompanyToken ? asTrimmedString(currentIntegration.apiToken) : '',
    usesPlatformFocusToken: usesPlatformFocusToken,
    lastHomologationNote:
      asTrimmedString(currentIntegration.lastHomologationNote) ||
      'Estrutura fiscal inicial criada automaticamente no onboarding. Validar certificado, municipio, token e homologacao antes da emissao oficial.',
  };

  const fiscalFeatures = {
    ...currentFeatures,
    enableOfficialInvoicePrep: true,
    enableRealInvoiceIntegration: hasCompanyToken || usesPlatformFocusToken,
  };

  return {
    routing,
    realIntegration,
    fiscalFeatures,
  };
}

function buildFocusProvisioningStatus(params: {
  companyData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
}): { shouldSync: boolean; status: string; missing: string[] } {
  const companyData = params.companyData;
  const settingsData = params.settingsData;
  const routing = asRecord(settingsData.fiscalRouting);
  const setup = asRecord(settingsData.fiscalRealIntegration);
  const certificate = asRecord(settingsData.fiscalCertificate);
  const missing: string[] = [];

  if (!providerIsFocus(asTrimmedString(setup.provider))) {
    return {
      shouldSync: false,
      status: 'SKIPPED',
      missing: ['provedor nao configurado para Focus'],
    };
  }

  if (routing.requiresManualReview === true) {
    missing.push('revisao manual da rota fiscal');
  }
  if (!onlyDigits(companyData.cnpj)) {
    missing.push('cnpj');
  }
  if (!asTrimmedString(companyData.inscricaoMunicipal)) {
    missing.push('inscricao municipal');
  }
  if (!asTrimmedString(companyData.cidade)) {
    missing.push('cidade');
  }
  if (!asTrimmedString(companyData.estado)) {
    missing.push('uf');
  }
  const platformFocusToken = obterConfigFocusPlatform().apiToken;
  const effectiveApiToken = asTrimmedString(setup.apiToken) || platformFocusToken;
  if (!asTrimmedString(effectiveApiToken)) {
    missing.push('token api');
  }
  if (!asTrimmedString(certificate.storagePath)) {
    missing.push('certificado digital');
  }
  if (!asTrimmedString(certificate.password)) {
    missing.push('senha do certificado');
  }

  return {
    shouldSync: missing.length === 0,
    status: missing.length === 0 ? 'READY' : 'PENDING',
    missing,
  };
}

async function autoProvisionFocusCompanyIfReady(params: {
  claims: Claims;
  companyData: Record<string, unknown>;
  settingsData: Record<string, unknown>;
}): Promise<Record<string, unknown>> {
  const settingsRef = admin
    .firestore()
    .collection('company_settings')
    .doc(params.claims.companyId);
  const readiness = buildFocusProvisioningStatus({
    companyData: params.companyData,
    settingsData: params.settingsData,
  });

  if (!providerIsFocus(asTrimmedString(asRecord(params.settingsData.fiscalRealIntegration).provider))) {
    await settingsRef.set(
      {
        focusProvisioning: {
          status: 'SKIPPED',
          missing: readiness.missing,
          lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
    return { status: 'SKIPPED', synced: false, missing: readiness.missing };
  }

  if (!readiness.shouldSync) {
    await settingsRef.set(
      {
        focusProvisioning: {
          status: 'PENDING',
          missing: readiness.missing,
          lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
    return { status: 'PENDING', synced: false, missing: readiness.missing };
  }

  try {
    const result = await syncFocusCompany({
      claims: params.claims,
      companyData: params.companyData,
      settingsData: params.settingsData,
    });
    await settingsRef.set(
      {
        focusProvisioning: {
          status: 'SYNCED',
          missing: [],
          focusCompanyId: asTrimmedString(result.id),
          lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
    return {
      status: 'SYNCED',
      synced: true,
      missing: [],
      focusCompanyId: asTrimmedString(result.id),
    };
  } catch (error: unknown) {
    const message = errorMessage(
      error,
      'Falha ao provisionar automaticamente a empresa na Focus.',
    );
    await settingsRef.set(
      {
        focusProvisioning: {
          status: 'ERROR',
          missing: [],
          lastError: message,
          lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
    return {
      status: 'ERROR',
      synced: false,
      missing: [],
      error: message,
    };
  }
}

async function mergeFiscalSecureSettings(
  companyId: string,
  settingsData: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const secureSnap = await admin.firestore().collection('fiscal_secure').doc(companyId).get();
  const secureData = asRecord(secureSnap.data());
  const certificateSecrets = asRecord(secureData.fiscalCertificateSecrets);
  const certificate = asRecord(settingsData.fiscalCertificate);
  return {
    ...settingsData,
    fiscalCertificate: {
      ...certificate,
      ...certificateSecrets,
    },
  };
}

function onlyDigits(value: unknown): string {
  return String(value ?? '').replace(/\D/g, '');
}

function formatBrazilCnpjForDisplay(value: unknown): string {
  const d = onlyDigits(value);
  if (d.length !== 14) return '';
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12, 14)}`;
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

type FocusIncomingDocumentKind = 'nfe' | 'nfse_nacional';

function normalizeFocusIncomingDocumentKind(value: unknown): FocusIncomingDocumentKind {
  const normalized = asTrimmedString(value).toLowerCase();
  if (normalized === 'nfse_nacional' || normalized === 'nfsen') {
    return 'nfse_nacional';
  }
  return 'nfe';
}

function buildFocusIncomingDocumentDocId(kind: FocusIncomingDocumentKind, accessKey: string): string {
  return `${kind}_${accessKey.replace(/[^a-zA-Z0-9_-]/g, '')}`;
}

function fiscalCompanyRef(companyId: string) {
  return admin.firestore().collection('empresas').doc(companyId);
}

function fiscalCompanyDocumentsRef(companyId: string) {
  return fiscalCompanyRef(companyId).collection('documentos_fiscais');
}

function fiscalCompanyXmlSyncLogsRef(companyId: string) {
  return fiscalCompanyRef(companyId).collection('xml_sync_logs');
}

function fiscalIncomingXmlStoragePath(companyId: string, accessKey: string): string {
  const safeKey = accessKey.replace(/[^a-zA-Z0-9_-]/g, '');
  return `documentos/${companyId}/xml/${safeKey}.xml`;
}

function coerceUnknownList(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  const record = asRecord(value);
  if (Array.isArray(record.items)) return record.items;
  if (Array.isArray(record.data)) return record.data;
  if (Array.isArray(record.documentos)) return record.documentos;
  if (Array.isArray(record.notas)) return record.notas;
  if (Array.isArray(record.nfes)) return record.nfes;
  if (Array.isArray(record.nfses)) return record.nfses;
  return [];
}

function pickFirstString(
  record: Record<string, unknown>,
  keys: string[],
): string {
  for (const finalKey of keys) {
    const value = asTrimmedString(record[finalKey]);
    if (value) return value;
  }
  return '';
}

function pickFirstNumber(
  record: Record<string, unknown>,
  keys: string[],
): number | null {
  for (const key of keys) {
    const raw = record[key];
    if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
    const parsed = Number(String(raw ?? '').replace(',', '.'));
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function pickFirstTimestamp(
  record: Record<string, unknown>,
  keys: string[],
): admin.firestore.Timestamp | null {
  for (const key of keys) {
    const parsed = parseTimestampLike(record[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

function extractFocusIncomingXmlContent(value: unknown): string {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.startsWith('<') ? trimmed : '';
  }
  const record = asRecord(value);
  const direct = pickFirstString(record, [
    'xml',
    'xml_nfe',
    'xml_nfse',
    'conteudo_xml',
    'xmlContent',
    'rawXml',
  ]);
  if (direct.trim().startsWith('<')) return direct.trim();

  for (const nestedKey of ['documento', 'nota', 'nfse', 'nfe', 'conteudo']) {
    const nested = extractFocusIncomingXmlContent(record[nestedKey]);
    if (nested) return nested;
  }
  return '';
}

function normalizeFiscalDocumentType(
  kind: FocusIncomingDocumentKind,
  item: Record<string, unknown>,
): string {
  const raw =
    pickFirstString(item, ['tipo', 'modelo', 'documentType', 'document_type'])
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '');
  if (raw === 'NFCE') return 'NFCE';
  if (kind === 'nfse_nacional') return 'NFSE_NACIONAL';
  return 'NFE';
}

function pickFirstNsu(item: Record<string, unknown>, fallbackVersion: number): string {
  const direct = pickFirstString(item, [
    'nsu',
    'ultimo_nsu',
    'last_nsu',
    'sequencia',
    'sequence',
    'versao',
    'version',
  ]);
  if (direct) return direct;
  return fallbackVersion > 0 ? String(fallbackVersion) : '';
}

function buildFiscalIncomingTaxPlaceholders(item: Record<string, unknown>): Record<string, unknown> {
  const taxes = asRecord(item.impostos);
  return {
    icms: asRecord(taxes.icms),
    icms_st: asRecord(taxes.icms_st),
    pis: asRecord(taxes.pis),
    cofins: asRecord(taxes.cofins),
    ibs: asRecord(taxes.ibs),
    cbs: asRecord(taxes.cbs),
    is: asRecord(taxes.is),
  };
}

function buildFiscalIncomingItems(item: Record<string, unknown>): Array<Record<string, unknown>> {
  const rawItems = coerceUnknownList(item.itens);
  return rawItems
    .map((entry) => asRecord(entry))
    .filter((entry) => Object.keys(entry).length > 0)
    .map((entry) => ({
      descricao: pickFirstString(entry, ['descricao', 'nome', 'xProd']),
      ncm: pickFirstString(entry, ['ncm']),
      cfop: pickFirstString(entry, ['cfop']),
      valor: pickFirstNumber(entry, ['valor', 'valor_total', 'vProd']),
      impostos: buildFiscalIncomingTaxPlaceholders(entry),
    }));
}

function summarizeFocusIncomingDocument(params: {
  kind: FocusIncomingDocumentKind;
  companyId: string;
  companyCnpj: string;
  item: Record<string, unknown>;
}): Record<string, unknown> {
  const item = params.item;
  const accessKey = pickFirstString(item, [
    'chave',
    'chave_acesso',
    'access_key',
    'accessKey',
    'nfe_chave',
    'nfse_chave',
  ]);
  const version =
    pickFirstNumber(item, ['versao', 'version']) ?? 0;
  const nsu = pickFirstNsu(item, version);
  const xmlContent = extractFocusIncomingXmlContent(item);
  const totalValue =
    pickFirstNumber(item, [
      'valor',
      'valor_total',
      'valor_nota',
      'valor_servicos',
      'valor_liquido',
    ]);
  const issuer = asRecord(item.emitente);
  const recipient = asRecord(item.destinatario);
  const provider = asRecord(item.prestador);
  const taker = asRecord(item.tomador);
  const fiscalType = normalizeFiscalDocumentType(params.kind, item);
  const issuedAt =
    pickFirstTimestamp(item, [
      'data_emissao',
      'emitida_em',
      'data_competencia',
      'data_recebimento',
      'dhEmi',
    ]);
  const receivedAt =
    pickFirstTimestamp(item, ['data_recebimento', 'recebida_em']);
  const issuerDocument =
    pickFirstString(issuer, ['cnpj', 'cpf']) ||
    pickFirstString(provider, ['cnpj', 'cpf']) ||
    pickFirstString(item, ['emitente_cnpj', 'prestador_cnpj']);
  const recipientDocument =
    pickFirstString(recipient, ['cnpj', 'cpf']) ||
    pickFirstString(taker, ['cnpj', 'cpf']) ||
    pickFirstString(item, ['destinatario_cnpj', 'tomador_cnpj']);

  return {
    companyId: params.companyId,
    receivedCompanyCnpj: params.companyCnpj,
    chave: accessKey,
    nsu,
    tipo: fiscalType,
    origem: 'focus',
    documentType: params.kind,
    accessKey,
    version,
    status: pickFirstString(item, ['status', 'situacao']) || 'novo',
    manifestStatus: pickFirstString(item, [
      'manifestacao',
      'manifestacao_destinatario',
      'manifest_status',
    ]),
    number: pickFirstString(item, ['numero', 'numero_nf', 'n_nfse', 'nfe_numero']),
    series: pickFirstString(item, ['serie']),
    emitente:
      pickFirstString(issuer, ['razao_social', 'nome']) ||
      pickFirstString(provider, ['razao_social', 'nome']) ||
      pickFirstString(item, ['emitente_nome', 'prestador_nome']),
    cnpj_emitente: onlyDigits(issuerDocument),
    destinatario:
      pickFirstString(recipient, ['razao_social', 'nome']) ||
      pickFirstString(taker, ['razao_social', 'nome']) ||
      pickFirstString(item, ['destinatario_nome', 'tomador_nome']),
    cnpj_destinatario: onlyDigits(recipientDocument),
    valor_total: totalValue,
    data_emissao: issuedAt || admin.firestore.FieldValue.delete(),
    xml_path:
      xmlContent.length > 0 ? fiscalIncomingXmlStoragePath(params.companyId, accessKey) : '',
    xml_disponivel: xmlContent.length > 0,
    xml_tamanho_bytes: xmlContent.length,
    xml_capturado_em:
      xmlContent.length > 0
        ? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.delete(),
    issuerName:
      pickFirstString(issuer, ['razao_social', 'nome']) ||
      pickFirstString(provider, ['razao_social', 'nome']) ||
      pickFirstString(item, ['emitente_nome', 'prestador_nome']),
    issuerDocument,
    recipientName:
      pickFirstString(recipient, ['razao_social', 'nome']) ||
      pickFirstString(taker, ['razao_social', 'nome']) ||
      pickFirstString(item, ['destinatario_nome', 'tomador_nome']),
    recipientDocument,
    totalValue,
    issuedAt: issuedAt || admin.firestore.FieldValue.delete(),
    receivedAt: receivedAt || admin.firestore.FieldValue.serverTimestamp(),
    impostos: buildFiscalIncomingTaxPlaceholders(item),
    itens: buildFiscalIncomingItems(item),
    criado_em: admin.firestore.FieldValue.serverTimestamp(),
    atualizado_em: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function loadFocusIncomingSyncContext(claims: Claims): Promise<{
  companyData: Record<string, unknown>;
  token: string;
  environment: string;
  cnpj: string;
}> {
  const settingsSnap = await admin
    .firestore()
    .collection('company_settings')
    .doc(claims.companyId)
    .get();
  if (!settingsSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'company_settings nao encontrado.');
  }

  const mergedSettings = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  const companyData = asRecord(mergedSettings.companyData);
  const cnpj = onlyDigits(companyData.cnpj);
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A empresa ativa precisa ter CNPJ valido no cadastro para capturar XML.',
    );
  }

  const integration = asRecord(mergedSettings.fiscalRealIntegration);
  const platformFocus = obterConfigFocusPlatform();
  const token = asTrimmedString(integration.apiToken) || platformFocus.apiToken;
  const environment =
    asTrimmedString(integration.environment) ||
    platformFocus.environment ||
    'homologacao';
  if (!token) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Nao existe token Focus configurado para capturar documentos recebidos.',
    );
  }

  return {companyData, token, environment, cnpj};
}

async function writeFiscalIncomingXmlIfAvailable(params: {
  companyId: string;
  accessKey: string;
  xmlContent: string;
}): Promise<string> {
  const xml = params.xmlContent.trim();
  if (!xml) return '';
  const storagePath = fiscalIncomingXmlStoragePath(params.companyId, params.accessKey);
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  await file.save(Buffer.from(xml, 'utf8'), {
    contentType: 'application/xml; charset=utf-8',
    resumable: false,
    metadata: {
      contentType: 'application/xml; charset=utf-8',
    },
  });
  return storagePath;
}

exports.fiscalSyncFocusIncomingDocuments = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);

  const kind = normalizeFocusIncomingDocumentKind(data?.documentType);
  const syncContext = await loadFocusIncomingSyncContext(claims);
  const companyRef = fiscalCompanyRef(claims.companyId);
  const companySnap = await companyRef.get();
  const companyData = asRecord(companySnap.data());
  const syncState = asRecord(asRecord(companyData.xml_sync_state)[kind]);
  const lastNsuRaw =
    asTrimmedString(syncState.ultimo_nsu) ||
    asTrimmedString(syncState.lastVersion) ||
    asTrimmedString(companyData.ultimo_nsu);
  const lastVersion = parseNonNegativeInt(lastNsuRaw || 0, 'lastVersion');
  const query = new URLSearchParams({
    cnpj: syncContext.cnpj,
    ...(lastVersion > 0 ? {versao: String(lastVersion)} : {}),
    ...(kind === 'nfse_nacional' ? {completa: '1'} : {}),
  });

  const response = await focusRequestAny({
    token: syncContext.token,
    environment: syncContext.environment,
    path:
      kind === 'nfse_nacional'
        ? `/v2/nfsens_recebidas?${query.toString()}`
        : `/v2/nfes_recebidas?${query.toString()}`,
  });

  const items = coerceUnknownList(response.data)
    .map((item) => asRecord(item))
    .filter((item) => Object.keys(item).length > 0);

  let maxVersion = lastVersion;
  let maxNsu = lastNsuRaw;
  let capturedWithXml = 0;
  const processStartedAt = admin.firestore.FieldValue.serverTimestamp();
  const logRef = fiscalCompanyXmlSyncLogsRef(claims.companyId).doc();

  await companyRef.set(
    {
      cnpj: syncContext.cnpj,
      status_fiscal: 'ativo',
      xml_sync_status: 'processando',
      xml_ultima_sincronizacao: processStartedAt,
      xml_ultimo_erro: admin.firestore.FieldValue.delete(),
    },
    {merge: true},
  );

  await logRef.set({
    companyId: claims.companyId,
    documentType: kind,
    origem: 'focus',
    modo_execucao: 'manual',
    actorUserId: claims.uid,
    actorRole: claims.role,
    iniciado_em: admin.firestore.FieldValue.serverTimestamp(),
    status: 'processando',
    ultimo_nsu_entrada: lastNsuRaw,
    cnpj: syncContext.cnpj,
  });

  try {
    const writes: Array<Promise<FirebaseFirestore.WriteResult>> = [];
    for (const item of items) {
      const summary = summarizeFocusIncomingDocument({
        kind,
        companyId: claims.companyId,
        companyCnpj: syncContext.cnpj,
        item,
      });
      const accessKey = asTrimmedString(summary.accessKey);
      if (!accessKey) continue;
      const version = Number(summary.version ?? 0);
      if (Number.isFinite(version) && version > maxVersion) {
        maxVersion = version;
      }
      const nsu = asTrimmedString(summary.nsu);
      if (nsu) {
        const nsuAsNumber = Number(nsu);
        const maxNsuAsNumber = Number(maxNsu);
        if (
          !maxNsu ||
          (Number.isFinite(nsuAsNumber) &&
            (!Number.isFinite(maxNsuAsNumber) || nsuAsNumber > maxNsuAsNumber))
        ) {
          maxNsu = nsu;
        }
      }
      const xmlContent = extractFocusIncomingXmlContent(item);
      let xmlPath = asTrimmedString(summary.xml_path);
      if (xmlContent) {
        xmlPath = await writeFiscalIncomingXmlIfAvailable({
          companyId: claims.companyId,
          accessKey,
          xmlContent,
        });
        capturedWithXml += 1;
      }
      writes.push(
        fiscalCompanyDocumentsRef(claims.companyId)
          .doc(buildFocusIncomingDocumentDocId(kind, accessKey))
          .set(
            {
              ...summary,
              xml_path: xmlPath,
              xml_disponivel: xmlPath.length > 0,
              criado_em: admin.firestore.FieldValue.serverTimestamp(),
              atualizado_em: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
          ),
      );
    }

    await Promise.all(writes);

    const headerMaxVersion = Number(response.headers.get('x-max-version') || '0');
    if (Number.isFinite(headerMaxVersion) && headerMaxVersion > maxVersion) {
      maxVersion = headerMaxVersion;
    }
    if (!maxNsu && maxVersion > 0) {
      maxNsu = String(maxVersion);
    }

    await companyRef.set(
      {
        cnpj: syncContext.cnpj,
        status_fiscal: 'ativo',
        ultimo_nsu: maxNsu,
        xml_sync_status: 'ativo',
        xml_ultima_sincronizacao: admin.firestore.FieldValue.serverTimestamp(),
        xml_ultimo_erro: admin.firestore.FieldValue.delete(),
        xml_sync_state: {
          [kind]: {
            ultimo_nsu: maxNsu,
            lastVersion: maxVersion,
            xml_sync_status: 'ativo',
            xml_ultima_sincronizacao: admin.firestore.FieldValue.serverTimestamp(),
            documentsFetched: items.length,
            xmlCaptured: capturedWithXml,
            cnpj: syncContext.cnpj,
            environment: syncContext.environment,
          },
        },
      },
      {merge: true},
    );

    await logRef.set(
      {
        status: 'sucesso',
        finalizado_em: admin.firestore.FieldValue.serverTimestamp(),
        quantidade_encontrados: items.length,
        quantidade_importados: items.length,
        quantidade_xml_importados: capturedWithXml,
        ultimo_nsu_saida: maxNsu,
      },
      {merge: true},
    );

    await writeAudit({
      claims,
      module: 'fiscal_xml_import',
      action: 'focus_sync_manual_completed',
      entityPath: `empresas/${claims.companyId}/documentos_fiscais`,
      entityId: kind,
      after: {
        documentType: kind,
        found: items.length,
        imported: items.length,
        xmlCaptured: capturedWithXml,
        ultimoNsu: maxNsu,
      },
    });
  } catch (error: unknown) {
    const message = errorMessage(
      error,
      'Falha ao sincronizar documentos fiscais recebidos via Focus.',
    );
    await companyRef.set(
      {
        cnpj: syncContext.cnpj,
        status_fiscal: 'ativo',
        xml_sync_status: 'erro',
        xml_ultima_sincronizacao: admin.firestore.FieldValue.serverTimestamp(),
        xml_ultimo_erro: message,
        xml_sync_state: {
          [kind]: {
            ultimo_nsu: lastNsuRaw,
            lastVersion,
            xml_sync_status: 'erro',
            xml_ultima_sincronizacao: admin.firestore.FieldValue.serverTimestamp(),
            erro: message,
            cnpj: syncContext.cnpj,
            environment: syncContext.environment,
          },
        },
      },
      {merge: true},
    );
    await logRef.set(
      {
        status: 'erro',
        finalizado_em: admin.firestore.FieldValue.serverTimestamp(),
        quantidade_encontrados: items.length,
        quantidade_importados: 0,
        quantidade_xml_importados: capturedWithXml,
        erro: message,
      },
      {merge: true},
    );
    await writeAudit({
      claims,
      module: 'fiscal_xml_import',
      action: 'focus_sync_manual_failed',
      entityPath: `empresas/${claims.companyId}/documentos_fiscais`,
      entityId: kind,
      after: {
        documentType: kind,
        error: message,
        found: items.length,
      },
    });
    throw error;
  }

  return {
    ok: true,
    documentType: kind,
    companyId: claims.companyId,
    cnpj: syncContext.cnpj,
    documentsFetched: items.length,
    xmlCaptured: capturedWithXml,
    lastVersion: maxVersion,
    ultimoNsu: maxNsu,
  };
});

exports.fiscalDownloadImportedXml = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);

  const documentId = asTrimmedString(data?.documentId);
  if (!documentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Informe o documento fiscal.');
  }

  const docSnap = await fiscalCompanyDocumentsRef(claims.companyId).doc(documentId).get();
  if (!docSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Documento fiscal nao encontrado.');
  }

  const docData = asRecord(docSnap.data());
  const xmlPath = asTrimmedString(docData.xml_path);
  if (!xmlPath) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Este documento ainda nao possui XML salvo para download.',
    );
  }

  const [buffer] = await admin.storage().bucket().file(xmlPath).download();
  return {
    ok: true,
    documentId,
    fileName: `${asTrimmedString(docData.chave) || documentId}.xml`,
    contentType: 'application/xml',
    base64: buffer.toString('base64'),
  };
});

function toAsaasMoneyValue(valueCents: unknown): number {
  const cents = Number(valueCents ?? 0);
  if (!Number.isFinite(cents) || cents <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Valor mensal invalido para provisionar no Asaas.',
    );
  }
  return Math.round(cents) / 100;
}

function formatCurrencyBr(valueCents: unknown): string {
  const cents = Number(valueCents ?? 0);
  const value = Number.isFinite(cents) ? cents / 100 : 0;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
}

function asaasSubscriptionCycle(value: unknown): string {
  const normalized = asTrimmedString(value).toUpperCase();
  if (normalized === 'WEEKLY') return 'WEEKLY';
  if (normalized === 'BIWEEKLY') return 'BIWEEKLY';
  if (normalized === 'MONTHLY') return 'MONTHLY';
  if (normalized === 'BIMONTHLY') return 'BIMONTHLY';
  if (normalized === 'QUARTERLY') return 'QUARTERLY';
  if (normalized === 'SEMIANNUALLY') return 'SEMIANNUALLY';
  if (normalized === 'YEARLY') return 'YEARLY';
  return 'MONTHLY';
}

function asaasBillingType(value: unknown): string {
  const normalized = asTrimmedString(value).toUpperCase();
  if (normalized === 'PIX') return 'PIX';
  if (normalized === 'BOLETO') return 'BOLETO';
  return 'BOLETO';
}

function toIsoDateString(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function buildAsaasCustomerPayload(params: {
  owner: Record<string, unknown>;
  companyData: Record<string, unknown>;
}): Record<string, unknown> {
  const companyData = params.companyData;
  const owner = params.owner;
  const name =
    asTrimmedString(companyData.nomeFantasia) ||
    asTrimmedString(companyData.razaoSocial) ||
    asTrimmedString(owner.nome) ||
    'Empresa sem nome';
  const cpfCnpj = onlyDigits(companyData.cnpj || companyData.cpf);
  const email = asTrimmedString(owner.email || companyData.email).toLowerCase();
  const mobilePhone = onlyDigits(companyData.telefone || owner.telefone);
  const postalCode = onlyDigits(companyData.cep);
  const payload: Record<string, unknown> = { name };

  if (cpfCnpj) payload.cpfCnpj = cpfCnpj;
  if (email) payload.email = email;
  if (mobilePhone) payload.mobilePhone = mobilePhone;
  if (asTrimmedString(companyData.endereco)) payload.address = asTrimmedString(companyData.endereco);
  if (asTrimmedString(companyData.numero)) payload.addressNumber = asTrimmedString(companyData.numero);
  if (asTrimmedString(companyData.complemento)) payload.complement = asTrimmedString(companyData.complemento);
  if (asTrimmedString(companyData.bairro)) payload.province = asTrimmedString(companyData.bairro);
  if (postalCode) payload.postalCode = postalCode;
  return payload;
}

/** CNAE pode vir como string, numero, ou em subobjetos (Brasil API / cache). */
function cnaeDigitsFromBrasilLikeSource(source: unknown): string {
  if (source == null) return '';
  if (typeof source === 'string' || typeof source === 'number') {
    const d = onlyDigits(source);
    return d.length >= 5 ? d : '';
  }
  if (typeof source !== 'object') return '';
  const r = source as Record<string, unknown>;
  const candidates: unknown[] = [
    r.cnae_fiscal,
    r.mainCnae,
    r.cnae_fiscal_principal,
    (r.atividade_principal as Record<string, unknown> | undefined)?.id,
    (r.atividade_principal as Record<string, unknown> | undefined)?.code,
    (r.estabelecimento as Record<string, unknown> | undefined)?.cnae_fiscal,
  ];
  for (const c of candidates) {
    const d = onlyDigits(c);
    if (d.length >= 5) return d;
  }
  return '';
}

/**
 * Brasil API / Receita as vezes retornam ruido em inscricao_municipal; o prefixo
 * de 5 digitos do CNAE (ex.: 43215 de 4321500) nao e IM.
 * [cnaeSource] pode ser string de CNAE, objeto bruto da API, ou payload com mainCnae.
 */
function sanitizeMunicipalRegistrationFromCnpj(
  municipalRaw: unknown,
  cnaeSource: unknown,
): string {
  const trimmed = String(municipalRaw ?? '').trim();
  if (!trimmed) return '';
  const im = onlyDigits(trimmed);
  const cnae =
    typeof cnaeSource === 'object' && cnaeSource !== null && !Array.isArray(cnaeSource)
      ? cnaeDigitsFromBrasilLikeSource(cnaeSource)
      : onlyDigits(cnaeSource);
  if (cnae.length < 5) return trimmed;
  const prefix5 = cnae.substring(0, 5);
  if (im === cnae) return '';
  if (im.length >= 5 && im.substring(0, 5) === prefix5) return '';
  return trimmed;
}

/** Cache antigo pode ter IM = prefixo de CNAE; re-sanitiza ao devolver. */
function applyCnpjPayloadSanitizedFields(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  return {
    ...payload,
    municipalRegistration: sanitizeMunicipalRegistrationFromCnpj(
      payload.municipalRegistration,
      payload,
    ),
  };
}

function mapCnpjPayload(raw: any): Record<string, unknown> {
  const partners = Array.isArray(raw?.qsa)
    ? raw.qsa
        .map((item: any) => String(item?.nome_socio ?? '').trim())
        .filter(Boolean)
    : [];
  const secondaryCnaes = Array.isArray(raw?.cnaes_secundarios)
    ? raw.cnaes_secundarios
        .map((item: any) => {
          if (item == null) return null;
          if (typeof item === 'string') {
            const value = item.trim();
            if (!value) return null;
            return {
              code: onlyDigits(value),
              description: value,
            };
          }
          return {
            code: String(item?.codigo ?? item?.code ?? item?.id ?? '').trim(),
            description: String(
              item?.descricao ?? item?.description ?? item?.text ?? '',
            ).trim(),
          };
        })
        .filter(Boolean)
    : [];

  return {
    found: true,
    source: 'brasilapi',
    document: onlyDigits(raw?.cnpj),
    legalName: String(raw?.razao_social ?? '').trim(),
    tradeName: String(raw?.nome_fantasia ?? '').trim(),
    email: String(raw?.email ?? '').trim().toLowerCase(),
    phone: String(raw?.ddd_telefone_1 ?? raw?.ddd_telefone_2 ?? '').trim(),
    zipCode: onlyDigits(raw?.cep),
    street: String(raw?.logradouro ?? '').trim(),
    number: String(raw?.numero ?? '').trim(),
    complement: String(raw?.complemento ?? '').trim(),
    neighborhood: String(raw?.bairro ?? '').trim(),
    city: String(raw?.municipio ?? '').trim(),
    state: String(raw?.uf ?? '').trim(),
    country: 'BRASIL',
    stateRegistration: String(raw?.inscricao_estadual ?? '').trim(),
    municipalRegistration: sanitizeMunicipalRegistrationFromCnpj(
      raw?.inscricao_municipal,
      raw,
    ),
    mainCnae: String(raw?.cnae_fiscal ?? '').trim(),
    mainCnaeDescription: String(raw?.cnae_fiscal_descricao ?? '').trim(),
    legalNature: String(raw?.natureza_juridica ?? '').trim(),
    companySize: String(raw?.porte ?? '').trim(),
    status: String(raw?.descricao_situacao_cadastral ?? '').trim(),
    openedAt: String(raw?.data_inicio_atividade ?? '').trim(),
    partners,
    secondaryCnaes,
  };
}

function mapCnpjWsPayload(raw: any): Record<string, unknown> {
  const establishment = raw?.estabelecimento ?? {};
  const mainActivity = establishment?.atividade_principal ?? {};
  const stateRegistration = Array.isArray(establishment?.inscricoes_estaduais)
    ? establishment.inscricoes_estaduais
        .map((item: any) => String(item?.inscricao_estadual ?? '').trim())
        .find(Boolean) ?? ''
    : '';
  const partners = Array.isArray(raw?.socios)
    ? raw.socios
        .map((item: any) => String(item?.nome ?? '').trim())
        .filter(Boolean)
    : [];
  const secondaryCnaes = Array.isArray(establishment?.atividades_secundarias)
    ? establishment.atividades_secundarias
        .map((item: any) => ({
          code: String(item?.id ?? item?.subclasse ?? '').trim(),
          description: String(item?.descricao ?? '').trim(),
        }))
        .filter((item: any) => item.code || item.description)
    : [];

  return {
    found: true,
    source: 'cnpjws',
    document: onlyDigits(establishment?.cnpj ?? raw?.cnpj_raiz),
    legalName: String(raw?.razao_social ?? '').trim(),
    tradeName: String(establishment?.nome_fantasia ?? '').trim(),
    email: String(establishment?.email ?? '').trim().toLowerCase(),
    phone: String(
      establishment?.telefone1 ??
        establishment?.telefone_1 ??
        establishment?.ddd1 ??
        '',
    ).trim(),
    zipCode: onlyDigits(establishment?.cep),
    street: String(establishment?.logradouro ?? '').trim(),
    number: String(establishment?.numero ?? '').trim(),
    complement: String(establishment?.complemento ?? '').trim(),
    neighborhood: String(establishment?.bairro ?? '').trim(),
    city: String(establishment?.cidade?.nome ?? '').trim(),
    state: String(establishment?.estado?.sigla ?? '').trim(),
    country: 'BRASIL',
    stateRegistration,
    municipalRegistration: '',
    mainCnae: String(
      mainActivity?.id ??
        mainActivity?.subclasse ??
        establishment?.cnae_fiscal ??
        '',
    ).trim(),
    mainCnaeDescription: String(
      mainActivity?.descricao ?? establishment?.atividade_principal?.descricao ?? '',
    ).trim(),
    legalNature: String(raw?.natureza_juridica?.descricao ?? '').trim(),
    companySize: String(raw?.porte?.descricao ?? '').trim(),
    status: String(establishment?.situacao_cadastral ?? '').trim(),
    openedAt: String(establishment?.data_inicio_atividade ?? '').trim(),
    partners,
    secondaryCnaes,
  };
}

async function fetchCnpjPayload(cnpj: string): Promise<Record<string, unknown>> {
  const brasilApiResponse = await fetch(`https://brasilapi.com.br/api/cnpj/v1/${cnpj}`);
  if (brasilApiResponse.ok) {
    const raw = await brasilApiResponse.json();
    return mapCnpjPayload(raw);
  }

  const cnpjWsResponse = await fetch(`https://publica.cnpj.ws/cnpj/${cnpj}`);
  if (cnpjWsResponse.ok) {
    const raw = await cnpjWsResponse.json();
    return mapCnpjWsPayload(raw);
  }

  throw new functions.https.HttpsError(
    'not-found',
    'Nao foi possivel localizar dados para este CNPJ.',
  );
}

function mapCepPayload(raw: any): Record<string, unknown> {
  return {
    found: true,
    source: 'viacep',
    zipCode: onlyDigits(raw?.cep),
    street: String(raw?.logradouro ?? '').trim(),
    complement: String(raw?.complemento ?? '').trim(),
    neighborhood: String(raw?.bairro ?? '').trim(),
    city: String(raw?.localidade ?? '').trim(),
    state: String(raw?.uf ?? '').trim(),
    ibgeCode: String(raw?.ibge ?? '').trim(),
    giaCode: String(raw?.gia ?? '').trim(),
    ddd: String(raw?.ddd ?? '').trim(),
  };
}

async function readRegistryCache(
  key: string,
): Promise<FirebaseFirestore.DocumentData | null> {
  const snap = await admin.firestore().collection('registry_cache').doc(key).get();
  if (!snap.exists) return null;
  return snap.data() ?? null;
}

async function writeRegistryCache(
  key: string,
  payload: Record<string, unknown>,
): Promise<void> {
  await admin.firestore().collection('registry_cache').doc(key).set(
    {
      ...payload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function escapeHtml(value: string): string {
  // ES2020-safe (no String.prototype.replaceAll).
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/** Nome exibido na apresentacao institucional dos emails (convites e assinaturas). */
const OFFICE_FOUNDER_DISPLAY_NAME = 'Bonfim Alexandre Sousa Santos';

/** Empresa de operacao por tras do Ponto Certo (credibilidade em todos os contatos). */
const OFFICE_FOUNDER_OPERATING_COMPANY_NAME =
  'BONFIM AUTOMAÇÃO E INSTALAÇÕES ELÉTRICAS LTDA';
const OFFICE_FOUNDER_OPERATING_COMPANY_CNPJ = '45.467.633/0001-42';
const OFFICE_FOUNDER_OPERATING_COMPANY_OPENED_AT = '26/02/2022';

function officeFounderOperatingCompanyCredibilityHtml(): string {
  return `
      <p style="margin: 20px 0 12px 0; line-height: 1.5;"><strong>Para dar mais transparência ao contato, seguem os dados da empresa responsável pela operação do Ponto Certo:</strong></p>
      <div style="margin: 0 0 20px 0; padding: 16px 18px; background: #f8fafc; border-left: 4px solid #2563eb; border-radius: 0 8px 8px 0; line-height: 1.5;">
        <p style="margin: 0 0 8px 0;"><strong>Empresa:</strong> ${escapeHtml(OFFICE_FOUNDER_OPERATING_COMPANY_NAME)}</p>
        <p style="margin: 0 0 8px 0;"><strong>CNPJ:</strong> ${escapeHtml(OFFICE_FOUNDER_OPERATING_COMPANY_CNPJ)}</p>
        <p style="margin: 0;"><strong>Abertura:</strong> ${escapeHtml(OFFICE_FOUNDER_OPERATING_COMPANY_OPENED_AT)}</p>
      </div>
  `;
}

function officeFounderEmailSignOffInnerHtml(): string {
  return `Atenciosamente,<br/>${escapeHtml(OFFICE_FOUNDER_DISPLAY_NAME)}<br/><span style="color:#374151;">Fundador e desenvolvedor | Ponto Certo</span>`;
}

/** Assinatura formal para o convite trial (texto pessoal do fundador). */
function officeFounderFormalClosingInviteHtml(): string {
  return `<p style="margin: 24px 0 0 0; line-height: 1.55;">Fico à disposição.</p>
      <p style="margin: 16px 0 0 0; line-height: 1.55; color: #111;">&mdash;<br/>${escapeHtml(
        OFFICE_FOUNDER_DISPLAY_NAME,
      )}<br/><span style="color:#374151;">Fundador | Ponto Certo</span></p>`;
}

function trialInviteTransparencySectionHtml(params: {
  companyName: string;
  companyEmail: string;
  cnpjFormatted: string;
  openedAtLabel: string;
}): string {
  const {companyName, companyEmail, cnpjFormatted, openedAtLabel} = params;
  if (!companyName && !cnpjFormatted && !openedAtLabel && !companyEmail) {
    return '';
  }
  const parts: string[] = [];
  parts.push(
    `<p style="margin: 0 0 12px 0;"><strong>Sobre a empresa referenciada neste convite:</strong></p>`,
  );
  parts.push(
    `<div style="margin: 0 0 20px 0; padding: 16px 18px; background: #f8fafc; border-left: 4px solid #2563eb; border-radius: 0 8px 8px 0; line-height: 1.5;">`,
  );
  if (companyName) {
    parts.push(
      `<p style="margin: 0 0 8px 0;"><strong>Empresa:</strong> ${escapeHtml(companyName)}</p>`,
    );
  }
  if (cnpjFormatted) {
    parts.push(
      `<p style="margin: 0 0 8px 0;"><strong>CNPJ:</strong> ${escapeHtml(cnpjFormatted)}</p>`,
    );
  }
  if (openedAtLabel) {
    parts.push(
      `<p style="margin: 0 0 8px 0;"><strong>Abertura:</strong> ${escapeHtml(openedAtLabel)}</p>`,
    );
  }
  if (companyEmail && !companyName) {
    parts.push(
      `<p style="margin: 0;"><strong>E-mail:</strong> ${escapeHtml(companyEmail)}</p>`,
    );
  }
  parts.push(`</div>`);
  return parts.join('');
}

function createInviteTransport(params: {
  smtpUser: string;
  smtpAppPassword: string;
  smtpHost?: string;
  smtpPort?: number;
  smtpSecure?: boolean;
}): nodemailer.Transporter {
  const emailCfg = obterConfigEmail();
  return nodemailer.createTransport({
    host: (params.smtpHost ?? emailCfg.smtpHost).trim(),
    port: params.smtpPort ?? emailCfg.smtpPort,
    secure: params.smtpSecure ?? emailCfg.smtpSecure,
    auth: {
      user: params.smtpUser,
      pass: params.smtpAppPassword,
    },
  });
}

async function enviarEmailHtml(params: {
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
}): Promise<void> {
  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.toEmail,
      from: params.fromEmail,
      subject: params.subject,
      html: params.html,
    });
    return;
  }

  if (params.smtpUser && params.smtpAppPassword) {
    const emailCfg = obterConfigEmail();
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
      smtpHost: params.smtpHost ?? emailCfg.smtpHost,
      smtpPort: params.smtpPort ?? emailCfg.smtpPort,
      smtpSecure: params.smtpSecure ?? emailCfg.smtpSecure,
    });

    await transporter.sendMail({
      to: params.toEmail,
      from: params.fromEmail,
      subject: params.subject,
      html: params.html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

function officeFounderPresentationHtml(): string {
  return `
      <hr style="border:none; border-top:1px solid #e5e7eb; margin:24px 0;" />
      <p style="margin:0 0 10px 0;"><strong>Quem esta por tras do Ponto Certo</strong></p>
      <p>Sou <strong>${escapeHtml(
        OFFICE_FOUNDER_DISPLAY_NAME,
      )}</strong>, fundador e desenvolvedor do produto, e empresario nos segmentos de obras, construcao civil e servicos eletricos. O Ponto Certo nasceu na pratica: para reduzir retrabalho na emissao de notas, dar previsibilidade ao financeiro e fortalecer a parceria entre empresa e escritorio contabil.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p>${officeFounderEmailSignOffInnerHtml()}</p>
  `;
}

async function enviarEmailBoasVindasFuncionario(params: {
  email: string;
  nome: string;
  nomeEmpresa: string;
  resetLink: string;
  apkUrl: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Seu acesso ao Ponto Certo - ${params.nomeEmpresa || 'Sua empresa'}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Bem-vindo(a), ${escapeHtml(params.nome)}!</h2>
      <p>Seu acesso ao aplicativo <strong>Ponto Certo</strong> da empresa <strong>${escapeHtml(params.nomeEmpresa || 'Sua empresa')}</strong> foi criado.</p>
      <p><a href="${params.resetLink}" style="font-weight:bold;">Definir minha senha de acesso</a></p>
      ${
        params.apkUrl
          ? `<p><a href="${params.apkUrl}">Baixar o app na Play Store</a></p>`
          : `<p>Em breve enviaremos o link oficial da Play Store para instalacao.</p>`
      }
      <p>Depois de criar a senha, abra o app e entre com o mesmo e-mail cadastrado.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });

    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

function buildPlayStoreAccessNoticeHtml(apkUrl: string): string {
  const linkHtml = apkUrl.trim()
    ? `<p style="margin: 0 0 10px 0;"><a href="${apkUrl.trim()}">Acessar o app na Play Store</a></p>`
    : '';
  return `
    ${linkHtml}
    <p style="margin: 0 0 10px 0;">
      Para acessar pela Play Store, aguarde a liberacao do seu acesso.
      O app publicado ainda esta em <strong>versao de teste</strong>.
    </p>
  `;
}

async function enviarEmailMigracaoAmbienteReal(params: {
  email: string;
  nome: string;
  realAccessUrl: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = 'Ponto Certo: ambiente oficial liberado para voce';
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome)}!</h2>
      <p>Seu acesso ao <strong>ambiente oficial</strong> do Ponto Certo esta liberado.</p>
      <p><a href="${params.realAccessUrl}" style="font-weight:bold;">Entrar no ambiente oficial</a></p>
      <p>Se ainda estiver no app de testes, use a opcao interna para migrar ao ambiente oficial.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });

    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailBoasVindasClientePlano(params: {
  email: string;
  nome: string;
  planTitle: string;
  onboardingUrl: string;
  implementationLabel: string;
  priceLabel: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Bem-vindo ao Ponto Certo - ${params.planTitle}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Bem-vindo(a), ${escapeHtml(params.nome || 'cliente')}!</h2>
      <p>Confirmamos a liberacao do teste real de <strong>30 dias</strong> para o plano <strong>${escapeHtml(params.planTitle)}</strong>.</p>
      <p>Investimento recorrente: <strong>${escapeHtml(params.priceLabel)}</strong>.</p>
      <p>${params.implementationLabel}</p>
      <p><strong>Proximo passo:</strong> complete o cadastro da empresa para iniciarmos a ativacao do ambiente real.</p>
      <p><a href="${params.onboardingUrl}" style="font-weight:bold;">Iniciar cadastro da empresa</a></p>
      <p>Inclua dados e documentos para concluir a liberacao com seguranca e ja operar no sistema completo.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });

    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailPreCadastroPlano(params: {
  email: string;
  nome: string;
  planTitle: string;
  checkoutUrl: string;
  implementationMode: string;
  implementationLabel: string;
  partnerInviteUrl?: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Ponto Certo: inicie seu teste real de 30 dias - ${params.planTitle}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome || 'escritorio')}!</h2>
      <p>Registramos seu pre-cadastro no <strong>${escapeHtml(params.planTitle)}</strong>.</p>
      <p>${
        params.implementationMode === 'accountant'
          ? 'O contador indicado sera o <strong>contato principal</strong> e vai iniciar primeiro o cadastro do escritorio para depois cadastrar a empresa que o indicou.'
          : 'Este fluxo segue com contador como contato principal para iniciar o escritorio e depois cadastrar a empresa.'
      }</p>
      <p>O acesso inicial entra com <strong>teste gratis de 30 dias</strong>, sem cobranca de implantacao.</p>
      <p>Apos a confirmacao deste pre-cadastro, o contador indicado recebe o caminho para cadastrar primeiro o escritorio no sistema web e, em seguida, cadastrar a empresa indicada.</p>
      ${
        params.implementationMode === 'accountant'
          ? `<p>${params.implementationLabel}</p><p>Depois do cadastro do escritorio e do cadastro da empresa indicada, o ambiente completo fica liberado em teste por 30 dias.</p>`
          : `<p>${params.implementationLabel}</p>`
      }
      <p>O onboarding comeca no <strong>sistema web</strong>; o app dos colaboradores acompanha a operacao conforme o plano.</p>
      ${
        params.implementationMode === 'accountant'
          ? officeFounderPresentationHtml()
          : `${officeFounderOperatingCompanyCredibilityHtml()}<p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>`
      }
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailConviteContadorParceiro(params: {
  email: string;
  accountantName: string;
  customerName: string;
  customerEmail: string;
  planTitle: string;
  checkoutUrl: string;
  inviteUrl: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Ponto Certo: empresa indicou seu escritorio para iniciar o teste real - ${params.customerName}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.accountantName || 'contador')}!</h2>
      <p><strong>${escapeHtml(params.customerName)}</strong> indicou seu escritorio para iniciar o fluxo do teste real de 30 dias do <strong>${escapeHtml(params.planTitle)}</strong> no Ponto Certo.</p>
      <p>O fluxo foi pensado para colocar empresa e contador no mesmo ambiente, com menos retrabalho fiscal e melhor organizacao desde o inicio.</p>
      <p><a href="${params.inviteUrl}" style="font-weight:bold;">Aceitar convite e conhecer o programa de parceria</a></p>
      <p><strong>Contato na empresa:</strong> ${escapeHtml(params.customerName)} (${escapeHtml(params.customerEmail)})</p>
      <p><strong>Regra desta entrada:</strong> teste gratis de 30 dias, sem cobranca de implantacao.</p>
      <p><strong>Checklist rapido:</strong></p>
      <ol style="margin:0 0 12px 0; padding-left: 20px;">
        <li>Confirme o aceite e alinhe com a empresa o responsavel operacional.</li>
        <li>Primeiro cadastre ou ative o escritorio de contabilidade.</li>
        <li>Depois recolha os dados e documentos para o cadastro correto da empresa indicada.</li>
        <li>No onboarding web, complete razao social, nome fantasia, documentos, endereco, responsavel, telefone e e-mail de acesso da empresa.</li>
        <li>Anexe os documentos solicitados para liberacao completa.</li>
        <li>Ja e contador no sistema? Use <strong>Cadastrar empresa</strong> e vincule o escritorio.</li>
      </ol>
      <p>Cadastro e onboarding sao feitos no <strong>sistema web</strong>; o app dos colaboradores segue a operacao da empresa.</p>
      ${officeFounderPresentationHtml()}
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailClienteContadorNotificado(params: {
  email: string;
  nome: string;
  accountantName: string;
  accountantEmail: string;
  planTitle: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Pagamento confirmado - ${params.planTitle} | Ponto Certo`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome || 'cliente')}!</h2>
      <p>Seu pagamento do <strong>${escapeHtml(params.planTitle)}</strong> foi <strong>confirmado</strong>.</p>
      <p>Enviamos ao contador indicado as instrucoes e o fluxo de cadastro:</p>
      <p><strong>${escapeHtml(params.accountantName)}</strong> (${escapeHtml(params.accountantEmail)})</p>
      <p>Ele recebera o link do onboarding web para concluir o cadastro com consistencia fiscal. Se ja for usuario contador, podera usar tambem o modulo <strong>Cadastrar empresa</strong>.</p>
      <p>A implantacao ocorre no sistema web; em seguida, liberamos os acessos conforme o plano.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailAcessoInicialEmpresa(params: {
  email: string;
  nome: string;
  companyName: string;
  resetLink: string;
  loginUrl: string;
  apkUrl: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Ponto Certo: ative o acesso - ${params.companyName}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome || 'responsavel')}!</h2>
      <p>A empresa <strong>${escapeHtml(params.companyName)}</strong> esta pronta no Ponto Certo.</p>
      <p><a href="${params.resetLink}" style="font-weight:bold;">Criar senha de acesso</a></p>
      <p><a href="${params.loginUrl}" style="font-weight:bold;">Entrar no painel web da empresa</a></p>
      ${buildPlayStoreAccessNoticeHtml(params.apkUrl)}
      <p>No primeiro acesso, revise os dados cadastrais e siga com a operacao.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function ensureCompanyOwnerAccess(params: {
  companyId: string;
  companyName: string;
  companyDisplayCode: string;
  ownerName: string;
  ownerEmail: string;
  companyData: Record<string, unknown>;
  mustChangePassword?: boolean;
}): Promise<{ownerUid: string; createdNow: boolean; loginUrl: string}> {
  const ownerEmail = params.ownerEmail.trim().toLowerCase();
  if (!ownerEmail) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email de acesso da empresa obrigatorio.',
    );
  }

  let userRecord: admin.auth.UserRecord | null = null;
  let createdNow = false;
  try {
    userRecord = await admin.auth().getUserByEmail(ownerEmail);
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (userRecord) {
    const existingUserSnap = await admin.firestore().collection('users').doc(userRecord.uid).get();
    if (existingUserSnap.exists) {
      const existingUser = asRecord(existingUserSnap.data());
      const existingRole = roleParaFirestore(existingUser.role);
      const existingCompanyId = asTrimmedString(existingUser.companyId);
      const reusableLightweight =
        existingRole === 'OWNER' &&
        existingUser.lightweightProfilePending === true;
      if (
        existingRole !== 'OWNER' ||
        (existingCompanyId && existingCompanyId !== params.companyId && !reusableLightweight)
      ) {
        throw new functions.https.HttpsError(
          'already-exists',
          'O email informado ja esta em uso por outro acesso no sistema.',
        );
      }
      if (reusableLightweight && existingCompanyId && existingCompanyId !== params.companyId) {
        await markSupersededLightweightCompany({
          previousCompanyId: existingCompanyId,
          nextCompanyId: params.companyId,
        });
      }
    } else {
      throw new functions.https.HttpsError(
        'already-exists',
        'O email informado ja esta em uso por outro acesso no sistema.',
      );
    }
  }

  const tempPassword = gerarSenhaTemporaria();
  if (!userRecord) {
    userRecord = await admin.auth().createUser({
      email: ownerEmail,
      password: tempPassword,
      displayName: params.ownerName,
      emailVerified: false,
    });
    createdNow = true;
  } else {
    await admin.auth().updateUser(userRecord.uid, {
      password: tempPassword,
      displayName: params.ownerName,
    });
  }

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      companyId: params.companyId,
      companyDisplayCode: params.companyDisplayCode,
      companyName: params.companyName,
      role: 'OWNER',
      nome: params.ownerName,
      email: ownerEmail,
      employeeId: userRecord.uid,
      mustChangePassword: params.mustChangePassword !== false,
      companyData: params.companyData,
      lightweightProfilePending: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: params.companyId,
    role: 'OWNER',
    employeeId: userRecord.uid,
  });

  const resetLink = await admin.auth().generatePasswordResetLink(ownerEmail);
  const loginUrl =
    `https://gestao-ponto-certo.com/login-empresa?email=${encodeURIComponent(ownerEmail)}`;
  const emailCfg = obterConfigEmail();
  await enviarEmailAcessoInicialEmpresa({
    email: ownerEmail,
    nome: params.ownerName,
    companyName: params.companyName,
    resetLink,
    loginUrl,
    apkUrl: emailCfg.apkUrl,
    fromEmail: emailCfg.fromEmail,
    sendgridKey: emailCfg.sendgridKey,
    smtpUser: emailCfg.smtpUser,
    smtpAppPassword: emailCfg.smtpAppPassword,
  });

  return {
    ownerUid: userRecord.uid,
    createdNow,
    loginUrl,
  };
}

async function enviarEmailAcessoInicialContador(params: {
  email: string;
  nome: string;
  companyName: string;
  companyDisplayCode: string;
  resetLink: string;
  loginUrl: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
  apkUrl: string;
}): Promise<void> {
  const assunto = `Ponto Certo: seu acesso de contador - ${params.companyName}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome || 'contador')}!</h2>
      <p>Voce foi vinculado como <strong>contador</strong> da empresa <strong>${escapeHtml(params.companyName)}</strong>.</p>
      <p><strong>Codigo da empresa:</strong> ${escapeHtml(params.companyDisplayCode || 'nao informado')}</p>
      <p><a href="${params.resetLink}" style="font-weight:bold;">Definir senha de acesso</a></p>
      <p>Acesso web do contador:</p>
      <p><a href="${params.loginUrl}">${params.loginUrl}</a></p>
      ${buildPlayStoreAccessNoticeHtml(params.apkUrl)}
      <p>Use este ambiente para fiscal, financeiro e conferencias da empresa.</p>
      ${officeFounderPresentationHtml()}
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function enviarEmailAcessoEscritorioContabil(params: {
  email: string;
  officeName: string;
  responsibleName: string;
  loginUrl: string;
  loginEmail: string;
  resetLink: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
  apkUrl: string;
}): Promise<void> {
  const assunto = `Ponto Certo: escritorio cadastrado - ${params.officeName}`;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.responsibleName || 'responsavel')}!</h2>
      <p>O escritorio <strong>${escapeHtml(params.officeName)}</strong> foi cadastrado com sucesso.</p>
      <p><strong>E-mail de login:</strong> ${escapeHtml(params.loginEmail)}</p>
      <p><a href="${params.resetLink}" style="font-weight:bold;">Criar senha de acesso</a></p>
      <p><a href="${params.loginUrl}" style="font-weight:bold;">Entrar no painel do escritorio</a><br/><span style="font-size:13px;color:#4b5563;">${params.loginUrl}</span></p>
      ${buildPlayStoreAccessNoticeHtml(params.apkUrl)}
      <p>Gerencie empresas da carteira, cadastros e operacao contabil a partir deste ambiente.</p>
      ${officeFounderPresentationHtml()}
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

const PLATFORM_SIGNUP_NOTIFICATION_EMAIL = 'acesso@tudo-certo.com';

async function enviarNotificacaoInternaNovoCadastro(params: {
  subject: string;
  html: string;
}): Promise<void> {
  try {
    const emailCfg = obterConfigEmail();
    const fromRaw = asTrimmedString(emailCfg.fromEmail).toLowerCase();
    const toInternal =
      fromRaw.includes('@') && !fromRaw.startsWith('@') ? fromRaw : PLATFORM_SIGNUP_NOTIFICATION_EMAIL;
    const fromEmail =
      fromRaw.includes('@') && !fromRaw.startsWith('@')
        ? fromRaw
        : asTrimmedString(emailCfg.fromEmail) || PLATFORM_SIGNUP_NOTIFICATION_EMAIL;
    await enviarEmailHtml({
      toEmail: toInternal,
      subject: params.subject,
      html: params.html,
      fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  } catch (error) {
    functions.logger.error('Falha ao enviar notificacao interna de cadastro', error);
  }
}

async function notificarNovoCadastroAdministrativo(params: {
  signupType:
    | 'office'
    | 'company_preregistration'
    | 'company_direct'
    | 'company_from_office'
    | 'company_trial_from_office'
    | 'accountant_linked';
  companyId?: string;
  officeId?: string;
  officeName?: string;
  companyName?: string;
  companyDocument?: string;
  responsibleName?: string;
  responsibleEmail?: string;
  accountantName?: string;
  accountantEmail?: string;
}): Promise<void> {
  const typeLabel = {
    office: 'Novo escritorio cadastrado',
    company_preregistration: 'Novo pre-cadastro comercial',
    company_direct: 'Nova empresa cadastrada direto',
    company_from_office: 'Nova empresa cadastrada por escritorio',
    company_trial_from_office: 'Nova empresa trial cadastrada por escritorio',
    accountant_linked: 'Novo contador vinculado',
  }[params.signupType];
  const subject =
    params.companyName || params.officeName
      ? `${typeLabel} - ${params.companyName || params.officeName}`
      : typeLabel;
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">${escapeHtml(typeLabel)}</h2>
      <p style="margin:0 0 10px 0;"><strong>Tipo:</strong> ${escapeHtml(params.signupType)}</p>
      <p style="margin:0 0 10px 0;"><strong>Escritorio:</strong> ${escapeHtml(params.officeName || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Office ID:</strong> ${escapeHtml(params.officeId || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Empresa:</strong> ${escapeHtml(params.companyName || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Company ID:</strong> ${escapeHtml(params.companyId || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Documento:</strong> ${escapeHtml(params.companyDocument || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Responsavel:</strong> ${escapeHtml(params.responsibleName || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Email responsavel:</strong> ${escapeHtml(params.responsibleEmail || '-')}</p>
      <p style="margin:0 0 10px 0;"><strong>Contador:</strong> ${escapeHtml(params.accountantName || '-')}</p>
      <p style="margin:0 0 0 0;"><strong>Email contador:</strong> ${escapeHtml(params.accountantEmail || '-')}</p>
    </div>
  `;
  await enviarNotificacaoInternaNovoCadastro({subject, html});
}

async function markSupersededLightweightCompany(params: {
  previousCompanyId: string;
  nextCompanyId: string;
}): Promise<void> {
  const previousCompanyId = asTrimmedString(params.previousCompanyId);
  const nextCompanyId = asTrimmedString(params.nextCompanyId);
  if (!previousCompanyId || !nextCompanyId || previousCompanyId === nextCompanyId) {
    return;
  }
  await admin.firestore().collection('company_settings').doc(previousCompanyId).set(
    {
      lightweightSuperseded: true,
      supersededByCompanyId: nextCompanyId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function provisionLightweightOfficeAccess(params: {
  officeName: string;
  responsibleName: string;
  email: string;
  password?: string;
  source: string;
}): Promise<{
  officeId: string;
  officeName: string;
  email: string;
  loginUrl: string;
  emailDispatched: boolean;
}> {
  const officeName = asTrimmedString(params.officeName) || 'Escritorio em configuracao';
  const responsibleName = asTrimmedString(params.responsibleName);
  const email = asTrimmedString(params.email).toLowerCase();
  if (!responsibleName || !email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email para criar o acesso do escritorio.',
    );
  }

  let userRecord: admin.auth.UserRecord | null = null;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  let officeId = '';
  if (userRecord) {
    const existingUserSnap = await admin.firestore().collection('users').doc(userRecord.uid).get();
    if (!existingUserSnap.exists) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email ja esta em uso por outro acesso no sistema.',
      );
    }
    const existingUser = asRecord(existingUserSnap.data());
    if (roleParaFirestore(existingUser.role) !== 'ACCOUNTANT') {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email ja esta em uso por outro acesso no sistema.',
      );
    }
    officeId =
      asTrimmedString(existingUser.officeId) ||
      asTrimmedString(existingUser.companyId) ||
      `office_${Date.now()}`;
    await admin.auth().updateUser(userRecord.uid, {
      password: params.password || gerarSenhaTemporaria(),
      displayName: responsibleName,
    });
  } else {
    userRecord = await admin.auth().createUser({
      email,
      password: params.password || gerarSenhaTemporaria(),
      displayName: responsibleName,
      emailVerified: false,
    });
    officeId = `office_${Date.now()}`;
  }

  await accountingOfficeRef().doc(officeId).set(
    omitUndefinedForFirestore({
      officeId,
      officeName,
      cnpj: '',
      responsibleName,
      phone: '',
      email,
      address: '',
      city: '',
      state: '',
      billingChoiceDefault: 'office',
      notes: '',
      source: params.source,
      active: true,
      platformStatus: 'pending_profile',
      officeMonthlyPriceCents: 9790,
      officeMonthlyPriceLabel: 'R$ 97,90/mes',
      officeBillingStatus: 'trialing',
      officePricingModel: 'trial_access',
      officePartnershipWaiverAllowed: true,
      officePartnershipWaiverActive: false,
      officePartnershipStatus: 'standard',
      linkedCompaniesCount: 0,
      lightweightProfilePending: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }) as Record<string, unknown>,
    {merge: true},
  );

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    omitUndefinedForFirestore({
      companyId: officeId,
      currentCompanyId: officeId,
      companyName: officeName,
      role: 'ACCOUNTANT',
      nome: responsibleName,
      email,
      employeeId: userRecord.uid,
      officeId,
      officeName,
      officeBillingChoiceDefault: 'office',
      mustChangePassword: false,
      lightweightProfilePending: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }) as Record<string, unknown>,
    {merge: true},
  );

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: officeId,
    role: 'ACCOUNTANT',
    employeeId: userRecord.uid,
    officeId,
  });

  const loginUrl =
    `https://gestao-ponto-certo.com/login-contador?email=${encodeURIComponent(email)}`;
  let emailDispatched = false;
  try {
    const emailCfg = obterConfigEmail();
    const resetLink = await admin.auth().generatePasswordResetLink(email);
    await enviarEmailAcessoEscritorioContabil({
      email,
      officeName,
      responsibleName,
      loginUrl,
      loginEmail: email,
      resetLink,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
      apkUrl: emailCfg.apkUrl,
    });
    emailDispatched = true;
  } catch (err) {
    emailDispatched = false;
    try {
      const cfg = obterConfigEmail();
      functions.logger.warn('Email acesso leve escritorio nao enviado', {
        email,
        missing: missingInviteConfig(cfg),
        error: errorMessage(err, 'unknown'),
      });
    } catch (_) {
      functions.logger.warn('Email acesso leve escritorio nao enviado', {
        email,
        error: errorMessage(err, 'unknown'),
      });
    }
  }

  return {
    officeId,
    officeName,
    email,
    loginUrl,
    emailDispatched,
  };
}

async function provisionLightweightCompanyAccess(params: {
  ownerEmail: string;
  ownerName: string;
  companyName: string;
  password?: string;
  source: string;
}): Promise<{
  companyId: string;
  companyName: string;
  emailDispatched: boolean;
}> {
  const ownerEmail = asTrimmedString(params.ownerEmail).toLowerCase();
  const ownerName = asTrimmedString(params.ownerName);
  const companyName =
    asTrimmedString(params.companyName) || 'Empresa em configuracao';
  if (!ownerEmail || !ownerName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email para criar o acesso da empresa.',
    );
  }

  let ownerRecord: admin.auth.UserRecord | null = null;
  try {
    ownerRecord = await admin.auth().getUserByEmail(ownerEmail);
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  let companyId = '';
  let companyDisplayCode = '';
  if (ownerRecord) {
    const existingUserSnap = await admin.firestore().collection('users').doc(ownerRecord.uid).get();
    if (!existingUserSnap.exists) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de acesso ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    const existingUser = asRecord(existingUserSnap.data());
    const isReusable =
      roleParaFirestore(existingUser.role) === 'OWNER' &&
      existingUser.lightweightProfilePending === true;
    if (!isReusable) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de acesso ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    companyId = asTrimmedString(existingUser.companyId) || `comp_${Date.now()}`;
    companyDisplayCode =
      asTrimmedString(asRecord(existingUser.companyData).companyDisplayCode) ||
      buildCompanyDisplayCode({
        cnpj: '',
        companyName,
      });
    await admin.auth().updateUser(ownerRecord.uid, {
      password: params.password || gerarSenhaTemporaria(),
      displayName: ownerName,
    });
  } else {
    ownerRecord = await admin.auth().createUser({
      email: ownerEmail,
      password: params.password || gerarSenhaTemporaria(),
      displayName: ownerName,
      emailVerified: false,
    });
    companyId = `comp_${Date.now()}`;
    companyDisplayCode = buildCompanyDisplayCode({
      cnpj: '',
      companyName,
    });
  }

  const companyData = {
    razaoSocial: companyName,
    nomeFantasia: companyName,
    cnpj: '',
    businessCategory: 'service',
    inscricaoEstadual: '',
    inscricaoEstadualDispensada: true,
    inscricaoMunicipalObrigatoria: true,
    inscricaoMunicipal: '',
    telefone: '',
    email: ownerEmail,
    endereco: '',
    companyType: 'EMPRESA',
    companyPlan: 'EQUIPE',
    companyDisplayCode: companyDisplayCode,
  };

  const commercialSettings = buildLightweightTrialCommercialSettings({
    companyId,
    plan: 'equipe',
    businessTier: 'empresa',
    monthlyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
    seatsIncluded: 3,
    platformNote:
      'Acesso inicial leve criado antes do cadastro real. Empresa precisa concluir o cadastro real para operar com dados fiscais.',
  });

  await admin.firestore().collection('users').doc(ownerRecord.uid).set(
    {
      companyId,
      companyName,
      role: 'OWNER',
      nome: ownerName,
      email: ownerEmail,
      employeeId: ownerRecord.uid,
      mustChangePassword: false,
      companyData,
      lightweightProfilePending: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().setCustomUserClaims(ownerRecord.uid, {
    companyId,
    role: 'OWNER',
    employeeId: ownerRecord.uid,
  });

  await admin.firestore().collection('company_settings').doc(companyId).set(
    {
      companyId,
      companyData,
      companyExperience: {
        type: 'EMPRESA',
        plan: 'Equipe',
        validationLabel: 'Cadastro inicial simplificado',
        validationReason:
          'A empresa recebeu um acesso inicial leve antes do cadastro real completo.',
      },
      commercialSettings,
      directSignup: {
        source: params.source,
        lightweightProfilePending: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  let emailDispatched = false;
  try {
    const emailCfg = obterConfigEmail();
    const resetLink = await admin.auth().generatePasswordResetLink(ownerEmail);
    const loginUrl =
      `https://gestao-ponto-certo.com/login-empresa?email=${encodeURIComponent(ownerEmail)}`;
    await enviarEmailAcessoInicialEmpresa({
      email: ownerEmail,
      nome: ownerName,
      companyName,
      resetLink,
      loginUrl,
      apkUrl: emailCfg.apkUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
    emailDispatched = true;
  } catch (err) {
    emailDispatched = false;
    try {
      const cfg = obterConfigEmail();
      functions.logger.warn('Email acesso leve empresa nao enviado', {
        ownerEmail,
        missing: missingInviteConfig(cfg),
        error: errorMessage(err, 'unknown'),
      });
    } catch (_) {
      functions.logger.warn('Email acesso leve empresa nao enviado', {
        ownerEmail,
        error: errorMessage(err, 'unknown'),
      });
    }
  }

  return {
    companyId,
    companyName,
    emailDispatched,
  };
}

async function createOrUpdateAccountingOffice(params: {
  officeName: string;
  cnpj: string;
  responsibleName: string;
  phone: string;
  email: string;
  password: string;
  address: string;
  city: string;
  state: string;
  billingChoice: string;
  notes: string;
  invitedByName?: string;
  invitedByEmail?: string;
  source: 'public_signup' | 'email_invite';
  inviteId?: string;
}): Promise<{
  officeId: string;
  accountantUid: string;
  loginUrl: string;
  emailDispatched: boolean;
  createdNow: boolean;
}> {
  const officeName = params.officeName.trim();
  const cnpj = onlyDigits(params.cnpj);
  const responsibleName = params.responsibleName.trim();
  const phone = params.phone.trim();
  const email = params.email.trim().toLowerCase();
  const rawPassword = String(params.password ?? '').trim();
  const password = rawPassword.length >= 8 ? rawPassword : gerarSenhaTemporaria();
  const address = params.address.trim();
  const city = params.city.trim();
  const state = params.state.trim().toUpperCase();
  const billingChoice =
    params.billingChoice.trim().toLowerCase() === 'company' ? 'company' : 'office';
  const notes = params.notes.trim();

  if (!officeName || cnpj.length !== 14 || !responsibleName || !phone || !email || !address || !city || !state) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preencha os dados obrigatorios do escritorio.',
    );
  }

  const existingOfficeSnap = await accountingOfficeRef()
    .where('cnpj', '==', cnpj)
    .limit(1)
    .get();
  if (!existingOfficeSnap.empty) {
    const officeDoc = existingOfficeSnap.docs[0];
    const existingEmail = asTrimmedString(officeDoc.data().email).toLowerCase();
    if (existingEmail && existingEmail !== email) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Ja existe escritorio cadastrado com este CNPJ usando outro email.',
      );
    }
  }

  let userRecord: admin.auth.UserRecord | null = null;
  let createdNow = false;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (!userRecord) {
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: responsibleName,
      emailVerified: false,
    });
    createdNow = true;
  } else {
    const existingUserSnap = await admin.firestore().collection('users').doc(userRecord.uid).get();
    if (existingUserSnap.exists) {
      const existingUser = asRecord(existingUserSnap.data());
      const existingRole = roleParaFirestore(existingUser.role);
      if (existingRole !== 'ACCOUNTANT') {
        throw new functions.https.HttpsError(
          'already-exists',
          'O email informado ja esta em uso por um acesso que nao e de escritorio contabil.',
        );
      }
    }
    await admin.auth().updateUser(userRecord.uid, {
      password,
      displayName: responsibleName,
    });
  }

  const officeId =
    !existingOfficeSnap.empty ? existingOfficeSnap.docs[0].id : `office_${Date.now()}`;
  const officeDisplayCode = buildCompanyDisplayCode({
    cnpj,
    companyName: officeName,
  });

  await accountingOfficeRef().doc(officeId).set(
    {
      officeId,
      officeDisplayCode,
      officeName,
      cnpj,
      responsibleName,
      phone,
      email,
      address,
      city,
      state,
      billingChoiceDefault: billingChoice,
      notes,
      source: params.source,
      inviteId: params.inviteId ?? '',
      invitedByName: params.invitedByName ?? '',
      invitedByEmail: params.invitedByEmail ?? '',
      active: true,
      platformStatus: 'active',
      officeMonthlyPriceCents: 9790,
      officeMonthlyPriceLabel: 'R$ 97,90/mes',
      officeBillingStatus: 'pending_setup',
      officePricingModel: 'office_subscription',
      officePartnershipWaiverAllowed: true,
      officePartnershipWaiverActive: false,
      officePartnershipStatus: 'standard',
      linkedCompaniesCount: existingOfficeSnap.empty
          ? 0
          : Number(existingOfficeSnap.docs[0].data().linkedCompaniesCount ?? 0) || 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: existingOfficeSnap.empty
          ? admin.firestore.FieldValue.serverTimestamp()
          : existingOfficeSnap.docs[0].data().createdAt ??
              admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      companyId: officeId,
      companyName: officeName,
      role: 'ACCOUNTANT',
      nome: responsibleName,
      email,
      employeeId: userRecord.uid,
      officeId,
      officeName,
      officeDisplayCode,
      officeBillingChoiceDefault: billingChoice,
      mustChangePassword: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: officeId,
    role: 'ACCOUNTANT',
    employeeId: userRecord.uid,
    officeId,
  });

  const loginUrl =
    `https://gestao-ponto-certo.com/login-contador?email=${encodeURIComponent(email)}`;
  let emailDispatched = false;
  try {
    const emailCfg = obterConfigEmail();
    const resetLink = await admin.auth().generatePasswordResetLink(email);
    await enviarEmailAcessoEscritorioContabil({
      email,
      officeName,
      responsibleName,
      loginUrl,
      loginEmail: email,
      resetLink,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
      apkUrl: emailCfg.apkUrl,
    });
    emailDispatched = true;
  } catch (_) {
    emailDispatched = false;
  }

  return {
    officeId,
    accountantUid: userRecord.uid,
    loginUrl,
    emailDispatched,
    createdNow,
  };
}

async function enviarEmailPendenciasFiscaisEmpresa(params: {
  email: string;
  nome: string;
  companyName: string;
  pendingItems: Record<string, unknown>[];
  customMessage: string;
  fromEmail: string;
  sendgridKey: string;
  smtpUser: string;
  smtpAppPassword: string;
}): Promise<void> {
  const assunto = `Ponto Certo: pendencias fiscais - ${params.companyName}`;
  const listItems = params.pendingItems
    .map((item) => {
      const title = asTrimmedString(item.title);
      const description = asTrimmedString(item.description);
      return `<li><strong>${escapeHtml(title)}</strong>: ${escapeHtml(description)}</li>`;
    })
    .join('');
  const html = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin:0 0 12px 0;">Ola, ${escapeHtml(params.nome || 'responsavel')}!</h2>
      <p>Para concluir a configuracao fiscal de <strong>${escapeHtml(params.companyName)}</strong>, precisamos que voce envie ou atualize os itens abaixo.</p>
      <ul style="margin:0 0 12px 0; padding-left: 20px;">${listItems}</ul>
      ${
        params.customMessage.trim().length > 0
          ? `<p><strong>Orientacao da equipe:</strong> ${escapeHtml(params.customMessage.trim())}</p>`
          : ''
      }
      <p>Com os dados regularizados, finalizamos a etapa fiscal e liberamos a operacao com mais seguranca.</p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin-top: 16px;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;

  if (params.smtpUser && params.smtpAppPassword) {
    const transporter = createInviteTransport({
      smtpUser: params.smtpUser,
      smtpAppPassword: params.smtpAppPassword,
    });
    await transporter.sendMail({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  if (params.sendgridKey) {
    sendgridMail.setApiKey(params.sendgridKey);
    await sendgridMail.send({
      to: params.email,
      from: params.fromEmail,
      subject: assunto,
      html,
    });
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'Configuracao de envio ausente. Defina smtp.user/smtp.app_password ou sendgrid.key.',
  );
}

async function createImplementationChargeForOnboarding(params: {
  requestRef: FirebaseFirestore.DocumentReference;
  item: Record<string, unknown>;
  implementationFeeCents?: number;
}): Promise<{
  paymentId: string;
  invoiceUrl: string;
  dueDate: string;
  status: string;
  valueCents: number;
} | null> {
  const item = params.item;
  const customerId = asTrimmedString(item.customerId);
  const implementationFeeCents =
    params.implementationFeeCents == null
      ? Number(item.implementationFeeCents ?? 0) || 0
      : params.implementationFeeCents;
  if (!customerId || implementationFeeCents <= 0) return null;

  const existingCharge = asRecord(item.implementationCharge);
  if (asTrimmedString(existingCharge.paymentId)) {
    return {
      paymentId: asTrimmedString(existingCharge.paymentId),
      invoiceUrl:
        asTrimmedString(existingCharge.invoiceUrl) ||
        asTrimmedString(existingCharge.bankSlipUrl),
      dueDate: timestampToIsoString(existingCharge.dueDate) ||
        asTrimmedString(existingCharge.dueDate),
      status: asTrimmedString(existingCharge.status),
      valueCents: implementationFeeCents,
    };
  }

  const dueDate = admin.firestore.Timestamp.fromMillis(
    Date.now() + 30 * 24 * 60 * 60 * 1000,
  );
  const charge = await asaasRequest(assertAsaasConfigured(), '/payments', {
    method: 'POST',
    body: {
      customer: customerId,
      billingType: 'BOLETO',
      value: toAsaasMoneyValue(implementationFeeCents),
      dueDate: toIsoDateString(dueDate.toDate()),
      description: `Implantacao ${asTrimmedString(item.planTitle) || 'PontoCerto'}`,
      externalReference: `implantation_${params.requestRef.id}`,
    },
  });

  await params.requestRef.set(
    {
      implementationCharge: {
        paymentId: asTrimmedString(charge.id),
        status: asTrimmedString(charge.status).toLowerCase(),
        invoiceUrl: asTrimmedString(charge.invoiceUrl),
        bankSlipUrl: asTrimmedString(charge.bankSlipUrl),
        dueDate: parseTimestampLike(charge.dueDate) ?? dueDate,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    paymentId: asTrimmedString(charge.id),
    invoiceUrl: asTrimmedString(charge.invoiceUrl) || asTrimmedString(charge.bankSlipUrl),
    dueDate: asTrimmedString(charge.dueDate) || toIsoDateString(dueDate.toDate()),
    status: asTrimmedString(charge.status).toLowerCase(),
    valueCents: implementationFeeCents,
  };
}

async function createOrRefreshPlanUpgradeCharge(params: {
  companyId: string;
  companyData: Record<string, unknown>;
  currentCommercial: Record<string, unknown>;
  currentPlanUpgrade: Record<string, unknown>;
}): Promise<{
  paymentId: string;
  paymentLinkUrl: string;
  dueDate: string;
  status: string;
  amountCents: number;
  externalReference: string;
}> {
  const publicConfigSnap = await publicSalesConfigRef().get();
  const publicConfig = buildDefaultPublicSalesConfig(asRecord(publicConfigSnap.data()));
  const planEquipe = asRecord(publicConfig.planEquipe);
  const amountCents = Number(planEquipe.implementationFeeCents ?? 0) || 0;
  if (amountCents <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A taxa de aquisicao para migrar ao plano Equipe nao esta configurada.',
    );
  }

  const existingStatus = asTrimmedString(params.currentPlanUpgrade.status).toLowerCase();
  const existingPaymentId = asTrimmedString(params.currentPlanUpgrade.paymentId);
  const existingPaymentLinkUrl =
    asTrimmedString(params.currentPlanUpgrade.paymentLinkUrl) ||
    asTrimmedString(params.currentPlanUpgrade.invoiceUrl);
  const existingDueDate = timestampToIsoString(params.currentPlanUpgrade.dueDate) ||
    asTrimmedString(params.currentPlanUpgrade.dueDate);
  const externalReference = `plan_upgrade_${params.companyId}_solo_to_equipe`;
  if (
    existingPaymentId &&
    ['pending', 'pending_payment', 'received', 'confirmed', 'paid'].includes(existingStatus)
  ) {
    return {
      paymentId: existingPaymentId,
      paymentLinkUrl: existingPaymentLinkUrl,
      dueDate: existingDueDate,
      status: existingStatus || 'pending_payment',
      amountCents,
      externalReference,
    };
  }

  const cfg = assertAsaasConfigured();
  const currentBilling = asRecord(params.currentCommercial.billingIntegration);
  let customerId = asTrimmedString(currentBilling.customerId);
  if (!customerId) {
    const owner = await carregarOwnerDaEmpresa(params.companyId);
    const customerResult = await asaasRequest(cfg, '/customers', {
      method: 'POST',
      body: buildAsaasCustomerPayload({
        owner,
        companyData: params.companyData,
      }),
    });
    customerId = asTrimmedString(customerResult.id);
  }
  if (!customerId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Nao foi possivel localizar o cliente Asaas da empresa para gerar a cobranca de upgrade.',
    );
  }

  const dueDate = admin.firestore.Timestamp.fromMillis(
    Date.now() + 3 * 24 * 60 * 60 * 1000,
  );
  const charge = await asaasRequest(cfg, '/payments', {
    method: 'POST',
    body: {
      customer: customerId,
      billingType: 'BOLETO',
      value: toAsaasMoneyValue(amountCents),
      dueDate: toIsoDateString(dueDate.toDate()),
      description: 'Aquisicao de upgrade do plano Solo para Equipe',
      externalReference,
    },
  });

  return {
    paymentId: asTrimmedString(charge.id),
    paymentLinkUrl:
      asTrimmedString(charge.invoiceUrl) ||
      asTrimmedString(charge.bankSlipUrl) ||
      asTrimmedString(charge.transactionReceiptUrl),
    dueDate: asTrimmedString(charge.dueDate) || toIsoDateString(dueDate.toDate()),
    status: asTrimmedString(charge.status).toLowerCase() || 'pending_payment',
    amountCents,
    externalReference,
  };
}

async function finalizeSalesOnboardingToOperationalCompany(params: {
  requestRef: FirebaseFirestore.DocumentReference;
  item: Record<string, unknown>;
}): Promise<{companyId: string; ownerUid: string; ownerEmail: string; companyName: string}> {
  const item = params.item;
  const formData = asRecord(item.formData);
  const uploads = Array.isArray(item.uploads)
    ? item.uploads.map((upload) => asRecord(upload))
    : [];
  const certificateUpload =
    uploads.find(
      (upload) =>
        asTrimmedString(upload.category) === 'certificado_digital_a1',
    ) ?? null;
  const ownerEmail =
    asTrimmedString(formData.preferredLoginEmail).toLowerCase() ||
    asTrimmedString(formData.ownerEmail).toLowerCase();
  const ownerName =
    asTrimmedString(formData.ownerName) ||
    asTrimmedString(item.customerName) ||
    'Responsavel';
  const companyName =
    asTrimmedString(formData.tradeName) ||
    asTrimmedString(formData.legalName) ||
    asTrimmedString(item.planTitle) ||
    'Empresa';
  if (!ownerEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Onboarding sem email de login para criar a empresa operacional.',
    );
  }

  const companyId = asTrimmedString(item.companyId) || `comp_${Date.now()}`;
  const companyDisplayCode = buildCompanyDisplayCode({
    cnpj: asTrimmedString(formData.document),
    companyName,
  });
  const mappedCompanyData = {
    razaoSocial: asTrimmedString(formData.legalName),
    nomeFantasia: asTrimmedString(formData.tradeName) || companyName,
    cnpj: onlyDigits(formData.document),
    telefone: asTrimmedString(formData.phone),
    email: asTrimmedString(formData.ownerEmail).toLowerCase(),
    businessCategory: asTrimmedString(formData.businessCategory) || 'service',
    inscricaoEstadual: asTrimmedString(formData.stateRegistration),
    inscricaoMunicipal: asTrimmedString(formData.municipalRegistration),
    cep: onlyDigits(formData.zipCode),
    rua: asTrimmedString(formData.street),
    endereco: asTrimmedString(formData.street),
    numero: asTrimmedString(formData.number),
    complemento: asTrimmedString(formData.complement),
    bairro: asTrimmedString(formData.neighborhood),
    cidade: asTrimmedString(formData.city),
    estado: asTrimmedString(formData.state).toUpperCase(),
    regimeTributario: asTrimmedString(formData.taxRegime),
    legalNature: asTrimmedString(formData.legalNature),
    companySize: asTrimmedString(formData.companySize),
    mainCnae: asTrimmedString(formData.mainCnae),
    mainCnaeDescription: asTrimmedString(formData.mainCnaeDescription),
    codigoMunicipio: asTrimmedString(formData.municipalCode),
    cityCode: asTrimmedString(formData.municipalCode),
    ibgeCode: asTrimmedString(formData.municipalCode),
    codigoServicoPadrao: asTrimmedString(formData.standardServiceCode),
    defaultServiceCode: asTrimmedString(formData.standardServiceCode),
    companyDisplayCode,
  };

  let userRecord: admin.auth.UserRecord;
  try {
    const tempPassword = gerarSenhaTemporaria();
    userRecord = await admin.auth().createUser({
      email: ownerEmail,
      password: tempPassword,
      displayName: ownerName,
      emailVerified: false,
    });
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code === 'auth/email-already-exists') {
      userRecord = await admin.auth().getUserByEmail(ownerEmail);
    } else {
      throw new functions.https.HttpsError(
        'internal',
        'Nao foi possivel criar o acesso inicial da empresa.',
      );
    }
  }

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      companyId,
      companyDisplayCode,
      companyName,
      role: 'OWNER',
      nome: ownerName,
      email: ownerEmail,
      employeeId: userRecord.uid,
      mustChangePassword: true,
      companyData: mappedCompanyData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const baseCommercial = buildDefaultCommercialSettings({
    companyId,
    commercialSettings: {
      plan: asTrimmedString(item.planCode) === 'equipe' ? 'equipe' : 'solo',
      businessTier: asTrimmedString(item.planCode) === 'equipe' ? 'empresa' : 'mei',
      lifecycleStatus: 'active',
      billingStatus: 'active',
      allowLogin: true,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired: false,
      activationStatus: 'released',
      billingIntegration: {
        provider: 'asaas',
        accessManagedByGateway: true,
        customerId: asTrimmedString(item.customerId),
        subscriptionId: asTrimmedString(item.subscriptionId),
        status: 'active',
        externalReference: companyId,
      },
      baseSystemPriceCents: Number(item.planPriceCents ?? 0) || 0,
      monthlyPriceCents: Number(item.planPriceCents ?? 0) || 0,
      seatsIncluded: asTrimmedString(item.planCode) === 'equipe' ? 3 : 1,
      contractedAppUsers: asTrimmedString(item.planCode) === 'equipe' ? 3 : 1,
    },
  });

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  await settingsRef.set(
    {
      companyId,
      companyData: mappedCompanyData,
      companyExperience: {
        type: asTrimmedString(item.planCode) === 'equipe' ? 'empresa' : 'mei',
        plan: asTrimmedString(item.planCode) === 'equipe' ? 'Equipe' : 'Solo',
      },
      commercialSettings: baseCommercial,
      onboardingSource: {
        requestId: params.requestRef.id,
        implementationMode: asTrimmedString(item.implementationMode),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (certificateUpload != null || asTrimmedString(formData.certificatePassword)) {
    await settingsRef.set(
      {
        fiscalCertificate: {
          fileName: asTrimmedString(certificateUpload?.fileName),
          contentType: asTrimmedString(certificateUpload?.contentType),
          storagePath: asTrimmedString(certificateUpload?.storagePath),
          publicUrl: asTrimmedString(certificateUpload?.publicUrl),
          uploadedAt: asTrimmedString(certificateUpload?.uploadedAt),
          source: 'sales_onboarding',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );
    await admin
      .firestore()
      .collection('fiscal_secure')
      .doc(companyId)
      .set(
        {
          companyId,
          fiscalCertificateSecrets: {
            password: asTrimmedString(formData.certificatePassword),
            loginResponsavel: asTrimmedString(formData.responsibleLogin),
            senhaResponsavel: asTrimmedString(formData.responsiblePassword),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'sales_onboarding',
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
  }

  const accountantName =
    asTrimmedString(item.accountantName) ||
    (asTrimmedString(item.implementationMode) === 'accountant'
      ? asTrimmedString(item.customerName)
      : '');
  const accountantEmail =
    asTrimmedString(item.accountantEmail).toLowerCase() ||
    (asTrimmedString(item.implementationMode) === 'accountant'
      ? asTrimmedString(item.customerEmail).toLowerCase()
      : '');
  if (accountantEmail) {
    const leadSnap = await admin
      .firestore()
      .collection('users')
      .where('email', '==', accountantEmail)
      .limit(1)
      .get();
    const accountantProfile = leadSnap.empty ? null : asRecord(leadSnap.docs[0].data());
    if (accountantProfile && roleParaFirestore(accountantProfile.role) === 'ACCOUNTANT') {
      await admin.firestore().collection('accountant_links').doc(`${companyId}_${leadSnap.docs[0].id}`).set(
        {
          companyId,
          companyName,
          companyDocument: asTrimmedString(mappedCompanyData.cnpj),
          companyDisplayCode,
          accountantUserId: leadSnap.docs[0].id,
          accountantName:
            asTrimmedString(accountantProfile.nome) || accountantName,
          accountantEmail:
            asTrimmedString(accountantProfile.email).toLowerCase() || accountantEmail,
          linkedByUserId: userRecord.uid,
          linkedByName: ownerName,
          status: 'active',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    } else {
      await settingsRef.set(
        {
          accountantOnboardingPending: {
            accountantName,
            accountantEmail,
            status: 'pending_accountant_link',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
    }
  }

  const resetLink = await admin.auth().generatePasswordResetLink(ownerEmail);
  const emailCfg = obterConfigEmail();
  const loginUrl =
    `https://gestao-ponto-certo.com/login-empresa?email=${encodeURIComponent(ownerEmail)}`;
  await enviarEmailAcessoInicialEmpresa({
    email: ownerEmail,
    nome: ownerName,
    companyName,
    resetLink,
    loginUrl,
    apkUrl: emailCfg.apkUrl,
    fromEmail: emailCfg.fromEmail,
    sendgridKey: emailCfg.sendgridKey,
    smtpUser: emailCfg.smtpUser,
    smtpAppPassword: emailCfg.smtpAppPassword,
  });

  await params.requestRef.set(
    {
      status: 'operational_company_created',
      companyId,
      ownerUid: userRecord.uid,
      ownerEmail,
      companyName,
      archivedCompanyPath: `company_settings/${companyId}/implementation_records/current`,
      convertedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await settingsRef.collection('implementation_records').doc('current').set(
    {
      requestId: params.requestRef.id,
      source: asTrimmedString(item.source),
      status: 'converted',
      companyId,
      companyName,
      implementationMode: asTrimmedString(item.implementationMode),
      customerName: asTrimmedString(item.customerName),
      customerEmail: asTrimmedString(item.customerEmail),
      originalBuyerName: asTrimmedString(item.originalBuyerName),
      originalBuyerEmail: asTrimmedString(item.originalBuyerEmail),
      accountantName,
      accountantEmail,
      planCode: asTrimmedString(item.planCode),
      planTitle: asTrimmedString(item.planTitle),
      planPriceLabel: asTrimmedString(item.planPriceLabel),
      implementationLabel: asTrimmedString(item.implementationLabel),
      implementationFeeCents: Number(item.implementationFeeCents ?? 0) || 0,
      implementationCharge: asRecord(item.implementationCharge),
      formData,
      uploads: Array.isArray(item.uploads) ? item.uploads : [],
      uploadedCount: Array.isArray(item.uploads) ? item.uploads.length : 0,
      convertedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await refreshCompanyProvisioningState({
    claims: {
      uid: userRecord.uid,
      companyId,
      role: 'OWNER',
      employeeId: userRecord.uid,
    },
    companyData: mappedCompanyData,
  });

  await params.requestRef.set(
    {
      archivedToCompanyId: companyId,
      uploadedCount: Array.isArray(item.uploads) ? item.uploads.length : 0,
      uploads: admin.firestore.FieldValue.delete(),
      formData: {
        legalName: asTrimmedString(formData.legalName),
        tradeName: asTrimmedString(formData.tradeName),
        document: asTrimmedString(formData.document),
        city: asTrimmedString(formData.city),
        state: asTrimmedString(formData.state),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    companyId,
    ownerUid: userRecord.uid,
    ownerEmail,
    companyName,
  };
}

async function createOrRefreshPublicSalesOnboarding(params: {
  cfg: AsaasConfig;
  payment: Record<string, unknown>;
  eventId: string;
  eventName: string;
}): Promise<{ requestId: string; created: boolean } | null> {
  const publicConfigSnap = await publicSalesConfigRef().get();
  const publicConfig = buildDefaultPublicSalesConfig(asRecord(publicConfigSnap.data()));
  const plan = inferPublicPlanFromPayment({
    config: publicConfig,
    payment: params.payment,
  });
  if (plan == null) return null;

  const customerId = asTrimmedString(params.payment.customer);
  const customer = await fetchAsaasCustomer(params.cfg, customerId);
  const customerEmail =
    asTrimmedString(customer.email) || asTrimmedString(params.payment.customerEmail);
  if (!customerEmail) return null;

  const customerName =
    asTrimmedString(customer.name) ||
    asTrimmedString(params.payment.name) ||
    customerEmail.split('@')[0];
  const paymentId = asTrimmedString(params.payment.id);
  const subscriptionId = asTrimmedString(params.payment.subscription);
  const matchedLeadDoc = await findSalesLeadDocByCustomerEmailAndPlan(
    customerEmail.toLowerCase(),
    asTrimmedString(plan.code),
  );
  const leadData = matchedLeadDoc ? asRecord(matchedLeadDoc.data()) : {};
  const implementationMode = asTrimmedString(leadData.implementationMode) || 'platform';
  const recipientEmail =
    implementationMode === 'accountant'
      ? asTrimmedString(leadData.accountantEmail).toLowerCase() || customerEmail.toLowerCase()
      : customerEmail.toLowerCase();
  const recipientName =
    implementationMode === 'accountant'
      ? asTrimmedString(leadData.accountantName) || customerName
      : customerName;
  const onboardingDocMatch = await findSalesOnboardingDocByRecipientEmailAndPlan(
    recipientEmail,
    asTrimmedString(plan.code),
  );

  const token = generatePublicToken();
  const tokenHash = hashPublicToken(token);
  const requestRef = onboardingDocMatch ? onboardingDocMatch.ref : salesOnboardingRef().doc();
  const requestId = requestRef.id;
  const onboardingUrl =
    `https://gestao-ponto-certo.com/boas-vindas-empresa?token=${encodeURIComponent(token)}`;
  const emailCfg = obterConfigEmail();

  await requestRef.set(
    {
      source: 'asaas_public_checkout',
      status: 'awaiting_customer_form',
      customerId,
      customerEmail: recipientEmail,
      customerName: recipientName,
      originalBuyerEmail: customerEmail.toLowerCase(),
      originalBuyerName: customerName,
      paymentId,
      paymentStatus: asTrimmedString(params.payment.status).toLowerCase(),
      subscriptionId,
      planCode: asTrimmedString(plan.code),
      planTitle: asTrimmedString(plan.title),
      planPriceLabel: asTrimmedString(plan.priceLabel),
      planPriceCents: Number(plan.priceCents ?? 0) || 0,
      implementationLabel: asTrimmedString(plan.implantationLabel),
      implementationFeeCents: Number(plan.implementationFeeCents ?? 0) || 0,
      implementationMode,
      onboardingTokenHash: tokenHash,
      onboardingUrl,
      lastWebhookEventId: params.eventId,
      lastWebhookEvent: params.eventName,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: onboardingDocMatch
        ? onboardingDocMatch.data().createdAt ?? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await enviarEmailBoasVindasClientePlano({
    email: recipientEmail,
    nome: recipientName,
    planTitle: asTrimmedString(plan.title),
    onboardingUrl,
    implementationLabel: asTrimmedString(plan.implantationLabel),
    priceLabel: asTrimmedString(plan.priceLabel),
    fromEmail: emailCfg.fromEmail,
    sendgridKey: emailCfg.sendgridKey,
    smtpUser: emailCfg.smtpUser,
    smtpAppPassword: emailCfg.smtpAppPassword,
  });

  if (
    implementationMode === 'accountant' &&
    customerEmail.toLowerCase() !== recipientEmail &&
    asTrimmedString(leadData.accountantEmail)
  ) {
    await enviarEmailClienteContadorNotificado({
      email: customerEmail.toLowerCase(),
      nome: customerName,
      accountantName: asTrimmedString(leadData.accountantName) || recipientName,
      accountantEmail: asTrimmedString(leadData.accountantEmail).toLowerCase(),
      planTitle: asTrimmedString(plan.title),
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  }

  await requestRef.set(
    {
      welcomeEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (matchedLeadDoc) {
    await matchedLeadDoc.ref.set(
      {
        status: 'paid',
        onboardingRequestId: requestId,
        onboardingUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  return { requestId, created: !onboardingDocMatch };
}

async function findExistingPaidDirectSignup(params: {
  ownerEmail: string;
  planCode: 'solo' | 'equipe';
}): Promise<{
  found: boolean;
  source: string;
  customerId: string;
  subscriptionId: string;
  paymentStatus: string;
}> {
  const ownerEmail = params.ownerEmail.trim().toLowerCase();
  if (!ownerEmail) {
    return {
      found: false,
      source: '',
      customerId: '',
      subscriptionId: '',
      paymentStatus: '',
    };
  }

  const onboardingRecipientSnap = await salesOnboardingRef()
    .where('customerEmail', '==', ownerEmail)
    .limit(40)
    .get()
    .catch(() => null);
  const wantPlan = params.planCode.trim().toLowerCase();
  const onboardingDocs = (onboardingRecipientSnap?.docs ?? []).filter(
    (doc) =>
      asTrimmedString(asRecord(doc.data()).planCode).toLowerCase() === wantPlan,
  );
  for (const doc of onboardingDocs) {
    const item = asRecord(doc.data());
    const paymentStatus = asTrimmedString(item.paymentStatus).toLowerCase();
    if (
      ['received', 'confirmed', 'paid', 'active'].includes(paymentStatus) ||
      asTrimmedString(item.customerId) ||
      asTrimmedString(item.subscriptionId)
    ) {
      return {
        found: true,
        source: 'sales_onboarding',
        customerId: asTrimmedString(item.customerId),
        subscriptionId: asTrimmedString(item.subscriptionId),
        paymentStatus,
      };
    }
  }

  const buyerSnap = await salesOnboardingRef()
    .where('originalBuyerEmail', '==', ownerEmail)
    .limit(40)
    .get()
    .catch(() => null);
  for (const doc of (buyerSnap?.docs ?? []).filter(
    (d) =>
      asTrimmedString(asRecord(d.data()).planCode).toLowerCase() === wantPlan,
  )) {
    const item = asRecord(doc.data());
    const paymentStatus = asTrimmedString(item.paymentStatus).toLowerCase();
    if (
      ['received', 'confirmed', 'paid', 'active'].includes(paymentStatus) ||
      asTrimmedString(item.customerId) ||
      asTrimmedString(item.subscriptionId)
    ) {
      return {
        found: true,
        source: 'sales_onboarding',
        customerId: asTrimmedString(item.customerId),
        subscriptionId: asTrimmedString(item.subscriptionId),
        paymentStatus,
      };
    }
  }

  const leadPaid = await findSalesLeadDocByCustomerEmailAndPlan(
    ownerEmail,
    params.planCode,
  );
  if (leadPaid) {
    const item = asRecord(leadPaid.data());
    const status = asTrimmedString(item.status).toLowerCase();
    if (status === 'paid') {
      return {
        found: true,
        source: 'sales_lead',
        customerId: asTrimmedString(item.customerId),
        subscriptionId: asTrimmedString(item.subscriptionId),
        paymentStatus: status,
      };
    }
  }

  return {
    found: false,
    source: '',
    customerId: '',
    subscriptionId: '',
    paymentStatus: '',
  };
}

async function provisionDirectSignupBilling(params: {
  companyId: string;
  owner: Record<string, unknown>;
  companyData: Record<string, unknown>;
  planCode: 'solo' | 'equipe';
  monthlyPriceCents: number;
  description: string;
}): Promise<{
  customerId: string;
  subscriptionId: string;
  paymentLinkUrl: string;
  status: string;
  nextDueDate: string;
}> {
  const cfg = assertAsaasConfigured();
  const customerPayload = buildAsaasCustomerPayload({
    owner: params.owner,
    companyData: params.companyData,
  });
  const customerResult = await asaasRequest(cfg, '/customers', {
    method: 'POST',
    body: customerPayload,
  });
  const customerId = asTrimmedString(customerResult.id);
  if (!customerId) {
    throw new functions.https.HttpsError(
      'internal',
      'Asaas nao retornou customerId no cadastro direto.',
    );
  }

  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const subscriptionResult = await asaasRequest(cfg, '/subscriptions', {
    method: 'POST',
    body: {
      customer: customerId,
      billingType: 'BOLETO',
      cycle: 'MONTHLY',
      value: toAsaasMoneyValue(params.monthlyPriceCents),
      nextDueDate: toIsoDateString(dueDate),
      description: params.description,
      externalReference: params.companyId,
    },
  });
  const subscriptionId = asTrimmedString(subscriptionResult.id);
  let paymentLinkUrl = '';
  if (subscriptionId) {
    try {
      const paymentsResult = await asaasRequest(
        cfg,
        `/subscriptions/${encodeURIComponent(subscriptionId)}/payments`,
      );
      const first = Array.isArray(paymentsResult.data) && paymentsResult.data.length > 0
        ? asRecord(paymentsResult.data[0])
        : {};
      paymentLinkUrl =
        asTrimmedString(first.invoiceUrl) ||
        asTrimmedString(first.bankSlipUrl) ||
        asTrimmedString(first.transactionReceiptUrl);
    } catch (_) {
      paymentLinkUrl = '';
    }
  }

  return {
    customerId,
    subscriptionId,
    paymentLinkUrl,
    status: asTrimmedString(subscriptionResult.status).toLowerCase() || 'pending_payment',
    nextDueDate: asTrimmedString(subscriptionResult.nextDueDate) || toIsoDateString(dueDate),
  };
}

async function resolveTrialConversionPlan(params: {
  settingsData: Record<string, unknown>;
}): Promise<{
  planCode: 'solo' | 'equipe';
  planTitle: string;
  monthlyPriceCents: number;
}> {
  const accountantCommercial = asRecord(params.settingsData.accountantCommercial);
  const accountantPrice = Number(accountantCommercial.companyPriceCents ?? 0) || 0;
  const commercial = buildDefaultCommercialSettings(params.settingsData);
  const currentPlan = asTrimmedString(commercial.plan).toLowerCase();
  const currentPrice = Number(commercial.monthlyPriceCents ?? 0) || 0;
  const companyData = asRecord(params.settingsData.companyData);
  const companyPlan = asTrimmedString(companyData.companyPlan).toUpperCase();
  const publicConfigSnap = await publicSalesConfigRef().get();
  const publicConfig = buildDefaultPublicSalesConfig(asRecord(publicConfigSnap.data()));
  const fallbackPlanCode: 'solo' | 'equipe' =
    currentPlan === 'solo' || companyPlan === 'SOLO' ? 'solo' : 'equipe';
  const fallbackPlan = asRecord(
    fallbackPlanCode === 'solo' ? publicConfig.planSolo : publicConfig.planEquipe,
  );

  if (accountantPrice > 0) {
    return {
      planCode: 'equipe',
      planTitle: 'Plano Equipe',
      monthlyPriceCents: accountantPrice,
    };
  }

  return {
    planCode: fallbackPlanCode,
    planTitle: asTrimmedString(fallbackPlan.title) || 'Plano Equipe',
    monthlyPriceCents:
      currentPrice > 0 ? currentPrice : Number(fallbackPlan.priceCents ?? 0) || 0,
  };
}

async function ensureAccountantAccessForCompany(params: {
  companyId: string;
  companyName: string;
  companyDisplayCode: string;
  companyDocument: string;
  linkedByUserId: string;
  linkedByName: string;
  accountantName: string;
  accountantEmail: string;
}): Promise<{accountantUid: string; createdNow: boolean}> {
  const accountantEmail = params.accountantEmail.trim().toLowerCase();
  if (!accountantEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'Email do contador obrigatorio.');
  }

  let userRecord: admin.auth.UserRecord | null = null;
  let createdNow = false;
  try {
    userRecord = await admin.auth().getUserByEmail(accountantEmail);
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  if (!userRecord) {
    const tempPassword = gerarSenhaTemporaria();
    userRecord = await admin.auth().createUser({
      email: accountantEmail,
      password: tempPassword,
      displayName: params.accountantName,
      emailVerified: false,
    });
    createdNow = true;
  }

  const userRef = admin.firestore().collection('users').doc(userRecord.uid);
  const userSnap = await userRef.get();
  const existing = asRecord(userSnap.data());
  const existingRole = roleParaFirestore(existing.role);
  if (userSnap.exists && existingRole !== 'ACCOUNTANT') {
    throw new functions.https.HttpsError(
      'already-exists',
      'O email informado ja esta em uso por um acesso que nao e de contador.',
    );
  }
  const accountantClaimsCompanyId =
    asTrimmedString(existing.currentCompanyId) ||
    asTrimmedString(existing.companyId) ||
    params.companyId;

  await userRef.set(
    {
      companyId: asTrimmedString(existing.companyId) || params.companyId,
      currentCompanyId:
        accountantClaimsCompanyId,
      companyName: asTrimmedString(existing.companyName) || params.companyName,
      role: 'ACCOUNTANT',
      nome: asTrimmedString(existing.nome) || params.accountantName,
      email: accountantEmail,
      employeeId: userRecord.uid,
      mustChangePassword: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: userSnap.exists
        ? existing.createdAt ?? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().updateUser(userRecord.uid, {
    displayName: params.accountantName,
  });
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: accountantClaimsCompanyId,
    role: 'ACCOUNTANT',
    employeeId: userRecord.uid,
  });

  await admin.firestore().collection('accountant_links').doc(`${params.companyId}_${userRecord.uid}`).set(
    {
      companyId: params.companyId,
      companyName: params.companyName,
      companyDocument: params.companyDocument,
      companyDisplayCode: params.companyDisplayCode,
      accountantUserId: userRecord.uid,
      accountantName: params.accountantName,
      accountantEmail,
      linkedByUserId: params.linkedByUserId,
      linkedByName: params.linkedByName,
      status: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const emailCfg = obterConfigEmail();
  const resetLink = await admin.auth().generatePasswordResetLink(accountantEmail);
  const loginUrl =
    `https://gestao-ponto-certo.com/login-contador?email=${encodeURIComponent(accountantEmail)}&empresa=${encodeURIComponent(params.companyDisplayCode)}`;
  await enviarEmailAcessoInicialContador({
    email: accountantEmail,
    nome: params.accountantName,
    companyName: params.companyName,
    companyDisplayCode: params.companyDisplayCode,
    resetLink,
    loginUrl,
    fromEmail: emailCfg.fromEmail,
    sendgridKey: emailCfg.sendgridKey,
    smtpUser: emailCfg.smtpUser,
    smtpAppPassword: emailCfg.smtpAppPassword,
    apkUrl: emailCfg.apkUrl,
  });

  await notificarNovoCadastroAdministrativo({
    signupType: 'accountant_linked',
    companyId: params.companyId,
    companyName: params.companyName,
    companyDocument: params.companyDocument,
    responsibleName: params.linkedByName,
    accountantName: params.accountantName,
    accountantEmail,
  });

  return {accountantUid: userRecord.uid, createdNow};
}

function rawDateToMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'string') return Date.parse(value);
  return Number.NaN;
}

async function resolveAccountantCompanyContext(
  userUid: string,
  preferredCompanyId: string,
): Promise<string> {
  const linksSnap = await admin
    .firestore()
    .collection('accountant_links')
    .where('accountantUserId', '==', userUid)
    .where('status', '==', 'active')
    .get();

  const rankedCompanyIds = linksSnap.docs
    .map((doc) => {
      const data = asRecord(doc.data());
      return {
        companyId: asTrimmedString(data.companyId),
        updatedAtMillis: rawDateToMillis(data.updatedAt),
      };
    })
    .filter((item) => item.companyId.length > 0)
    .sort((a, b) => {
      const aMillis = Number.isFinite(a.updatedAtMillis) ? a.updatedAtMillis : 0;
      const bMillis = Number.isFinite(b.updatedAtMillis) ? b.updatedAtMillis : 0;
      return bMillis - aMillis;
    })
    .map((item) => item.companyId);

  if (preferredCompanyId && rankedCompanyIds.includes(preferredCompanyId)) {
    return preferredCompanyId;
  }

  return rankedCompanyIds[0] ?? preferredCompanyId;
}

async function persistAccountantCurrentCompany(userUid: string, companyId: string): Promise<void> {
  if (!userUid.trim() || !companyId.trim()) return;
  await admin.firestore().collection('users').doc(userUid).set(
    {
      currentCompanyId: companyId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

exports.authSyncClaims = functions.https.onCall(async (_data, context) => {
  const { uid } = assertAuth(context);
  const user = await carregarUsuario(uid);

  const role = roleParaFirestore(user.role);
  const preferredCompanyId =
    asTrimmedString((user as Record<string, unknown>).currentCompanyId) ||
    String(user.companyId ?? '').trim();
  const companyId = role === 'ACCOUNTANT'
    ? await resolveAccountantCompanyContext(uid, preferredCompanyId)
    : String(user.companyId ?? '').trim();
  const employeeId = String(user.employeeId ?? uid).trim();

  if (!companyId || !employeeId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Perfil sem companyId/employeeId para gerar custom claims.',
    );
  }

  if (role === 'ACCOUNTANT' && companyId !== preferredCompanyId) {
    await persistAccountantCurrentCompany(uid, companyId);
  }

  await admin.auth().setCustomUserClaims(uid, {
    companyId,
    role,
    employeeId,
  });

  return { ok: true, companyId, role, employeeId };
});

exports.authSelectAccountantCompany = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['ACCOUNTANT']);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const linkSnap = await admin
    .firestore()
    .collection('accountant_links')
    .where('accountantUserId', '==', claims.uid)
    .where('companyId', '==', companyId)
    .where('status', '==', 'active')
    .limit(1)
    .get();

  if (linkSnap.empty) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'O contador nao possui vinculo ativo com a empresa informada.',
    );
  }

  await persistAccountantCurrentCompany(claims.uid, companyId);
  await admin.auth().setCustomUserClaims(claims.uid, {
    companyId,
    role: claims.role,
    employeeId: claims.employeeId,
  });

  return {ok: true, companyId};
});

exports.authSetClaimsForUser = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const targetUid = String(data?.targetUid ?? '').trim();
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid obrigatorio.');
  }

  const target = await carregarUsuarioMesmoTenant(targetUid, claims);
  const role = roleParaFirestore(target.role);
  const companyId = role === 'ACCOUNTANT'
    ? await resolveAccountantCompanyContext(
        targetUid,
        asTrimmedString((target as Record<string, unknown>).currentCompanyId) ||
          String(target.companyId ?? '').trim(),
      )
    : String(target.companyId ?? '').trim();
  const employeeId = String(target.employeeId ?? targetUid).trim();

  await admin.auth().setCustomUserClaims(targetUid, {
    companyId,
    role,
    employeeId,
  });

  await writeAudit({
    claims,
    module: 'auth',
    action: 'set_claims_user',
    entityPath: 'users',
    entityId: targetUid,
    before: null,
    after: { companyId, role, employeeId },
  });

  return { ok: true };
});

exports.platformListCompanies = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const usersSnap = await admin
    .firestore()
    .collection('users')
    .where('role', '==', 'OWNER')
    .limit(200)
    .get();

  const rows: Array<{companyId: string; millis: number; item: Record<string, unknown>}> =
    await Promise.all(
    usersSnap.docs.map(async (doc) => {
      const data = asRecord(doc.data());
      const companyId = asTrimmedString(data.companyId);
      const settingsSnap = companyId
        ? await admin.firestore().collection('company_settings').doc(companyId).get()
        : null;
      const rawSettingsData = asRecord(settingsSnap?.data());
      const settingsData = companyId
        ? await mergeFiscalSecureSettings(companyId, rawSettingsData)
        : rawSettingsData;
      const commercial = buildDefaultCommercialSettings(settingsData);
      const billing = asRecord(commercial.billingIntegration);
      const accountantPending = asRecord(settingsData.accountantOnboardingPending);
      const accountantPendingStatusRaw = asTrimmedString(accountantPending.status);
      const accountantPendingStatus =
        accountantPendingStatusRaw === 'invited'
          ? 'pending_accountant_link'
          : accountantPendingStatusRaw;
      const fiscalSnapshot = companyId
        ? buildFiscalPlatformSnapshot({
            companyId,
            ownerUid: doc.id,
            ownerData: data,
            settingsData,
          })
        : {};
      const item = {
        ownerUid: doc.id,
        companyId,
        companyName:
          asTrimmedString(data.companyName) ||
          asTrimmedString(asRecord(data.companyData).nomeFantasia),
        ownerName: asTrimmedString(data.nome),
        ownerEmail: asTrimmedString(data.email),
        companyDocument:
          asTrimmedString(asRecord(data.companyData).cnpj) ||
          asTrimmedString(asRecord(data.companyData).cpf),
        city: asTrimmedString(asRecord(data.companyData).cidade),
        state: asTrimmedString(asRecord(data.companyData).estado),
        phone: asTrimmedString(asRecord(data.companyData).telefone),
        lifecycleStatus: commercial.lifecycleStatus,
        plan: commercial.plan,
        businessTier: asTrimmedString(commercial.businessTier),
        allowLogin: commercial.allowLogin !== false,
        approvalStatus: commercial.approvalStatus,
        accessControlMode: asTrimmedString(commercial.accessControlMode),
        activationRequired: commercial.activationRequired === true,
        activationStatus: asTrimmedString(commercial.activationStatus),
        activationCodeLast4: asTrimmedString(commercial.activationCodeLast4),
        activationCodeIssuedAt: timestampToIsoString(commercial.activationCodeIssuedAt),
        activationCodeExpiresAt: timestampToIsoString(commercial.activationCodeExpiresAt),
        activationReleasedAt: timestampToIsoString(commercial.activationReleasedAt),
        billingStatus: asTrimmedString(commercial.billingStatus),
        billingProvider: asTrimmedString(billing.provider),
        billingGatewayStatus: asTrimmedString(billing.status),
        billingAccessManagedByGateway: billing.accessManagedByGateway === true,
        billingCustomerId: asTrimmedString(billing.customerId),
        billingSubscriptionId: asTrimmedString(billing.subscriptionId),
        billingPaymentLinkUrl: asTrimmedString(billing.paymentLinkUrl || billing.checkoutUrl),
        billingExternalReference: asTrimmedString(billing.externalReference),
        billingGraceDays: Number(billing.graceDays ?? 3) || 3,
        billingCurrentPeriodEnd: timestampToIsoString(billing.currentPeriodEnd),
        billingGraceUntil: timestampToIsoString(billing.graceUntil),
        billingLastPaymentAt: timestampToIsoString(billing.lastPaymentAt),
        billingLastPaymentStatus: asTrimmedString(billing.lastPaymentStatus),
        billingLastWebhookEvent: asTrimmedString(billing.lastWebhookEvent),
        billingLastWebhookAt: timestampToIsoString(billing.lastWebhookAt),
        accountantOnboardingStatus: accountantPendingStatus,
        accountantOnboardingName: asTrimmedString(accountantPending.accountantName),
        accountantOnboardingEmail: asTrimmedString(accountantPending.accountantEmail),
        seatsIncluded: Number(commercial.seatsIncluded ?? 3) || 3,
        contractedAppUsers:
          Number(commercial.contractedAppUsers ?? commercial.seatsIncluded ?? 3) || 3,
        baseSystemPriceCents: Number(commercial.baseSystemPriceCents ?? 0) || 0,
        extraAppUserPriceCents:
          Number(commercial.extraAppUserPriceCents ?? 0) || 0,
        monthlyPriceCents: Number(commercial.monthlyPriceCents ?? 0) || 0,
        calculatedMonthlyPriceCents:
          Number(commercial.calculatedMonthlyPriceCents ?? commercial.monthlyPriceCents ?? 0) || 0,
        platformNote: asTrimmedString(commercial.platformNote),
        fiscalOverallStatus: asTrimmedString(fiscalSnapshot.overallStatus),
        fiscalPendingCount: Number(fiscalSnapshot.pendingCount ?? 0) || 0,
        fiscalCriticalPendingCount:
          Number(fiscalSnapshot.criticalPendingCount ?? 0) || 0,
        focusProvisioningStatus:
          asTrimmedString(fiscalSnapshot.focusProvisioningStatus),
      };
      return {
        companyId,
        millis: firestoreCreatedMillis(data.createdAt),
        item,
      };
    }),
  );

  const canonicalByCompany = new Map<string, Record<string, unknown>>();
  const bestMillis = new Map<string, number>();
  for (const row of rows) {
    if (!row.companyId) {
      continue;
    }
    const prev = bestMillis.get(row.companyId);
    if (prev === undefined || row.millis < prev) {
      bestMillis.set(row.companyId, row.millis);
      canonicalByCompany.set(row.companyId, row.item);
    }
  }

  const items = Array.from(canonicalByCompany.values());

  return {
    ok: true,
    items,
  };
});

exports.platformListStandaloneLightweightCompanies = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const ownersSnap = await admin
    .firestore()
    .collection('users')
    .where('role', '==', 'OWNER')
    .where('lightweightProfilePending', '==', true)
    .limit(120)
    .get();

  const buckets = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const doc of ownersSnap.docs) {
    const data = asRecord(doc.data());
    const companyId = asTrimmedString(data.companyId);
    if (!companyId || companyId === PUBLIC_DEMO_COMPANY_ID) {
      continue;
    }
    const prev = buckets.get(companyId);
    const ms = firestoreCreatedMillis(data.createdAt);
    if (!prev) {
      buckets.set(companyId, doc);
      continue;
    }
    const prevMs = firestoreCreatedMillis(asRecord(prev.data()).createdAt);
    if (ms < prevMs) {
      buckets.set(companyId, doc);
    }
  }

  const items: Record<string, unknown>[] = [];
  for (const [companyId, doc] of buckets.entries()) {
    const data = asRecord(doc.data());
    const settingsSnap = await admin
      .firestore()
      .collection('company_settings')
      .doc(companyId)
      .get();
    const settingsData = asRecord(settingsSnap.data());
    const ds = asRecord(settingsData.directSignup);
    const ap = asRecord(settingsData.accountantOnboardingPending);
    items.push({
      companyId,
      ownerUid: doc.id,
      ownerName: asTrimmedString(data.nome),
      ownerEmail: asTrimmedString(data.email).toLowerCase(),
      companyName:
        asTrimmedString(data.companyName) ||
        asTrimmedString(asRecord(data.companyData).nomeFantasia),
      lightweightSource: asTrimmedString(ds.source),
      directSignupPending: ds.lightweightProfilePending === true,
      accountantPendingStatus: asTrimmedString(ap.status),
      updatedAtIso: timestampToIsoString(settingsData.updatedAt),
    });
  }

  items.sort((a, b) =>
    String(b['updatedAtIso'] ?? '').localeCompare(String(a['updatedAtIso'] ?? '')),
  );

  return {
    ok: true,
    items,
  };
});

exports.platformListPublicDemoAccessLedger = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const limit = Math.min(300, Math.max(1, Number(data?.limit ?? 120) || 120));
  const snap = await demoPublicAccessRef().limit(800).get();
  const rows = snap.docs
    .map((doc) => {
      const item = asRecord(doc.data());
      const rolesRaw = item.roles ?? {};
      return {
        docId: doc.id,
        clientVisitorId: asTrimmedString(item.clientVisitorId),
        marketingVisitorId: asTrimmedString(item.visitorId),
        ipHashShort: asTrimmedString(item.ipHash).slice(0, 12),
        deviceType: asTrimmedString(item.deviceType),
        language: asTrimmedString(item.language),
        screen: `${Number(item.screenWidth ?? 0)}x${Number(item.screenHeight ?? 0)}`,
        accessCount: Number(item.accessCount ?? 0) || 0,
        rolesCompany: rolesRaw && typeof rolesRaw === 'object' ? (rolesRaw as Record<string, unknown>)['company'] === true : false,
        rolesAccountant:
          rolesRaw && typeof rolesRaw === 'object'
            ? (rolesRaw as Record<string, unknown>)['accountant'] === true
            : false,
        lastSeenAtIso: timestampToIsoString(item.lastSeenAt),
        firstSeenAtIso: timestampToIsoString(item.firstSeenAt),
        dedupeVersion: Number(item.dedupeVersion ?? 0) || 0,
        userAgentSnippet: asTrimmedString(item.userAgent).slice(0, 120),
      };
    })
    .sort((a, b) => String(b.lastSeenAtIso).localeCompare(String(a.lastSeenAtIso)))
    .slice(0, limit);

  return {
    ok: true,
    items: rows,
  };
});

exports.platformGetCompanyFiscalStatus = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const ownerSnap = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', companyId)
    .where('role', '==', 'OWNER')
    .limit(1)
    .get();
  if (ownerSnap.empty) {
    throw new functions.https.HttpsError('not-found', 'Owner da empresa nao encontrado.');
  }

  const ownerDoc = ownerSnap.docs[0];
  const settingsSnap = await admin
    .firestore()
    .collection('company_settings')
    .doc(companyId)
    .get();
  const settingsData = await mergeFiscalSecureSettings(companyId, asRecord(settingsSnap.data()));
  const snapshot = buildFiscalPlatformSnapshot({
    companyId,
    ownerUid: ownerDoc.id,
    ownerData: asRecord(ownerDoc.data()),
    settingsData,
  });

  return {
    ok: true,
    snapshot,
  };
});

exports.platformUpdateCompanyFiscalStatus = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const ownerSnap = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', companyId)
    .where('role', '==', 'OWNER')
    .limit(1)
    .get();
  if (ownerSnap.empty) {
    throw new functions.https.HttpsError('not-found', 'Owner da empresa nao encontrado.');
  }
  const ownerDoc = ownerSnap.docs[0];
  const ownerData = asRecord(ownerDoc.data());

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const settingsSnap = await settingsRef.get();
  const currentSettings = asRecord(settingsSnap.data());
  const currentIntegration = asRecord(currentSettings.fiscalRealIntegration);
  const currentChecklist = asRecord(currentSettings.fiscalHomologationChecklist);
  const currentControl = asRecord(currentSettings.fiscalPendingControl);

  const companyDataPatch = asRecord(data?.companyDataPatch);
  await syncPlatformCompanyDataPatch({
    companyId,
    companyDataPatch: {
      inscricaoMunicipal: asTrimmedString(companyDataPatch.inscricaoMunicipal) || undefined,
      cidade: asTrimmedString(companyDataPatch.cidade) || undefined,
      estado: asTrimmedString(companyDataPatch.estado).toUpperCase() || undefined,
      codigoMunicipio: asTrimmedString(companyDataPatch.codigoMunicipio) || undefined,
      cityCode: asTrimmedString(companyDataPatch.codigoMunicipio) || undefined,
      ibgeCode: asTrimmedString(companyDataPatch.codigoMunicipio) || undefined,
      codigoServicoPadrao: asTrimmedString(companyDataPatch.codigoServicoPadrao) || undefined,
      defaultServiceCode: asTrimmedString(companyDataPatch.codigoServicoPadrao) || undefined,
      mainCnae: asTrimmedString(companyDataPatch.mainCnae) || undefined,
    },
  });

  const integrationPatchRaw = asRecord(data?.integrationPatch);
  const integrationPatch = {
    environment:
      asTrimmedString(integrationPatchRaw.environment) || currentIntegration.environment,
    provider: asTrimmedString(integrationPatchRaw.provider) || currentIntegration.provider,
    focusNfseApi:
      asTrimmedString(integrationPatchRaw.focusNfseApi) || currentIntegration.focusNfseApi,
    municipalCode:
      asTrimmedString(integrationPatchRaw.municipalCode) || currentIntegration.municipalCode,
    certificateRef:
      asTrimmedString(integrationPatchRaw.certificateRef) || currentIntegration.certificateRef,
    apiBaseUrl:
      asTrimmedString(integrationPatchRaw.apiBaseUrl) || currentIntegration.apiBaseUrl,
    apiToken:
      asTrimmedString(integrationPatchRaw.apiToken) || currentIntegration.apiToken,
    lastHomologationNote:
      asTrimmedString(integrationPatchRaw.lastHomologationNote) ||
      currentIntegration.lastHomologationNote,
  };

  const checklistPatchRaw = asRecord(data?.checklistPatch);
  const checklistPatch = {
    companyBaseReviewed:
      checklistPatchRaw.companyBaseReviewed ?? currentChecklist.companyBaseReviewed,
    certificateValidated:
      checklistPatchRaw.certificateValidated ?? currentChecklist.certificateValidated,
    matrixValidated: checklistPatchRaw.matrixValidated ?? currentChecklist.matrixValidated,
    providerConnectionValidated:
      checklistPatchRaw.providerConnectionValidated ??
      currentChecklist.providerConnectionValidated,
    pilotInvoiceValidated:
      checklistPatchRaw.pilotInvoiceValidated ?? currentChecklist.pilotInvoiceValidated,
    productionAuthorized:
      checklistPatchRaw.productionAuthorized ?? currentChecklist.productionAuthorized,
  };

  const pendingItemsRaw = Array.isArray(data?.pendingItems) ? data.pendingItems : [];
  const nextPendingControl: Record<string, unknown> = {...currentControl};
  for (const item of pendingItemsRaw) {
    const map = asRecord(item);
    const code = asTrimmedString(map.code);
    if (!code) continue;
    nextPendingControl[code] = {
      owner: asTrimmedString(map.owner),
      status: asTrimmedString(map.status) || 'pending',
      note: asTrimmedString(map.note),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByUid: claims.uid,
    };
  }

  const securePatchRaw = asRecord(data?.securePatch);
  const hasSecurePatch =
    asTrimmedString(securePatchRaw.certificatePassword) ||
    asTrimmedString(securePatchRaw.responsibleLogin) ||
    asTrimmedString(securePatchRaw.responsiblePassword);

  await settingsRef.set(
    {
      fiscalRealIntegration: integrationPatch,
      fiscalHomologationChecklist: checklistPatch,
      fiscalPendingControl: nextPendingControl,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  if (hasSecurePatch) {
    const secureSecrets: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (asTrimmedString(securePatchRaw.certificatePassword)) {
      secureSecrets.password = asTrimmedString(securePatchRaw.certificatePassword);
    }
    if (asTrimmedString(securePatchRaw.responsibleLogin)) {
      secureSecrets.loginResponsavel = asTrimmedString(securePatchRaw.responsibleLogin);
    }
    if (asTrimmedString(securePatchRaw.responsiblePassword)) {
      secureSecrets.senhaResponsavel = asTrimmedString(securePatchRaw.responsiblePassword);
    }
    await admin
      .firestore()
      .collection('fiscal_secure')
      .doc(companyId)
      .set(
        {
          companyId,
          fiscalCertificateSecrets: secureSecrets,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
  }

  const refreshedSettingsSnap = await settingsRef.get();
  const refreshedSettingsData = asRecord(refreshedSettingsSnap.data());
  const companyData =
    mapCompanyData(refreshedSettingsData.companyData) ||
    mapCompanyData(ownerData.companyData);
  if (!companyData) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Dados da empresa nao encontrados para atualizar a automacao fiscal.',
    );
  }

  const {focusProvisioning} = await refreshCompanyProvisioningState({
    claims: {
      uid: claims.uid,
      companyId,
      role: 'OWNER',
      employeeId: ownerDoc.id,
    },
    companyData,
  });

  const finalSettingsSnap = await settingsRef.get();
  const finalSettingsData = await mergeFiscalSecureSettings(
    companyId,
    asRecord(finalSettingsSnap.data()),
  );
  const snapshot = buildFiscalPlatformSnapshot({
    companyId,
    ownerUid: ownerDoc.id,
    ownerData,
    settingsData: finalSettingsData,
  });

  const sendPendingEmail = data?.sendPendingEmail === true;
  const customMessage = asTrimmedString(data?.customMessage);
  if (sendPendingEmail) {
    const pendingItems = (snapshot.pendingItems as Record<string, unknown>[]).filter(
      (item) => {
        const owner = asTrimmedString(item.owner);
        return owner === 'company' || item.documentRequired === true;
      },
    );
    if (pendingItems.length > 0) {
      const emailCfg = obterConfigEmail();
      await enviarEmailPendenciasFiscaisEmpresa({
        email: asTrimmedString(ownerData.email).toLowerCase(),
        nome: asTrimmedString(ownerData.nome),
        companyName: asTrimmedString(snapshot.companyName),
        pendingItems,
        customMessage,
        fromEmail: emailCfg.fromEmail,
        sendgridKey: emailCfg.sendgridKey,
        smtpUser: emailCfg.smtpUser,
        smtpAppPassword: emailCfg.smtpAppPassword,
      });
      await settingsRef.set(
        {
          fiscalPendingCommunication: {
            lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSentTo: asTrimmedString(ownerData.email).toLowerCase(),
            summary:
              customMessage ||
              `${pendingItems.length} pendencia(s) fiscal(is) enviada(s) automaticamente para a empresa.`,
            requestedByUid: claims.uid,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }

  await writeAudit({
    claims,
    module: 'platform',
    action: 'update_company_fiscal_status',
    entityPath: 'company_settings',
    entityId: companyId,
    before: null,
    after: {
      focusProvisioningStatus: asTrimmedString(focusProvisioning.status),
      pendingCount: Number(snapshot.pendingCount ?? 0) || 0,
      sendPendingEmail,
    },
  });

  return {
    ok: true,
    snapshot,
  };
});

exports.platformSyncCompanyFocus = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const ownerSnap = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', companyId)
    .where('role', '==', 'OWNER')
    .limit(1)
    .get();
  if (ownerSnap.empty) {
    throw new functions.https.HttpsError('not-found', 'Owner da empresa nao encontrado.');
  }
  const ownerDoc = ownerSnap.docs[0];
  const ownerData = asRecord(ownerDoc.data());
  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = await mergeFiscalSecureSettings(companyId, asRecord(settingsSnap.data()));
  const companyData =
    mapCompanyData(settingsData.companyData) ||
    mapCompanyData(ownerData.companyData);
  if (!companyData) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Dados da empresa nao encontrados para sincronizar com a Focus.',
    );
  }

  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (!providerIsFocus(asTrimmedString(setup.provider))) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Selecione Focus NFe como provedor antes de sincronizar.',
    );
  }

  const result = await syncFocusCompany({
    claims: {
      uid: claims.uid,
      companyId,
      role: 'OWNER',
      employeeId: ownerDoc.id,
    },
    companyData,
    settingsData,
  });

  await settingsRef.set(
    {
      focusProvisioning: {
        status: 'SYNCED',
        missing: [],
        focusCompanyId: asTrimmedString(result.id),
        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await mergeFiscalHomologationChecklist({
    companyId,
    patch: {
      providerConnectionValidated: true,
    },
  });

  const finalSettingsSnap = await settingsRef.get();
  const finalSettingsData = await mergeFiscalSecureSettings(
    companyId,
    asRecord(finalSettingsSnap.data()),
  );
  const snapshot = buildFiscalPlatformSnapshot({
    companyId,
    ownerUid: ownerDoc.id,
    ownerData,
    settingsData: finalSettingsData,
  });

  await writeAudit({
    claims,
    module: 'platform',
    action: 'platform_sync_company_focus',
    entityPath: 'company_settings',
    entityId: companyId,
    before: null,
    after: {
      focusCompanyId: asTrimmedString(result.id),
      certificateValidUntil: asTrimmedString(result.certificado_valido_ate),
    },
  });

  return {
    ok: true,
    focusCompanyId: asTrimmedString(result.id),
    certificadoValidoAte: asTrimmedString(result.certificado_valido_ate),
    snapshot,
  };
});

exports.platformExtendCompanyTrial = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  const extraDays = Math.max(1, Math.min(60, Number(data?.extraDays ?? 0) || 0));
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }
  if (!extraDays) {
    throw new functions.https.HttpsError('invalid-argument', 'extraDays obrigatorio (min 1).');
  }

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const beforeSnap = await settingsRef.get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'company_settings nao encontrado.');
  }
  const beforeData = asRecord(beforeSnap.data());
  const currentCommercial = buildDefaultCommercialSettings(beforeData);
  const currentBilling = asRecord(currentCommercial.billingIntegration);

  const lifecycleStatus = asTrimmedString(currentCommercial.lifecycleStatus).toLowerCase();
  if (lifecycleStatus !== 'trial') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Esta empresa nao esta em modo trial.',
    );
  }

  const now = Date.now();
  const currentGraceUntilValue = currentBilling.graceUntil;
  const currentGraceUntilMillis = currentGraceUntilValue instanceof admin.firestore.Timestamp
    ? currentGraceUntilValue.toMillis()
    : currentGraceUntilValue instanceof Date
      ? currentGraceUntilValue.getTime()
      : Number.NaN;
  const baseMillis = Number.isFinite(currentGraceUntilMillis)
    ? Math.max(currentGraceUntilMillis, now)
    : now;
  const nextGraceUntil = admin.firestore.Timestamp.fromMillis(
    baseMillis + extraDays * 24 * 60 * 60 * 1000,
  );

  await settingsRef.set(
    {
      commercialSettings: {
        ...currentCommercial,
        allowLogin: true,
        billingStatus: 'trialing',
        billingIntegration: {
          ...currentBilling,
          status: asTrimmedString(currentBilling.status) || 'trialing',
          graceUntil: nextGraceUntil,
          graceDays: Math.max(
            Number(currentBilling.graceDays ?? 0) || 0,
            Number(extraDays) || 0,
          ),
        },
        platformNote: `Trial estendido em +${extraDays} dias pela plataforma.`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'extend_company_trial',
    entityPath: 'company_settings',
    entityId: companyId,
    before: {
      lifecycleStatus: currentCommercial.lifecycleStatus,
      billingStatus: currentCommercial.billingStatus,
      graceUntil: timestampToIsoString(currentBilling.graceUntil),
    },
    after: {
      lifecycleStatus: 'trial',
      billingStatus: 'trialing',
      graceUntil: nextGraceUntil.toDate().toISOString(),
      extraDays,
    },
  });

  return {
    ok: true,
    companyId,
    graceUntil: nextGraceUntil.toDate().toISOString(),
    extraDays,
  };
});

exports.platformListTrialInvites = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const limit = Math.max(1, Math.min(200, Number(data?.limit ?? 50) || 50));
  const snap = await trialInviteRef()
    .orderBy('tokenIssuedAt', 'desc')
    .limit(limit)
    .get();

  const items = snap.docs.map((doc) => {
    const item = asRecord(doc.data());
    const expiresAt = item.tokenExpiresAt;
    const expiresAtMillis = expiresAt instanceof admin.firestore.Timestamp
      ? expiresAt.toMillis()
      : expiresAt instanceof Date
        ? expiresAt.getTime()
        : Number.NaN;
    const expiresAtIso = expiresAt instanceof admin.firestore.Timestamp
      ? expiresAt.toDate().toISOString()
      : expiresAt instanceof Date
        ? expiresAt.toISOString()
        : '';
    const issuedAt = item.tokenIssuedAt;
    const issuedAtIso = issuedAt instanceof admin.firestore.Timestamp
      ? issuedAt.toDate().toISOString()
      : issuedAt instanceof Date
        ? issuedAt.toISOString()
        : '';
    const usedAt = item.usedAt;
    const usedAtIso = usedAt instanceof admin.firestore.Timestamp
      ? usedAt.toDate().toISOString()
      : usedAt instanceof Date
        ? usedAt.toISOString()
        : '';
    const deletedAt = item.deletedAt;
    const deletedAtIso = deletedAt instanceof admin.firestore.Timestamp
      ? deletedAt.toDate().toISOString()
      : deletedAt instanceof Date
        ? deletedAt.toISOString()
        : '';
    const storedStatus = asTrimmedString(item.status);
    const effectiveStatus =
      storedStatus === 'issued' &&
      Number.isFinite(expiresAtMillis) &&
      expiresAtMillis < Date.now()
        ? 'expired'
        : storedStatus;

    return {
      id: doc.id,
      status: effectiveStatus,
      companyEmail: asTrimmedString(item.companyEmail),
      accountantEmail: asTrimmedString(item.accountantEmail),
      usedCompanyId: asTrimmedString(item.usedCompanyId),
      usedOfficeId: asTrimmedString(item.usedOfficeId),
      issuedByUid: asTrimmedString(item.issuedByUid),
      issuedByName: asTrimmedString(item.issuedByName),
      issuedAtIso,
      expiresAtIso,
      usedAtIso,
      notes: asTrimmedString(item.notes),
      deletedAtIso,
      deletedByName: asTrimmedString(item.deletedByName),
    };
  });

  return { ok: true, items };
});

exports.platformDeleteTrialInvites = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const rawInviteIds: unknown[] = Array.isArray(data?.inviteIds)
    ? (data.inviteIds as unknown[])
    : [];
  const inviteIds: string[] = rawInviteIds
    .map((item) => String(item ?? '').trim())
    .filter((item) => item.length > 0);

  const uniqueIds = Array.from(new Set(inviteIds)).slice(0, 100);
  if (!uniqueIds.length) {
    throw new functions.https.HttpsError('invalid-argument', 'inviteIds obrigatorio.');
  }

  const batch = admin.firestore().batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  for (const id of uniqueIds) {
    const ref = trialInviteRef().doc(id);
    batch.set(
      ref,
      {
        status: 'deleted',
        deletedAt: now,
        deletedByUid: claims.uid,
        deletedByName: asTrimmedString(userProfile.nome) || asTrimmedString(userProfile.name),
        updatedAt: now,
      },
      { merge: true },
    );
  }
  await batch.commit();

  await writeAudit({
    claims,
    module: 'platform',
    action: 'delete_trial_invites',
    entityPath: 'trial_invites',
    entityId: 'bulk',
    before: {},
    after: { inviteIds: uniqueIds },
  });

  return { ok: true, deleted: uniqueIds.length };
});

exports.platformPurgeDeletedTrialInvites = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const rawInviteIds: unknown[] = Array.isArray(data?.inviteIds)
    ? (data.inviteIds as unknown[])
    : [];
  const inviteIds: string[] = rawInviteIds
    .map((item) => String(item ?? '').trim())
    .filter((item) => item.length > 0);

  const uniqueIds = Array.from(new Set(inviteIds)).slice(0, 200);
  if (!uniqueIds.length) {
    throw new functions.https.HttpsError('invalid-argument', 'inviteIds obrigatorio.');
  }

  const refs = uniqueIds.map((id) => trialInviteRef().doc(id));
  const snaps = await Promise.all(refs.map((ref) => ref.get()));

  const batch = admin.firestore().batch();
  let purged = 0;
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const data = asRecord(snap.data());
    if (asTrimmedString(data.status) !== 'deleted') {
      continue;
    }
    batch.delete(snap.ref);
    purged += 1;
  }
  await batch.commit();

  await writeAudit({
    claims,
    module: 'platform',
    action: 'purge_deleted_trial_invites',
    entityPath: 'trial_invites',
    entityId: 'bulk',
    before: {},
    after: { inviteIds: uniqueIds, purged },
  });

  return { ok: true, purged };
});

/**
 * Listagem administrativa: escritorios e empresas vinculadas (company_settings.accountantOffice.officeId).
 * Nao altera company_settings nem fluxos de cadastro.
 */
async function listCompanySettingsLinkedToOffice(officeId: string): Promise<Record<string, unknown>[]> {
  const snap = await admin
    .firestore()
    .collection('company_settings')
    .where('accountantOffice.officeId', '==', officeId)
    .limit(200)
    .get();
  const out: Record<string, unknown>[] = [];
  for (const doc of snap.docs) {
    const companyId = doc.id;
    if (companyId === officeId) {
      continue;
    }
    const raw = asRecord(doc.data());
    const settingsData = await mergeFiscalSecureSettings(companyId, raw);
    const companyData = asRecord(settingsData.companyData);
    const commercial = buildDefaultCommercialSettings(settingsData);
    const billing = asRecord(commercial.billingIntegration);
    const pending = asRecord(settingsData.accountantOnboardingPending);
    out.push({
      companyId,
      companyName:
        asTrimmedString(companyData.nomeFantasia) ||
        asTrimmedString(companyData.razaoSocial) ||
        companyId,
      companyDocument: onlyDigits(companyData.cnpj),
      city: asTrimmedString(companyData.cidade),
      state: asTrimmedString(companyData.estado),
      lifecycleStatus: asTrimmedString(commercial.lifecycleStatus),
      allowLogin: commercial.allowLogin !== false,
      billingStatus: asTrimmedString(commercial.billingStatus),
      billingGraceUntil: timestampToIsoString(billing.graceUntil),
      accountantOnboardingStatus: asTrimmedString(pending.status),
    });
  }
  return out;
}

exports.platformListAccountingOffices = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const limit = Math.max(1, Math.min(300, Number(data?.limit ?? 200) || 200));
  const searchEmail = asTrimmedString(data?.searchEmail).toLowerCase();
  const snap = await accountingOfficeRef().orderBy('updatedAt', 'desc').limit(limit).get();

  const byId = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  if (searchEmail) {
    const emailSnap = await accountingOfficeRef()
      .where('email', '==', searchEmail)
      .limit(20)
      .get();
    for (const d of emailSnap.docs) {
      byId.set(d.id, d);
    }
  }
  for (const d of snap.docs) {
    byId.set(d.id, d);
  }
  const docs = Array.from(byId.values());
  const orderedDocs = (() => {
    if (!searchEmail) {
      return docs;
    }
    const matches: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    const rest: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    for (const d of docs) {
      if (asTrimmedString(d.data().email).toLowerCase() === searchEmail) {
        matches.push(d);
      } else {
        rest.push(d);
      }
    }
    return [...matches, ...rest];
  })();

  const items = await Promise.all(
    orderedDocs.map(async (doc) => {
      const o = asRecord(doc.data());
      const officeId = doc.id;
      const companies = await listCompanySettingsLinkedToOffice(officeId);
      const storedCount = Number(o.linkedCompaniesCount ?? 0) || 0;
      return {
        officeId,
        officeName: asTrimmedString(o.officeName),
        officeDisplayCode: asTrimmedString(o.officeDisplayCode),
        email: asTrimmedString(o.email).toLowerCase(),
        cnpj: onlyDigits(o.cnpj),
        responsibleName: asTrimmedString(o.responsibleName),
        phone: asTrimmedString(o.phone),
        city: asTrimmedString(o.city),
        state: asTrimmedString(o.state),
        platformStatus: asTrimmedString(o.platformStatus) || 'active',
        officeBillingStatus: asTrimmedString(o.officeBillingStatus),
        active: o.active !== false,
        accessSuspended: o.accessSuspended === true,
        source: asTrimmedString(o.source),
        linkedCompaniesCount: companies.length > 0 ? companies.length : storedCount,
        companies,
        updatedAt: timestampToIsoString(o.updatedAt),
        createdAt: timestampToIsoString(o.createdAt),
      };
    }),
  );
  return {ok: true, items};
});

exports.platformSetAccountingOfficeAccess = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const officeId = asTrimmedString(data?.officeId);
  const allowAccess = data?.allowAccess === true;
  const reason = asTrimmedString(data?.reason);

  if (!officeId) {
    throw new functions.https.HttpsError('invalid-argument', 'officeId obrigatorio.');
  }
  if (!allowAccess && !reason) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe o motivo administrativo ao suspender acesso.',
    );
  }

  const issuerName = asTrimmedString(userProfile.nome) || asTrimmedString((userProfile as Record<string, unknown>).name) || 'platform';
  const ref = accountingOfficeRef().doc(officeId);
  const beforeSnap = await ref.get();
  if (!beforeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Escritorio nao encontrado.');
  }
  const before = asRecord(beforeSnap.data());

  await ref.set(
    {
      accessSuspended: !allowAccess,
      platformStatus: allowAccess ? 'active' : 'suspended',
      accessUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      accessUpdatedByUid: claims.uid,
      accessUpdatedByName: issuerName,
      accessAdministrativeReason: allowAccess ? admin.firestore.FieldValue.delete() : reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const usersSnap = await admin
    .firestore()
    .collection('users')
    .where('officeId', '==', officeId)
    .where('role', '==', 'ACCOUNTANT')
    .limit(50)
    .get();

  for (const d of usersSnap.docs) {
    try {
      await admin.auth().updateUser(d.id, {disabled: !allowAccess});
    } catch (e) {
      functions.logger.warn('platformSetAccountingOfficeAccess: auth update failed', d.id, e);
    }
  }

  await writeAudit({
    claims,
    module: 'platform',
    action: 'set_accounting_office_access',
    entityPath: 'accounting_offices',
    entityId: officeId,
    before: {platformStatus: asTrimmedString(before.platformStatus), accessSuspended: before.accessSuspended === true},
    after: {allowAccess, reason: allowAccess ? '' : reason},
  });

  return {ok: true, officeId, allowAccess, accountantsUpdated: usersSnap.size};
});

exports.platformReconcileAccountingOfficeTrialInvite = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const officeId = asTrimmedString(data?.officeId);
  if (!officeId) {
    throw new functions.https.HttpsError('invalid-argument', 'officeId obrigatorio.');
  }

  const officeSnap = await accountingOfficeRef().doc(officeId).get();
  if (!officeSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Escritorio nao encontrado.');
  }
  const o = asRecord(officeSnap.data());
  const email = asTrimmedString(o.email).toLowerCase();
  if (!email) {
    return {ok: true, updated: 0, message: 'Escritorio sem email cadastrado.'};
  }

  const trialSnap = await trialInviteRef().where('accountantEmail', '==', email).limit(30).get();
  if (trialSnap.empty) {
    return {ok: true, updated: 0, message: 'Nenhum convite trial com este email de contador.'};
  }

  const batch = admin.firestore().batch();
  let updated = 0;
  for (const doc of trialSnap.docs) {
    const t = asRecord(doc.data());
    if (asTrimmedString(t.status) === 'deleted') {
      continue;
    }
    const existingUsedOffice = asTrimmedString(t.usedOfficeId);
    if (existingUsedOffice === officeId) {
      continue;
    }
    if (existingUsedOffice && existingUsedOffice !== officeId) {
      continue;
    }
    const status = asTrimmedString(t.status);
    if (status === 'used' && asTrimmedString(t.usedOfficeId) === '') {
      batch.set(
        doc.ref,
        {usedOfficeId: officeId, updatedAt: admin.firestore.FieldValue.serverTimestamp()},
        {merge: true},
      );
      updated += 1;
    } else if (status === 'issued') {
      batch.set(
        doc.ref,
        {
          status: 'used',
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
          usedOfficeId: officeId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      updated += 1;
    }
  }
  if (updated > 0) {
    await batch.commit();
  }

  await writeAudit({
    claims,
    module: 'platform',
    action: 'reconcile_accounting_office_trial_invite',
    entityPath: 'accounting_offices',
    entityId: officeId,
    before: null,
    after: {email, updatedInvites: updated},
  });

  return {ok: true, updated};
});

exports.platformListSalesPipeline = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const [
    leadSnap,
    onboardingSnap,
    employeeTesterSnap,
    feedbackSnap,
    feedbackIncidentSnap,
    feedbackIssueSnap,
    unmatchedBillingSnap,
    pendingAccountantSnap,
    officeBillingSnap,
  ] = await Promise.all([
    salesLeadRef().orderBy('updatedAt', 'desc').limit(100).get(),
    salesOnboardingRef().orderBy('updatedAt', 'desc').limit(100).get(),
    employeeTesterLeadRef().orderBy('updatedAt', 'desc').limit(100).get(),
    admin.firestore().collection('product_feedback').limit(300).get(),
    admin.firestore().collection('runtime_incidents').where('source', '==', 'product_feedback').limit(360).get(),
    admin.firestore().collection('system_issues').where('source', '==', 'product_feedback').limit(360).get(),
    admin.firestore().collection('billing_webhook_events').where('status', '==', 'unmatched').limit(20).get(),
    admin.firestore().collection('company_settings').where('accountantOnboardingPending.status', '==', 'pending_accountant_link').limit(50).get(),
    accountingOfficeRef().where('officeBillingStatus', 'in', ['pending_setup', 'pending_payment', 'overdue', 'failed']).limit(50).get(),
  ]);

  const leads = leadSnap.docs.map((doc) => {
    const item = asRecord(doc.data());
    return {
      id: doc.id,
      status: asTrimmedString(item.status),
      customerName: asTrimmedString(item.customerName),
      customerEmail: asTrimmedString(item.customerEmail),
      accountantName: asTrimmedString(item.accountantName),
      accountantEmail: asTrimmedString(item.accountantEmail),
      planCode: asTrimmedString(item.planCode),
      planTitle: asTrimmedString(item.planTitle),
      implementationMode: asTrimmedString(item.implementationMode),
      onboardingRequestId: asTrimmedString(item.onboardingRequestId),
      updatedAt: timestampToIsoString(item.updatedAt),
      createdAt: timestampToIsoString(item.createdAt),
    };
  });

  const onboardings = onboardingSnap.docs.map((doc) => {
    const item = asRecord(doc.data());
    const formData = asRecord(item.formData);
    const implementationCharge = asRecord(item.implementationCharge);
    return {
      id: doc.id,
      status: asTrimmedString(item.status),
      customerName: asTrimmedString(item.customerName),
      customerEmail: asTrimmedString(item.customerEmail),
      originalBuyerName: asTrimmedString(item.originalBuyerName),
      originalBuyerEmail: asTrimmedString(item.originalBuyerEmail),
      planCode: asTrimmedString(item.planCode),
      planTitle: asTrimmedString(item.planTitle),
      implementationMode: asTrimmedString(item.implementationMode),
      implementationFeeCents: Number(item.implementationFeeCents ?? 0) || 0,
      implementationChargePaymentId: asTrimmedString(implementationCharge.paymentId),
      implementationChargeStatus: asTrimmedString(implementationCharge.status),
      implementationChargeInvoiceUrl:
        asTrimmedString(implementationCharge.invoiceUrl) ||
        asTrimmedString(implementationCharge.bankSlipUrl),
      implementationChargeAutomationError: asTrimmedString(item.implementationChargeAutomationError),
      companyId: asTrimmedString(item.companyId),
      companyName: asTrimmedString(item.companyName),
      ownerEmail: asTrimmedString(item.ownerEmail),
      archivedCompanyPath: asTrimmedString(item.archivedCompanyPath),
      accountantName: asTrimmedString(item.accountantName),
      accountantEmail: asTrimmedString(item.accountantEmail),
      legalName: asTrimmedString(formData.legalName),
      document: asTrimmedString(formData.document),
      city: asTrimmedString(formData.city),
      state: asTrimmedString(formData.state),
      uploadedCount:
        Number(item.uploadedCount ?? 0) ||
        (Array.isArray(item.uploads) ? item.uploads.length : 0),
      submittedAt: timestampToIsoString(item.submittedAt),
      updatedAt: timestampToIsoString(item.updatedAt),
    };
  });

  const employeeTesterLeads = employeeTesterSnap.docs.map((doc) => {
    const item = asRecord(doc.data());
    return {
      id: doc.id,
      status: asTrimmedString(item.status),
      fullName: asTrimmedString(item.fullName),
      email: asTrimmedString(item.email),
      phone: asTrimmedString(item.phone),
      city: asTrimmedString(item.city),
      state: asTrimmedString(item.state),
      occupation: asTrimmedString(item.occupation),
      sourceBucket: asTrimmedString(item.sourceBucket),
      utmSource: asTrimmedString(item.utmSource),
      utmCampaign: asTrimmedString(item.utmCampaign),
      testerUid: asTrimmedString(item.testerUid),
      playStoreTesterIncludedAt: timestampToIsoString(item.playStoreTesterIncludedAt),
      playStoreReleasedAt: timestampToIsoString(item.playStoreReleasedAt),
      inviteSentAt: timestampToIsoString(item.inviteSentAt),
      realAccessReleasedAt: timestampToIsoString(item.realAccessReleasedAt),
      realAccessUrl: asTrimmedString(item.realAccessUrl),
      updatedAt: timestampToIsoString(item.updatedAt),
      createdAt: timestampToIsoString(item.createdAt),
    };
  });

  const testerLeadsByUid = new Map<string, Record<string, unknown>>();
  for (const doc of employeeTesterSnap.docs) {
    const item = asRecord(doc.data());
    const testerUid = asTrimmedString(item.testerUid);
    if (testerUid) {
      testerLeadsByUid.set(testerUid, item);
    }
  }

  const userIds = new Set<string>();
  for (const doc of feedbackSnap.docs) {
    const item = asRecord(doc.data());
    const userId = asTrimmedString(item.userId);
    if (userId) userIds.add(userId);
  }
  for (const doc of feedbackIncidentSnap.docs) {
    const item = asRecord(doc.data());
    const reporterUserId = asTrimmedString(item.reporterUserId);
    if (reporterUserId) userIds.add(reporterUserId);
  }

  const userProfiles = await Promise.all(
    [...userIds].map(async (userId) => {
      const snap = await admin.firestore().collection('users').doc(userId).get();
      return [userId, asRecord(snap.data())] as const;
    }),
  );
  const userProfilesById = new Map<string, Record<string, unknown>>(userProfiles);

  const incidentsByFeedbackId = new Map<string, Record<string, unknown>>();
  for (const doc of feedbackIncidentSnap.docs) {
    const item = asRecord(doc.data());
    const extra = asRecord(item.extra);
    const feedbackId =
      asTrimmedString(extra.feedbackId) ||
      asTrimmedString(extra.originId) ||
      asTrimmedString(extra.feedbackDocId) ||
      (doc.id.startsWith('feedback_') ? doc.id.slice('feedback_'.length) : '');
    if (feedbackId) {
      incidentsByFeedbackId.set(feedbackId, {
        id: doc.id,
        ...item,
      });
    }
  }

  const issuesByIncidentId = new Map<string, Record<string, unknown>>();
  for (const doc of feedbackIssueSnap.docs) {
    const item = asRecord(doc.data());
    if (asTrimmedString(item.source) !== 'product_feedback') {
      continue;
    }
    const latestIncidentId = asTrimmedString(item.latestIncidentId);
    if (latestIncidentId) {
      issuesByIncidentId.set(latestIncidentId, {
        id: doc.id,
        ...item,
      });
    }
  }

  const productIdeas = feedbackSnap.docs.map((doc) => {
    const item = asRecord(doc.data());
    const incident = incidentsByFeedbackId.get(doc.id) || {};
    const issue = issuesByIncidentId.get(asTrimmedString(incident.id)) || {};
    const testerUid = asTrimmedString(item.userId) || asTrimmedString(incident.reporterUserId);
    const lead = testerLeadsByUid.get(testerUid) || {};
    const profile = userProfilesById.get(testerUid) || {};
    const companyData = asRecord(profile.companyData);
    const companyId = asTrimmedString(item.companyId) || asTrimmedString(profile.companyId);
    const companyName =
      asTrimmedString(profile.companyName) ||
      asTrimmedString(companyData.nomeFantasia) ||
      asTrimmedString(companyData.razaoSocial) ||
      (companyId === PUBLIC_EMPLOYEE_TESTER_COMPANY_ID
        ? PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME
        : '');
    return {
      id: doc.id,
      title: asTrimmedString(item.title) || 'Ideia registrada',
      module: asTrimmedString(item.module),
      priority: asTrimmedString(item.priority) || 'media',
      status: asTrimmedString(item.status) || 'novo',
      companyId,
      companyName,
      userId: testerUid,
      userName:
        asTrimmedString(lead.fullName) ||
        asTrimmedString(item.userName) ||
        asTrimmedString(incident.reporterName) ||
        asTrimmedString(profile.nome),
      userEmail: asTrimmedString(lead.email) || asTrimmedString(profile.email),
      userRole:
        asTrimmedString(item.userRole) ||
        asTrimmedString(incident.reporterRole) ||
        asTrimmedString(profile.role),
      context: asTrimmedString(item.context),
      idea: asTrimmedString(item.idea),
      userInfo: asTrimmedString(item.userInfo),
      incidentId: asTrimmedString(item.observabilityIncidentId) || asTrimmedString(incident.id),
      incidentStatus: asTrimmedString(incident.status),
      issueId: asTrimmedString(issue.id),
      issueStatus: asTrimmedString(issue.status),
      assistantSummary:
        asTrimmedString(incident.assistantSummary) ||
        asTrimmedString(issue.assistantSummary) ||
        asTrimmedString(item.assistantSummary),
      recommendedAction:
        asTrimmedString(incident.recommendedAction) ||
        asTrimmedString(issue.recommendedAction) ||
        asTrimmedString(item.recommendedAction),
      createdAt: timestampToIsoString(item.createdAt || incident.createdAt),
      updatedAt: timestampToIsoString(item.updatedAt || incident.updatedAt || item.createdAt),
    };
  });

  productIdeas.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));

  const governanceIssues: Record<string, unknown>[] = [];
  for (const doc of unmatchedBillingSnap.docs) {
    const item = asRecord(doc.data());
    const payload = asRecord(item.payload);
    const payment = asaasEventPaymentData(payload);
    governanceIssues.push({
      id: doc.id,
      type: 'asaas_unmatched',
      severity: 'warning',
      title: 'Webhook Asaas sem cadastro financeiro vinculado',
      description:
        `${asTrimmedString(item.eventName) || 'evento'} | pagamento ${asTrimmedString(item.paymentId) || asTrimmedString(payment.id) || '-'} | status ${asTrimmedString(item.status) || 'unmatched'}`,
      entityId: asTrimmedString(item.eventId) || doc.id,
      updatedAt: timestampToIsoString(item.updatedAt || item.createdAt),
    });
  }
  for (const doc of pendingAccountantSnap.docs) {
    const item = asRecord(doc.data());
    const pending = asRecord(item.accountantOnboardingPending);
    const companyData = asRecord(item.companyData);
    governanceIssues.push({
      id: `${doc.id}_accountant_pending`,
      type: 'accountant_link_pending',
      severity: 'warning',
      title: 'Empresa aguardando vinculo pelo contador',
      description:
        `${asTrimmedString(companyData.nomeFantasia) || asTrimmedString(companyData.razaoSocial) || doc.id} | contador: ${asTrimmedString(pending.accountantEmail) || '-'}`,
      entityId: doc.id,
      updatedAt: timestampToIsoString(pending.updatedAt || item.updatedAt),
    });
  }
  for (const doc of officeBillingSnap.docs) {
    const item = asRecord(doc.data());
    if (item.officePartnershipWaiverActive === true) continue;
    governanceIssues.push({
      id: `${doc.id}_office_billing`,
      type: 'office_billing_pending',
      severity: asTrimmedString(item.officeBillingStatus) === 'overdue' ? 'error' : 'warning',
      title: 'Cobranca do escritorio contabil pendente',
      description:
        `${asTrimmedString(item.officeName) || doc.id} | ${asTrimmedString(item.email) || '-'} | status ${asTrimmedString(item.officeBillingStatus) || 'pending_setup'}`,
      entityId: doc.id,
      updatedAt: timestampToIsoString(item.updatedAt || item.createdAt),
    });
  }
  for (const doc of onboardingSnap.docs) {
    const item = asRecord(doc.data());
    const error = asTrimmedString(item.implementationChargeAutomationError);
    if (!error) continue;
    governanceIssues.push({
      id: `${doc.id}_implementation_charge_error`,
      type: 'implementation_charge_error',
      severity: 'error',
      title: 'Falha ao gerar cobranca de implantacao',
      description: `${asTrimmedString(item.customerName) || asTrimmedString(item.customerEmail) || doc.id} | ${error}`,
      entityId: doc.id,
      updatedAt: timestampToIsoString(item.updatedAt),
    });
  }
  governanceIssues.sort((a, b) =>
    asTrimmedString(b.updatedAt).localeCompare(asTrimmedString(a.updatedAt)),
  );

  return {
    ok: true,
    leads,
    onboardings,
    employeeTesterLeads,
    productIdeas,
    governanceIssues,
  };
});

exports.publicCreateEmployeeTesterLead = functions.https.onCall(async (data) => {
  const fullName = asTrimmedString(data?.fullName);
  const email = asTrimmedString(data?.email).toLowerCase();
  const phone = asTrimmedString(data?.phone);
  const city = asTrimmedString(data?.city);
  const state = asTrimmedString(data?.state).toUpperCase();
  const occupation = asTrimmedString(data?.occupation);
  const tracking = asRecord(data?.tracking);
  const visitorId = asTrimmedString(tracking.visitorId);
  const sessionId = asTrimmedString(tracking.sessionId);
  const utmSource = sanitizeMarketingKey(tracking.utmSource);
  const utmMedium = sanitizeMarketingKey(tracking.utmMedium);
  const utmCampaign = sanitizeMarketingKey(tracking.utmCampaign);
  const utmContent = sanitizeMarketingKey(tracking.utmContent);
  const utmTerm = sanitizeMarketingKey(tracking.utmTerm);
  const referrerHost = marketingReferrerHost(tracking.referrerHost || tracking.referrer);
  const sourceBucket = inferMarketingSourceBucket({
    utmSource,
    referrerHost,
  });

  if (!fullName || !email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email para entrar na fila de testes.',
    );
  }

  const existing = await employeeTesterLeadRef()
    .where('email', '==', email)
    .limit(1)
    .get();
  const leadRef = existing.empty ? employeeTesterLeadRef().doc() : existing.docs[0].ref;
  const currentData = existing.empty ? {} : asRecord(existing.docs[0].data());
  const currentStatus = asTrimmedString(currentData.status);

  await leadRef.set(
    {
      status: currentStatus || 'new',
      fullName,
      email,
      phone,
      city,
      state,
      occupation,
      sourceBucket,
      utmSource,
      utmMedium,
      utmCampaign,
      utmContent,
      utmTerm,
      visitorId,
      sessionId,
      referrerHost,
      originPage: '/teste-funcionario',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: existing.empty
        ? admin.firestore.FieldValue.serverTimestamp()
        : currentData.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    ok: true,
    leadId: leadRef.id,
    status: currentStatus || 'new',
  };
});

exports.platformMarkEmployeeTesterPlayStoreIncluded = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const leadId = asTrimmedString(data?.leadId);
  if (!leadId) {
    throw new functions.https.HttpsError('invalid-argument', 'leadId obrigatorio.');
  }

  const leadRef = employeeTesterLeadRef().doc(leadId);
  const leadSnap = await leadRef.get();
  if (!leadSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Lead de testador nao encontrado.');
  }

  const lead = asRecord(leadSnap.data());
  const nextStatus =
    asTrimmedString(lead.status) === 'access_sent' ? 'access_sent' : 'play_store_ready';

  await leadRef.set(
    {
      status: nextStatus,
      playStoreTesterIncludedAt:
        lead.playStoreTesterIncludedAt ?? admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      playStoreIncludedByUid: claims.uid,
    },
    {merge: true},
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'mark_employee_tester_play_store_included',
    entityPath: 'employee_tester_leads',
    entityId: leadId,
    before: {
      status: asTrimmedString(lead.status),
      playStoreTesterIncludedAt: timestampToIsoString(lead.playStoreTesterIncludedAt),
    },
    after: {
      status: nextStatus,
      playStoreTesterIncludedAt: 'serverTimestamp',
    },
  });

  return {
    ok: true,
    leadId,
    status: nextStatus,
  };
});

exports.platformReleaseEmployeeTesterAccess = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const leadId = asTrimmedString(data?.leadId);
  if (!leadId) {
    throw new functions.https.HttpsError('invalid-argument', 'leadId obrigatorio.');
  }

  const leadRef = employeeTesterLeadRef().doc(leadId);
  const leadSnap = await leadRef.get();
  if (!leadSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Lead de testador nao encontrado.');
  }

  const lead = asRecord(leadSnap.data());
  const email = asTrimmedString(lead.email).toLowerCase();
  const nome = asTrimmedString(lead.fullName);
  if (!email || !nome) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Lead sem nome ou email valido para liberar o acesso.',
    );
  }
  if (!lead.playStoreTesterIncludedAt && asTrimmedString(lead.status) !== 'access_sent') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Marque primeiro que o email foi incluido manualmente na lista fechada da Play Store.',
    );
  }

  await ensurePublicEmployeeTesterCompany();

  const emailCfg = obterConfigEmail();
  const senhaTemporaria = gerarSenhaTemporaria();
  let userRecord: admin.auth.UserRecord;

  try {
    userRecord = await admin.auth().createUser({
      email,
      password: senhaTemporaria,
      displayName: nome,
      emailVerified: false,
    });
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code === 'auth/email-already-exists') {
      userRecord = await admin.auth().getUserByEmail(email);
    } else {
      throw new functions.https.HttpsError('internal', 'Nao foi possivel criar o usuario do testador.');
    }
  }

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      companyId: PUBLIC_EMPLOYEE_TESTER_COMPANY_ID,
      companyName: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
      companyData: {
        nomeFantasia: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
        companyType: 'equipe',
        companyPlan: 'employee_testers',
      },
      role: 'EMPLOYEE',
      nome,
      email,
      telefone: asTrimmedString(lead.phone) || null,
      endereco:
        [asTrimmedString(lead.city), asTrimmedString(lead.state)]
          .filter((item) => !!item)
          .join(' / ') || null,
      apelido: null,
      documento: null,
      pix: null,
      employeeId: userRecord.uid,
      mustChangePassword: true,
      isPublicEmployeeTester: true,
      testerLeadId: leadId,
      testerCampaignStatus: 'released',
      testerShowcaseName: 'Conhecer o sistema real',
      realAccessReleasedAt: lead.realAccessReleasedAt ?? null,
      realAccessUrl: asTrimmedString(lead.realAccessUrl),
      realAccessLabel: asTrimmedString(lead.realAccessLabel) || 'Ir para o ambiente real',
      occupation: asTrimmedString(lead.occupation),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().updateUser(userRecord.uid, {displayName: nome});
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: PUBLIC_EMPLOYEE_TESTER_COMPANY_ID,
    role: 'EMPLOYEE',
    employeeId: userRecord.uid,
  });

  const resetLink = await admin.auth().generatePasswordResetLink(email);

  try {
    await enviarEmailBoasVindasFuncionario({
      email,
      nome,
      nomeEmpresa: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
      resetLink,
      apkUrl: emailCfg.apkUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  } catch (_) {
    throw new functions.https.HttpsError(
      'internal',
      'Tester incluido, mas falhou o envio do email de acesso.',
    );
  }

  const beforeLead = {
    status: asTrimmedString(lead.status),
    testerUid: asTrimmedString(lead.testerUid),
    inviteSentAt: timestampToIsoString(lead.inviteSentAt),
  };

  await leadRef.set(
    {
      status: 'access_sent',
      testerUid: userRecord.uid,
      testerCompanyId: PUBLIC_EMPLOYEE_TESTER_COMPANY_ID,
      testerCompanyName: PUBLIC_EMPLOYEE_TESTER_COMPANY_NAME,
      playStoreTesterIncludedAt:
        lead.playStoreTesterIncludedAt ?? admin.firestore.FieldValue.serverTimestamp(),
      playStoreReleasedAt:
        lead.playStoreReleasedAt ?? admin.firestore.FieldValue.serverTimestamp(),
      inviteSentAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      releasedByUid: claims.uid,
    },
    {merge: true},
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'release_employee_tester_access',
    entityPath: 'employee_tester_leads',
    entityId: leadId,
    before: beforeLead,
    after: {
      status: 'access_sent',
      testerUid: userRecord.uid,
      testerCompanyId: PUBLIC_EMPLOYEE_TESTER_COMPANY_ID,
    },
  });

  return {
    ok: true,
    leadId,
    testerUid: userRecord.uid,
    status: 'access_sent',
  };
});

exports.platformReleaseEmployeeTesterRealAccess = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const leadId = asTrimmedString(data?.leadId);
  const realAccessUrl = asTrimmedString(data?.realAccessUrl) || DEFAULT_REAL_ENVIRONMENT_URL;
  const realAccessLabel = asTrimmedString(data?.realAccessLabel) || 'Ir para o ambiente real';
  if (!leadId) {
    throw new functions.https.HttpsError('invalid-argument', 'leadId obrigatorio.');
  }

  const leadRef = employeeTesterLeadRef().doc(leadId);
  const leadSnap = await leadRef.get();
  if (!leadSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Lead de testador nao encontrado.');
  }

  const lead = asRecord(leadSnap.data());
  const testerUid = asTrimmedString(lead.testerUid);
  const email = asTrimmedString(lead.email).toLowerCase();
  const nome = asTrimmedString(lead.fullName);
  if (!testerUid || asTrimmedString(lead.status) !== 'access_sent') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Libere primeiro o acesso de teste antes de liberar o ambiente real.',
    );
  }

  await admin.firestore().collection('users').doc(testerUid).set(
    {
      testerCampaignStatus: 'real_released',
      testerShowcaseName: 'Conhecer o sistema real',
      realAccessReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
      realAccessUrl,
      realAccessLabel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await leadRef.set(
    {
      realAccessReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
      realAccessUrl,
      realAccessLabel,
      realAccessReleasedByUid: claims.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const emailCfg = obterConfigEmail();
  try {
    await enviarEmailMigracaoAmbienteReal({
      email,
      nome: nome || email,
      realAccessUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  } catch (_) {
    throw new functions.https.HttpsError(
      'internal',
      'Ambiente real liberado, mas falhou o envio do email de migracao.',
    );
  }

  await writeAudit({
    claims,
    module: 'platform',
    action: 'release_employee_tester_real_access',
    entityPath: 'employee_tester_leads',
    entityId: leadId,
    before: {
      realAccessReleasedAt: timestampToIsoString(lead.realAccessReleasedAt),
      realAccessUrl: asTrimmedString(lead.realAccessUrl),
    },
    after: {
      testerUid,
      realAccessUrl,
      realAccessLabel,
      realAccessReleasedAt: 'serverTimestamp',
    },
  });

  return {
    ok: true,
    leadId,
    testerUid,
    realAccessUrl,
  };
});

function maxTimestampIsoFromDocs(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  fields: string[],
): string {
  let latest: admin.firestore.Timestamp | null = null;
  for (const doc of docs) {
    const data = asRecord(doc.data());
    for (const field of fields) {
      const parsed = parseTimestampLike(data[field]);
      if (parsed && (!latest || parsed.toMillis() > latest.toMillis())) {
        latest = parsed;
      }
    }
  }
  return latest ? latest.toDate().toISOString() : '';
}

exports.platformGetEmployeeTesterUsageSummary = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const leadId = asTrimmedString(data?.leadId);
  if (!leadId) {
    throw new functions.https.HttpsError('invalid-argument', 'leadId obrigatorio.');
  }

  const leadRef = employeeTesterLeadRef().doc(leadId);
  const leadSnap = await leadRef.get();
  if (!leadSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Lead de testador nao encontrado.');
  }

  const lead = asRecord(leadSnap.data());
  const testerUid = asTrimmedString(lead.testerUid);
  if (!testerUid) {
    return {
      ok: true,
      leadId,
      hasAccess: false,
      summary: {
        fullName: asTrimmedString(lead.fullName),
        email: asTrimmedString(lead.email),
        status: asTrimmedString(lead.status),
        tasksCount: 0,
        serviceOrdersCount: 0,
        punchesCount: 0,
        justificationsCount: 0,
        paymentsCount: 0,
        debtsCount: 0,
        personalMovementsCount: 0,
        hasDeviceConsent: false,
        authCreatedAt: '',
        authLastSignInAt: '',
        lastActivityAt: '',
      },
    };
  }

  const [
    taskSnap,
    ordersSnap,
    punchSnap,
    justificationSnap,
    paymentsSnap,
    debtsSnap,
    movementsSnap,
    consentSnap,
  ] = await Promise.all([
    admin.firestore().collection('tasks').where('autorId', '==', testerUid).get(),
    admin.firestore().collection('service_orders').where('assignedEmployeeId', '==', testerUid).get(),
    admin.firestore().collection('punches').where('employeeId', '==', testerUid).get(),
    admin.firestore().collection('justifications').where('employeeId', '==', testerUid).get(),
    admin.firestore().collection('payments').where('employeeId', '==', testerUid).get(),
    admin.firestore().collection('debts').where('employeeId', '==', testerUid).get(),
    admin.firestore().collection('finance_movements').where('ownerUserId', '==', testerUid).get(),
    admin.firestore().collection('device_consents').doc(testerUid).get(),
  ]);

  let authCreatedAt = '';
  let authLastSignInAt = '';
  try {
    const authUser = await admin.auth().getUser(testerUid);
    authCreatedAt = asTrimmedString(authUser.metadata.creationTime);
    authLastSignInAt = asTrimmedString(authUser.metadata.lastSignInTime);
  } catch (_) {}

  const lastActivityCandidates = [
    maxTimestampIsoFromDocs(taskSnap.docs, ['updatedAt', 'createdAt', 'dataExecucao']),
    maxTimestampIsoFromDocs(ordersSnap.docs, ['updatedAt', 'createdAt', 'scheduledDate']),
    maxTimestampIsoFromDocs(punchSnap.docs, ['timestamp', 'createdAt']),
    maxTimestampIsoFromDocs(justificationSnap.docs, ['updatedAt', 'createdAt']),
    maxTimestampIsoFromDocs(paymentsSnap.docs, ['updatedAt', 'createdAt']),
    maxTimestampIsoFromDocs(debtsSnap.docs, ['updatedAt', 'createdAt']),
    maxTimestampIsoFromDocs(movementsSnap.docs, ['updatedAt', 'createdAt', 'date']),
    timestampToIsoString(asRecord(consentSnap.data()).acceptedAt),
    authLastSignInAt,
  ].filter((item) => !!item);

  const lastActivityAt = lastActivityCandidates.sort().reverse()[0] ?? '';

  return {
    ok: true,
    leadId,
    hasAccess: true,
    summary: {
      fullName: asTrimmedString(lead.fullName),
      email: asTrimmedString(lead.email),
      status: asTrimmedString(lead.status),
      testerUid,
      tasksCount: taskSnap.size,
      serviceOrdersCount: ordersSnap.size,
      punchesCount: punchSnap.size,
      justificationsCount: justificationSnap.size,
      paymentsCount: paymentsSnap.size,
      debtsCount: debtsSnap.size,
      personalMovementsCount: movementsSnap.size,
      hasDeviceConsent: consentSnap.exists && asRecord(consentSnap.data()).accepted == true,
      authCreatedAt,
      authLastSignInAt,
      lastActivityAt,
    },
  };
});

exports.platformGetMarketingDashboard = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const daysRaw = Number(data?.days ?? 30) || 30;
  const days = Math.min(Math.max(daysRaw, 7), 90);
  const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

  const [dailySnap, visitorsSnap, sessionsSnap, leadsSnap] = await Promise.all([
    marketingDailyCollectionRef().orderBy('dateKey', 'desc').limit(days).get(),
    marketingVisitorsRef().where('lastSeenAt', '>=', cutoffTimestamp).get(),
    marketingSessionsRef().where('lastSeenAt', '>=', cutoffTimestamp).get(),
    salesLeadRef().where('updatedAt', '>=', cutoffTimestamp).orderBy('updatedAt', 'desc').limit(25).get(),
  ]);

  const eventTotals = new Map<string, number>();
  const sourceTotals = new Map<string, number>();
  const campaignTotals = new Map<string, number>();
  const planTotals = new Map<string, number>();

  for (const doc of dailySnap.docs) {
    const data = asRecord(doc.data());
    const eventCounts = asRecord(data.eventCounts);
    const sourceCounts = asRecord(data.sourceCounts);
    const campaignCounts = asRecord(data.campaignCounts);
    const planCounts = asRecord(data.planCounts);

    for (const [key, value] of Object.entries(eventCounts)) {
      eventTotals.set(key, (eventTotals.get(key) ?? 0) + (Number(value) || 0));
    }
    for (const [key, value] of Object.entries(sourceCounts)) {
      sourceTotals.set(key, (sourceTotals.get(key) ?? 0) + (Number(value) || 0));
    }
    for (const [key, value] of Object.entries(campaignCounts)) {
      campaignTotals.set(key, (campaignTotals.get(key) ?? 0) + (Number(value) || 0));
    }
    for (const [key, value] of Object.entries(planCounts)) {
      planTotals.set(key, (planTotals.get(key) ?? 0) + (Number(value) || 0));
    }
  }

  const visitors = visitorsSnap.docs.map((doc) => asRecord(doc.data()));
  const sessions = sessionsSnap.docs.map((doc) => asRecord(doc.data()));
  const hotVisitors = visitors.filter((item) => (Number(item.score ?? 0) || 0) >= 20).length;
  const recurringVisitors = visitors.filter((item) => (Number(item.sessionCount ?? 0) || 0) >= 2).length;
  const demoVisitorsSnap = await demoPublicAccessRef()
    .where('lastSeenAt', '>=', cutoffTimestamp)
    .get();
  let demoCompanyUnique = 0;
  let demoAccountantUnique = 0;
  let demoOpenCount = 0;
  for (const doc of demoVisitorsSnap.docs) {
    const item = asRecord(doc.data());
    const roles = asRecord(item.roles);
    if (roles.company === true) demoCompanyUnique += 1;
    if (roles.accountant === true) demoAccountantUnique += 1;
    demoOpenCount += Math.max(0, Number(item.accessCount ?? 0) || 0);
  }

  const recentLeads = leadsSnap.docs.map((doc) => {
    const item = asRecord(doc.data());
    return {
      id: doc.id,
      customerName: asTrimmedString(item.customerName),
      customerEmail: asTrimmedString(item.customerEmail),
      status: asTrimmedString(item.status),
      planCode: asTrimmedString(item.planCode),
      implementationMode: asTrimmedString(item.implementationMode),
      sourceBucket: asTrimmedString(item.sourceBucket),
      utmSource: asTrimmedString(item.utmSource),
      utmCampaign: asTrimmedString(item.utmCampaign),
      updatedAt: timestampToIsoString(item.updatedAt),
    };
  });

  const sortCounts = (map: Map<string, number>) =>
    Array.from(map.entries())
      .map(([key, count]) => ({ key, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);

  const salesViews = eventTotals.get('sales_page_view') ?? 0;
  const preregViews = eventTotals.get('sales_preregistration_view') ?? 0;
  const planSelects = eventTotals.get('sales_plan_select') ?? 0;
  const preregSubmits = eventTotals.get('sales_preregistration_submit') ?? 0;
  const sessionCount = sessions.length;

  return {
    ok: true,
    days,
    metrics: {
      visitors: visitors.length,
      sessions: sessionCount,
      salesViews,
      preregViews,
      planSelects,
      preregSubmits,
      hotVisitors,
      recurringVisitors,
      demoVisitors: demoVisitorsSnap.size,
      demoCompanyUnique,
      demoAccountantUnique,
      demoOpenCount,
      preregConversionRate:
        sessionCount > 0 ? Number((preregSubmits / sessionCount).toFixed(4)) : 0,
      planSelectRate:
        sessionCount > 0 ? Number((planSelects / sessionCount).toFixed(4)) : 0,
    },
    topSources: sortCounts(sourceTotals),
    topCampaigns: sortCounts(campaignTotals),
    topPlans: sortCounts(planTotals),
    recentLeads,
  };
});

exports.publicTrackMarketingEvent = functions.https.onCall(async (data) => {
  const eventName = sanitizeMarketingKey(data?.eventName);
  const visitorId = asTrimmedString(data?.visitorId);
  const sessionId = asTrimmedString(data?.sessionId);
  const pagePath = asTrimmedString(data?.pagePath) || '/';
  const planCode = sanitizeMarketingKey(data?.planCode);
  const implementationMode = sanitizeMarketingKey(data?.implementationMode);
  const leadId = asTrimmedString(data?.leadId);
  const utmSource = sanitizeMarketingKey(data?.utmSource);
  const utmMedium = sanitizeMarketingKey(data?.utmMedium);
  const utmCampaign = sanitizeMarketingKey(data?.utmCampaign);
  const utmContent = sanitizeMarketingKey(data?.utmContent);
  const utmTerm = sanitizeMarketingKey(data?.utmTerm);
  const referrer = asTrimmedString(data?.referrer);
  const referrerHost = marketingReferrerHost(referrer);
  const language = asTrimmedString(data?.language).slice(0, 32);
  const deviceType = sanitizeMarketingKey(data?.deviceType);
  const sourceBucket = inferMarketingSourceBucket({
    utmSource,
    referrerHost,
  });

  if (!eventName || !visitorId || !sessionId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'eventName, visitorId e sessionId sao obrigatorios.',
    );
  }

  const scoreDelta = marketingEventScore(eventName);
  const dateKey = marketingDateKey();
  const eventRef = marketingEventsRef().doc();
  const visitorRef = marketingVisitorsRef().doc(visitorId);
  const sessionRef = marketingSessionsRef().doc(sessionId);
  const dailyRef = marketingDailyRef(dateKey);

  await admin.firestore().runTransaction(async (tx) => {
    const [visitorSnap, sessionSnap] = await Promise.all([
      tx.get(visitorRef),
      tx.get(sessionRef),
    ]);

    const isNewVisitor = !visitorSnap.exists;
    const isNewSession = !sessionSnap.exists;

    tx.set(
      eventRef,
      {
        eventName,
        visitorId,
        sessionId,
        pagePath,
        planCode,
        implementationMode,
        leadId,
        sourceBucket,
        utmSource,
        utmMedium,
        utmCampaign,
        utmContent,
        utmTerm,
        referrer,
        referrerHost,
        language,
        deviceType,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dateKey,
      },
      { merge: true },
    );

    tx.set(
      visitorRef,
      {
        visitorId,
        firstSeenAt: visitorSnap.exists
          ? visitorSnap.get('firstSeenAt') ?? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        firstPagePath: visitorSnap.exists ? visitorSnap.get('firstPagePath') ?? pagePath : pagePath,
        lastPagePath: pagePath,
        firstSourceBucket:
          visitorSnap.exists ? visitorSnap.get('firstSourceBucket') ?? sourceBucket : sourceBucket,
        sourceBucket,
        utmSource,
        utmMedium,
        utmCampaign,
        utmContent,
        utmTerm,
        referrerHost,
        language,
        deviceType,
        eventCount: admin.firestore.FieldValue.increment(1),
        ...(isNewSession
          ? { sessionCount: admin.firestore.FieldValue.increment(1) }
          : {}),
        ...(scoreDelta > 0
          ? { score: admin.firestore.FieldValue.increment(scoreDelta) }
          : {}),
        ...(leadId ? { lastLeadId: leadId } : {}),
      },
      { merge: true },
    );

    tx.set(
      sessionRef,
      {
        sessionId,
        visitorId,
        firstSeenAt: sessionSnap.exists
          ? sessionSnap.get('firstSeenAt') ?? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        firstPagePath: sessionSnap.exists ? sessionSnap.get('firstPagePath') ?? pagePath : pagePath,
        lastPagePath: pagePath,
        sourceBucket,
        utmSource,
        utmMedium,
        utmCampaign,
        referrerHost,
        language,
        deviceType,
        eventCount: admin.firestore.FieldValue.increment(1),
        ...(eventName === 'sales_plan_select'
          ? { planSelectCount: admin.firestore.FieldValue.increment(1) }
          : {}),
        ...(eventName === 'sales_preregistration_submit'
          ? { preregSubmitCount: admin.firestore.FieldValue.increment(1) }
          : {}),
        ...(leadId ? { leadId } : {}),
      },
      { merge: true },
    );

    tx.set(
      dailyRef,
      {
        dateKey,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        eventCounts: {
          [eventName]: admin.firestore.FieldValue.increment(1),
        },
        sourceCounts: {
          [sourceBucket]: admin.firestore.FieldValue.increment(1),
        },
        ...(utmCampaign
          ? {
              campaignCounts: {
                [utmCampaign]: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
        ...(planCode
          ? {
              planCounts: {
                [planCode]: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
        ...(isNewVisitor
          ? {
              visitorCounts: {
                total: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
        ...(isNewSession
          ? {
              sessionCounts: {
                total: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
      },
      { merge: true },
    );
  });

  return {
    ok: true,
    sourceBucket,
  };
});

exports.publicGetDemoAccessSummary = functions.https.onCall(async () => {
  const configSnap = await demoAccessConfigRef().get();
  const config = buildDefaultDemoAccessConfig(asRecord(configSnap.data()));
  const summary = await buildPublicDemoAccessSummary();
  return {
    ok: true,
    enabled: config.enabled === true,
    profile: 'summary',
    targetRoute: '/inicio',
    visitors: summary.visitors,
    companyUnique: summary.companyUnique,
    accountantUnique: summary.accountantUnique,
  };
});

exports.publicOpenDemoAccess = functions.https.onCall(async (data, context) => {
  try {
  const profile = normalizePublicDemoProfile(data?.profile);
  const configSnap = await demoAccessConfigRef().get();
  const config = buildDefaultDemoAccessConfig(asRecord(configSnap.data()));
  if (config.enabled !== true) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'O acesso demo publico esta desativado no momento.',
    );
  }

  const companyId = PUBLIC_DEMO_COMPANY_ID;

  const visitorId = asTrimmedString(data?.visitorId);
  if (!visitorId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'visitorId obrigatorio para acesso demo.',
    );
  }

  const metadata = readPublicRequestMetadata(context);
  const sessionId = asTrimmedString(data?.sessionId);
  const pagePath = asTrimmedString(data?.pagePath) || '/vendas';
  const deviceType = sanitizeMarketingKey(data?.deviceType);
  const language = asTrimmedString(data?.language).slice(0, 32);
  const screenWidth = Number(data?.screenWidth ?? 0) || 0;
  const screenHeight = Number(data?.screenHeight ?? 0) || 0;

  const uid =
    profile === 'accountant' ? PUBLIC_DEMO_ACCOUNTANT_UID : PUBLIC_DEMO_OWNER_UID;
  const role: AppRole = profile === 'accountant' ? 'ACCOUNTANT' : 'OWNER';
  const displayName =
    profile === 'accountant'
      ? asTrimmedString(config.accountantDisplayName) || PUBLIC_DEMO_OFFICE_NAME
      : asTrimmedString(config.ownerDisplayName) || PUBLIC_DEMO_COMPANY_NAME;

  await ensurePublicDemoWorkspace(companyId);
  const authUid = await ensurePublicDemoAuthUser({
    uid,
    email: `${uid}@demo.pontocerto.local`,
    displayName,
  });
  await ensurePublicDemoUser({
    uid: authUid,
    companyId,
    role,
    displayName,
    demoProfile: profile,
  });
  if (profile === 'accountant') {
    await ensurePublicDemoAccountantLink({
      accountantUid: authUid,
      companyId,
    });
    await admin.firestore().collection('users').doc(authUid).set(
      {
        officeId: PUBLIC_DEMO_OFFICE_ID,
        officeName: PUBLIC_DEMO_OFFICE_NAME,
        officeBillingChoiceDefault: 'office',
      },
      {merge: true},
    );
  }

  const dedupeDocId = buildPublicDemoAccessDedupeDocId({
    ipHash: metadata.ipHash,
    userAgent: metadata.userAgent,
    deviceType,
    language,
    screenWidth,
    screenHeight,
  });
  const accessRef = demoPublicAccessRef().doc(dedupeDocId);
  const dateKey = marketingDateKey();
  const dailyRef = marketingDailyRef(dateKey);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(accessRef);
    const current = asRecord(snap.data());
    const roles = asRecord(current.roles);
    const isNewVisitor = !snap.exists;
    const isNewRole = roles[profile] !== true;
    tx.set(
      accessRef,
      {
        visitorId,
        firstSeenAt: snap.exists
          ? current.firstSeenAt ?? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSessionId: sessionId,
        lastPagePath: pagePath,
        deviceType,
        language,
        screenWidth,
        screenHeight,
        ipHash: metadata.ipHash,
        clientVisitorId: visitorId,
        dedupeVersion: 1,
        userAgent: metadata.userAgent,
        accessCount: admin.firestore.FieldValue.increment(1),
        roles: {
          ...roles,
          [profile]: true,
        },
      },
      {merge: true},
    );
    tx.set(
      dailyRef,
      {
        dateKey,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        eventCounts: {
          [`demo_open_${profile}`]: admin.firestore.FieldValue.increment(1),
        },
        ...(isNewVisitor
          ? {
              demoCounts: {
                uniqueVisitors: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
        ...(isNewRole
          ? {
              demoCounts: {
                [`unique_${profile}`]: admin.firestore.FieldValue.increment(1),
              },
            }
          : {}),
      },
      {merge: true},
    );
  });

  const customToken = await admin.auth().createCustomToken(authUid, {
    companyId,
    role,
    employeeId: authUid,
    demoReadOnly: true,
    demoProfile: profile,
  });
  const summary = await buildPublicDemoAccessSummary();
  return {
    ok: true,
    profile,
    customToken,
    targetRoute: profile === 'accountant' ? '/accountant-companies' : '/home',
    visitors: summary.visitors,
    companyUnique: summary.companyUnique,
    accountantUnique: summary.accountantUnique,
  };
  } catch (error: unknown) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const msg = errorMessage(error, 'unknown');
    functions.logger.error('publicOpenDemoAccess error', {
      message: msg,
      stack: error instanceof Error ? error.stack : undefined,
    });
    if (isLikelyFirebaseAdminIamSigningError(error)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'O demo precisa de permissao IAM no Google Cloud: na conta de servico que executa as Cloud Functions, ' +
          'conceda o papel "Token Creator de Conta de Servico" (roles/iam.serviceAccountTokenCreator) ' +
          'sobre a conta firebase-adminsdk do projeto (veja firebase.google.com/docs/auth/admin/create-custom-tokens).',
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      `Demo indisponivel no momento: ${msg}`,
    );
  }
});

exports.platformGetDemoAccessConfig = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const snap = await demoAccessConfigRef().get();
  const config = buildDefaultDemoAccessConfig(asRecord(snap.data()));
  return {
    ok: true,
    config,
  };
});

exports.platformUpdateDemoAccessConfig = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const beforeSnap = await demoAccessConfigRef().get();
  const beforeConfig = buildDefaultDemoAccessConfig(asRecord(beforeSnap.data()));
  const d = asRecord(data);
  const nested = d.config;
  const clientConfig =
    nested != null && typeof nested === 'object' && !Array.isArray(nested)
      ? asRecord(nested)
      : d;
  const nextConfig = buildDefaultDemoAccessConfig(clientConfig);

  await demoAccessConfigRef().set(
    {
      ...nextConfig,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByPlatformUid: claims.uid,
    },
    {merge: true},
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'update_demo_access_config',
    entityPath: 'platform_public',
    entityId: 'demo_access',
    before: beforeConfig,
    after: nextConfig,
  });

  return {
    ok: true,
    config: nextConfig,
  };
});

exports.platformGetPublicSalesConfig = functions.https.onCall(async () => {
  const snap = await publicSalesConfigRef().get();
  const config = buildDefaultPublicSalesConfig(asRecord(snap.data()));
  return {
    ok: true,
    config: {
      ...config,
      updatedAt: timestampToIsoString(config.updatedAt),
    },
  };
});

exports.accountantGetPartnerContact = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['ACCOUNTANT', 'OWNER']);

  const snap = await admin
    .firestore()
    .collection('company_settings')
    .where('commercialSettings.plan', '==', 'supreme')
    .limit(1)
    .get();

  if (snap.empty) {
    throw new functions.https.HttpsError(
      'not-found',
      'Cadastro da empresa suprema nao encontrado.',
    );
  }

  const item = asRecord(snap.docs[0].data());
  const companyData = asRecord(item.companyData);

  return {
    ok: true,
    companyId: asTrimmedString(item.companyId) || snap.docs[0].id,
    companyName:
      asTrimmedString(companyData.nomeFantasia) ||
      asTrimmedString(companyData.razaoSocial),
    legalName: asTrimmedString(companyData.razaoSocial),
    email: asTrimmedString(companyData.email),
    phone: asTrimmedString(companyData.telefone),
    city: asTrimmedString(companyData.cidade),
    state: asTrimmedString(companyData.estado),
  };
});

exports.platformUpdatePublicSalesConfig = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const beforeSnap = await publicSalesConfigRef().get();
  const beforeData = asRecord(beforeSnap.data());
  const beforeConfig = buildDefaultPublicSalesConfig(beforeData);
  const d = asRecord(data);
  // Callable pode trazer { config: { ... } } ou, em runtimes/versões, o plano no topo.
  const nested = d.config;
  const clientConfig =
    nested != null && typeof nested === 'object' && !Array.isArray(nested)
      ? asRecord(nested)
      : d;
  const payload = buildDefaultPublicSalesConfig(clientConfig);
  const fromClient = asTrimmedString(clientConfig.metaPixelHeadSnippet);
  const fromPayload = asTrimmedString((payload as Record<string, unknown>).metaPixelHeadSnippet);
  const rawSnippet = fromClient.length > 0 ? fromClient : fromPayload;
  if (rawSnippet.length > 65535) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Codigo do Meta Pixel: no maximo 65535 caracteres.',
    );
  }
  const finalPayload = {
    ...payload,
    metaPixelHeadSnippet: rawSnippet,
  };
  const nextConfig = {
    ...finalPayload,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedByPlatformUid: claims.uid,
  };

  await publicSalesConfigRef().set(nextConfig, { merge: true });

  await writeAudit({
    claims,
    module: 'platform',
    action: 'update_public_sales_config',
    entityPath: 'platform_public',
    entityId: 'sales_page',
    before: beforeConfig,
    after: finalPayload,
  });

  return {
    ok: true,
    config: finalPayload,
  };
});

exports.publicGetSalesOnboardingRequest = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token obrigatorio.');
  }

  const tokenHash = hashPublicToken(token);
  const snap = await salesOnboardingRef()
    .where('onboardingTokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Cadastro de onboarding nao encontrado.');
  }

  const item = asRecord(snap.docs[0].data());
  return {
    ok: true,
    requestId: snap.docs[0].id,
    status: asTrimmedString(item.status),
    customerName: asTrimmedString(item.customerName),
    customerEmail: asTrimmedString(item.customerEmail),
    originalBuyerName: asTrimmedString(item.originalBuyerName),
    originalBuyerEmail: asTrimmedString(item.originalBuyerEmail),
    planCode: asTrimmedString(item.planCode),
    planTitle: asTrimmedString(item.planTitle),
    planPriceLabel: asTrimmedString(item.planPriceLabel),
    implementationLabel: asTrimmedString(item.implementationLabel),
    implementationMode: asTrimmedString(item.implementationMode),
    accountantName: asTrimmedString(item.accountantName),
    accountantEmail: asTrimmedString(item.accountantEmail),
  };
});

exports.publicCreateSalesPreRegistration = functions.https.onCall(async (data) => {
  const publicConfigSnap = await publicSalesConfigRef().get();
  const publicConfig = buildDefaultPublicSalesConfig(asRecord(publicConfigSnap.data()));
  const planCode = asTrimmedString(data?.planCode).toLowerCase();
  const plan =
    publicSalesPlanEntries(publicConfig).find(
      (item) => asTrimmedString(item.code).toLowerCase() == planCode,
    ) ?? {};
  if (Object.keys(plan).length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Plano publico invalido.');
  }

  const customerName = asTrimmedString(data?.customerName);
  const customerEmail = asTrimmedString(data?.customerEmail).toLowerCase();
  const implementationMode = asTrimmedString(data?.implementationMode) || 'accountant';
  const accountantNameRaw = asTrimmedString(data?.accountantName);
  const accountantEmailRaw = asTrimmedString(data?.accountantEmail).toLowerCase();
  const accountantName =
    implementationMode === 'accountant' ? (accountantNameRaw || customerName) : accountantNameRaw;
  const accountantEmail =
    implementationMode === 'accountant' ? (accountantEmailRaw || customerEmail) : accountantEmailRaw;
  const tracking = asRecord(data?.tracking);
  const visitorId = asTrimmedString(tracking.visitorId);
  const sessionId = asTrimmedString(tracking.sessionId);
  const utmSource = sanitizeMarketingKey(tracking.utmSource);
  const utmMedium = sanitizeMarketingKey(tracking.utmMedium);
  const utmCampaign = sanitizeMarketingKey(tracking.utmCampaign);
  const utmContent = sanitizeMarketingKey(tracking.utmContent);
  const utmTerm = sanitizeMarketingKey(tracking.utmTerm);
  const referrerHost = marketingReferrerHost(tracking.referrerHost || tracking.referrer);
  const sourceBucket = inferMarketingSourceBucket({
    utmSource,
    referrerHost,
  });

  if (!customerName || !customerEmail) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email da empresa para continuar.',
    );
  }
  if (
    implementationMode == 'accountant' &&
    (!accountantName || !accountantEmail)
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email do contador para esse fluxo.',
    );
  }

  const matchedLead = await findSalesLeadDocByCustomerEmailAndPlan(
    customerEmail,
    asTrimmedString(plan.code),
  );
  const leadRef = matchedLead ? matchedLead.ref : salesLeadRef().doc();
  const preservedLeadCreatedAt = matchedLead
    ? (matchedLead.data().createdAt as FirebaseFirestore.Timestamp | undefined)
    : undefined;
  const partnerInviteToken = implementationMode == 'accountant' ? generatePublicToken() : '';
  const partnerInviteTokenHash = partnerInviteToken === ''
    ? ''
    : hashPublicToken(partnerInviteToken);
  const partnerInviteUrl = partnerInviteToken === ''
    ? ''
    : `https://gestao-ponto-certo.com/convite-contador?token=${encodeURIComponent(partnerInviteToken)}`;
  const checkoutUrl = asTrimmedString(plan.checkoutUrl);

  await leadRef.set(
    {
      status: 'pre_registered',
      customerName,
      customerEmail,
      planCode: asTrimmedString(plan.code),
      planTitle: asTrimmedString(plan.title),
      checkoutUrl,
      implementationMode,
      accountantName,
      accountantEmail,
      accountantInviteTokenHash: partnerInviteTokenHash,
      accountantInviteUrl: partnerInviteUrl,
      planPriceLabel: asTrimmedString(plan.priceLabel),
      implementationLabel: asTrimmedString(plan.implantationLabel),
      visitorId,
      sessionId,
      sourceBucket,
      utmSource,
      utmMedium,
      utmCampaign,
      utmContent,
      utmTerm,
      referrerHost,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: preservedLeadCreatedAt ?? admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const emailCfg = obterConfigEmail();
  let precadastroEmpresaEmailOk = false;
  let conviteParceiroEmailOk = false;
  try {
    await enviarEmailPreCadastroPlano({
      email: customerEmail,
      nome: customerName,
      planTitle: asTrimmedString(plan.title),
      checkoutUrl,
      implementationMode,
      implementationLabel: asTrimmedString(plan.implantationLabel),
      partnerInviteUrl: partnerInviteUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
    precadastroEmpresaEmailOk = true;
  } catch (error) {
    functions.logger.warn('Falha ao enviar email de pre-cadastro para a empresa', {
      leadId: leadRef.id,
      customerEmail,
      missing: missingInviteConfig(emailCfg),
      error: errorMessage(error, 'unknown'),
    });
  }
  if (implementationMode === 'accountant') {
    try {
      await enviarEmailConviteContadorParceiro({
        email: accountantEmail,
        accountantName,
        customerName,
        customerEmail,
        planTitle: asTrimmedString(plan.title),
        checkoutUrl,
        inviteUrl: partnerInviteUrl,
        fromEmail: emailCfg.fromEmail,
        sendgridKey: emailCfg.sendgridKey,
        smtpUser: emailCfg.smtpUser,
        smtpAppPassword: emailCfg.smtpAppPassword,
      });
      conviteParceiroEmailOk = true;
    } catch (error) {
      functions.logger.warn('Falha ao enviar email de convite ao parceiro contabil', {
        leadId: leadRef.id,
        accountantEmail,
        missing: missingInviteConfig(emailCfg),
        error: errorMessage(error, 'unknown'),
      });
    }
  }

  try {
    await provisionLightweightOfficeAccess({
      officeName: accountantName || 'Escritorio em configuracao',
      responsibleName: accountantName || 'Contador',
      email: accountantEmail,
      source: 'sales_preregistration',
    });
  } catch (error) {
    functions.logger.warn('Falha ao provisionar acesso leve do escritorio no pre-cadastro', {
      leadId: leadRef.id,
      email: accountantEmail,
      error: errorMessage(error, 'unknown'),
    });
  }

  try {
    await provisionLightweightCompanyAccess({
      ownerEmail: customerEmail,
      ownerName: customerName,
      companyName: customerName,
      source: 'sales_preregistration',
    });
  } catch (error) {
    functions.logger.warn('Falha ao provisionar acesso leve da empresa no pre-cadastro', {
      leadId: leadRef.id,
      email: customerEmail,
      error: errorMessage(error, 'unknown'),
    });
  }

  await notificarNovoCadastroAdministrativo({
    signupType: 'company_preregistration',
    companyName: customerName,
    responsibleName: customerName,
    responsibleEmail: customerEmail,
    accountantName,
    accountantEmail,
  });

  return {
    ok: true,
    leadId: leadRef.id,
    checkoutUrl,
    partnerInviteUrl,
    precadastroEmpresaEmailOk,
    conviteParceiroEmailOk,
  };
});

exports.publicGetAccountantPartnerInvite = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token obrigatorio.');
  }
  const tokenHash = hashPublicToken(token);
  const snap = await salesLeadRef()
    .where('accountantInviteTokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Convite do contador nao encontrado.');
  }
  const item = asRecord(snap.docs[0].data());
  return {
    ok: true,
    leadId: snap.docs[0].id,
    status: asTrimmedString(item.status),
    customerName: asTrimmedString(item.customerName),
    customerEmail: asTrimmedString(item.customerEmail),
    accountantName: asTrimmedString(item.accountantName),
    accountantEmail: asTrimmedString(item.accountantEmail),
    planTitle: asTrimmedString(item.planTitle),
    implementationMode: asTrimmedString(item.implementationMode),
    partnerStatus: asTrimmedString(item.accountantPartnerStatus),
  };
});

exports.publicAcceptAccountantPartnerInvite = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token obrigatorio.');
  }
  const tokenHash = hashPublicToken(token);
  const snap = await salesLeadRef()
    .where('accountantInviteTokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Convite do contador nao encontrado.');
  }
  const leadRef = snap.docs[0].ref;
  const item = asRecord(snap.docs[0].data());
  await leadRef.set(
    {
      accountantPartnerStatus: 'accepted',
      accountantPartnerAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {
    ok: true,
    leadId: leadRef.id,
    status: asTrimmedString(item.status),
    partnerStatus: 'accepted',
    customerName: asTrimmedString(item.customerName),
    customerEmail: asTrimmedString(item.customerEmail),
    accountantName: asTrimmedString(item.accountantName),
    accountantEmail: asTrimmedString(item.accountantEmail),
    planTitle: asTrimmedString(item.planTitle),
  };
});

exports.platformIssueTrial90DayInvite = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertSupremePlatformAccess(claims);
  const issuerProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  const issuerName = asTrimmedString(issuerProfile.nome) || asTrimmedString(issuerProfile.name);

  const companyEmailRaw = asTrimmedString(data?.companyEmail).toLowerCase();
  const accountantEmail = asTrimmedString(data?.accountantEmail).toLowerCase();
  const companyName = asTrimmedString(data?.companyName);
  const accountantName = asTrimmedString(data?.accountantName);
  const notes = asTrimmedString(data?.notes);
  const companyCnpjDigits = onlyDigits(data?.companyCnpj);
  const companyOpenedAtLabel = asTrimmedString(data?.companyOpenedAt);

  if (!accountantEmail || !accountantEmail.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'Informe o email do contador.');
  }
  const companyEmail =
    companyEmailRaw && companyEmailRaw.includes('@') ? companyEmailRaw : '';

  const token = generatePublicToken();
  const tokenHash = hashPublicToken(token);
  const now = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now + 30 * 24 * 60 * 60 * 1000,
  );
  const inviteUrlCompany = `https://gestao-ponto-certo.com/cadastro-empresa?trialToken=${encodeURIComponent(
    token,
  )}`;
  const inviteUrlAccountant = `https://gestao-ponto-certo.com/cadastro-empresa-contador?trialToken=${encodeURIComponent(
    token,
  )}`;
  const playStoreUrl = obterConfigEmail().apkUrl || DEFAULT_PLAY_STORE_URL;

  const existing = await trialInviteRef()
    .where('tokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (!existing.empty) {
    throw new functions.https.HttpsError('internal', 'Falha ao emitir convite (token duplicado).');
  }

  const ref = trialInviteRef().doc();
  const invite: TrialInvite = {
    companyEmail,
    accountantEmail,
    tokenHash,
    tokenIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
    tokenExpiresAt: expiresAt,
    status: 'issued',
    usedAt: null,
    usedCompanyId: '',
    issuedByUid: claims.uid,
    issuedByName: issuerName,
    notes,
    ...(companyName ? {companyName} : {}),
    ...(companyCnpjDigits.length === 14 ? {companyCnpj: companyCnpjDigits} : {}),
    ...(companyOpenedAtLabel ? {companyOpenedAt: companyOpenedAtLabel} : {}),
    ...(accountantName ? {accountantName} : {}),
  };
  await ref.set(invite, {merge: true});

  const cnpjFormattedForEmail =
    companyCnpjDigits.length === 14 ? formatBrazilCnpjForDisplay(companyCnpjDigits) : '';

  const emailCfg = obterConfigEmail();
  const missingEmailCfg = missingInviteConfig(emailCfg);
  if (missingEmailCfg.length) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Envio de convite indisponivel: configuracao de email incompleta (${missingEmailCfg.join(
        ', ',
      )}).`,
    );
  }
  const emailHtmlContador = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #1f2937; line-height: 1.55; max-width: 640px;">
      <p style="margin: 0 0 16px 0; font-size: 16px;">Olá${accountantName ? `, ${escapeHtml(accountantName)}` : ''}.</p>
      <p style="margin: 0 0 14px 0;">
        Meu nome é <strong>${escapeHtml(
          OFFICE_FOUNDER_DISPLAY_NAME,
        )}</strong>, sou fundador do <strong>Ponto Certo</strong> e também empresário na área de obras e serviços elétricos.
      </p>
      <p style="margin: 0 0 10px 0;">Criei o sistema porque vivi na prática o que você provavelmente enfrenta todos os dias:</p>
      <ul style="margin: 0 0 16px 0; padding-left: 22px;">
        <li style="margin-bottom: 6px;">Informações espalhadas no WhatsApp</li>
        <li style="margin-bottom: 6px;">Cliente que esquece de enviar dados</li>
        <li style="margin-bottom: 6px;">Retrabalho para organizar financeiro e documentos</li>
        <li style="margin-bottom: 6px;">Dificuldade na emissão de notas no prazo</li>
        <li style="margin-bottom: 6px;">Falta de padrão no envio das informações</li>
      </ul>
      <p style="margin: 0 0 18px 0;">
        No fim, quem paga o preço é o escritório — com mais trabalho, mais risco e menos previsibilidade.
      </p>
      <p style="margin: 0 0 10px 0;"><strong>O Ponto Certo resolve isso de forma simples:</strong></p>
      <p style="margin: 0 0 6px 0;">👉 A empresa usa sem dificuldade</p>
      <p style="margin: 0 0 6px 0;">👉 O contador controla tudo por trás</p>
      <p style="margin: 0 0 16px 0;">👉 Tudo fica organizado em um único ambiente</p>
      <p style="margin: 0 0 20px 0;">
        Financeiro, serviços, notas fiscais e rotinas fiscais centralizados — sem depender de mensagens soltas.
      </p>
      ${trialInviteTransparencySectionHtml({
        companyName,
        companyEmail,
        cnpjFormatted: cnpjFormattedForEmail,
        openedAtLabel: companyOpenedAtLabel,
      })}
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin: 0 0 16px 0;">
        Esse projeto nasceu da operação real — não é teoria.
      </p>
      <p style="margin: 0 0 14px 0;">
        Se fizer sentido para você, estou liberando um <strong>teste gratuito de 30 dias</strong> para o escritório usar junto com seus clientes.
      </p>
      <p style="margin: 0 0 8px 0;"><strong>Como funciona:</strong></p>
      <ol style="margin: 0 0 18px 0; padding-left: 22px;">
        <li style="margin-bottom: 8px;">Acesse o link e faça o cadastro inicial (empresa + contador)</li>
        <li style="margin-bottom: 8px;">O sistema envia o acesso automaticamente para o contador</li>
        <li>Vocês já começam a usar no mesmo ambiente, sem custo por 30 dias</li>
      </ol>
      <p style="margin: 0 0 6px 0;"><strong>👉 Acesse aqui:</strong></p>
      <p style="margin: 0 0 18px 0;">
        <a href="${inviteUrlAccountant}" style="font-weight: bold; color: #2563eb;">${inviteUrlAccountant}</a>
      </p>
      <p style="margin: 0 0 16px 0;">
        Se sua rotina hoje depende de mensagem, planilha e cobrança manual de cliente, você vai sentir a diferença já na primeira semana.
      </p>
      <p style="margin: 0 0 12px 0; font-size: 14px;">
        <strong>App na Play Store:</strong><br/>
        <a href="${playStoreUrl}" style="color: #2563eb;">${playStoreUrl}</a>
      </p>
      <p style="margin: 0 0 20px 0; padding: 14px 16px; background: #f9fafb; border-radius: 8px; border: 1px solid #e5e7eb; font-size: 14px; color: #374151;">
        <strong>Após o teste:</strong> escritorio <strong>R$ 97,90/mês</strong> ou isento em parceria aprovada; empresa <strong>R$ 97,90/mês</strong> pelo sistema; usuário adicional no app <strong>R$ 19,90/mês</strong>.
      </p>
      ${officeFounderFormalClosingInviteHtml()}
    </div>
  `;

  try {
    await Promise.all([
      enviarEmailHtml({
        toEmail: accountantEmail,
        subject: 'Menos retrabalho, mais controle entre empresa e contador',
        html: emailHtmlContador,
        fromEmail: emailCfg.fromEmail,
        sendgridKey: emailCfg.sendgridKey,
        smtpUser: emailCfg.smtpUser,
        smtpAppPassword: emailCfg.smtpAppPassword,
      }),
    ]);
  } catch (err: any) {
    const message = asTrimmedString(err?.message) || 'Falha ao enviar emails do convite.';
    const name = asTrimmedString(err?.name);
    const code = asTrimmedString(err?.code);
    throw new functions.https.HttpsError('internal', message, {
      name,
      code,
    });
  }

  await writeAudit({
    claims,
    module: 'platform',
    action: 'issue_trial_90d_invite',
    entityPath: 'trial_invites',
    entityId: ref.id,
    before: {},
    after: {
      companyEmail,
      accountantEmail,
      companyName: companyName || '',
      companyCnpj: companyCnpjDigits.length === 14 ? companyCnpjDigits : '',
      companyOpenedAt: companyOpenedAtLabel,
      tokenIssuedAt: 'serverTimestamp',
      tokenExpiresAt: expiresAt.toDate().toISOString(),
      inviteUrlCompany,
      inviteUrlAccountant,
    },
  });

  return {
    ok: true,
    inviteId: ref.id,
    companyEmail,
    accountantEmail,
    inviteUrl: inviteUrlAccountant,
    inviteUrlCompany,
    inviteUrlAccountant,
    tokenPreview: token.slice(0, 6),
    expiresAtIso: expiresAt.toDate().toISOString(),
  };
});

exports.platformTrial90DayFollowup = functions.pubsub
  .schedule('every day 06:05')
  .timeZone('America/Sao_Paulo')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredSnap = await admin
      .firestore()
      .collection('company_settings')
      .where('commercialSettings.lifecycleStatus', '==', 'trial')
      .where('commercialSettings.allowLogin', '==', true)
      .where('commercialSettings.billingIntegration.graceUntil', '<', now)
      .limit(50)
      .get();

    if (expiredSnap.empty) return null;

    const emailCfg = obterConfigEmail();
    const tasks: Promise<unknown>[] = [];

    for (const doc of expiredSnap.docs) {
      const settings = asRecord(doc.data());
      const companyId = asTrimmedString(settings.companyId) || doc.id;
      const companyData = asRecord(settings.companyData);
      const tradeName = asTrimmedString(companyData.nomeFantasia) || asTrimmedString(companyData.razaoSocial);
      const companyEmail = asTrimmedString(companyData.email).toLowerCase();
      const commercial = asRecord(settings.commercialSettings);
      if (commercial.trialFollowupSentAt) {
        continue;
      }

      const ownerSnap = await admin
        .firestore()
        .collection('users')
        .where('companyId', '==', companyId)
        .where('role', '==', 'OWNER')
        .limit(1)
        .get();
      const owner = ownerSnap.empty ? {} : asRecord(ownerSnap.docs[0].data());
      const ownerEmail = asTrimmedString(owner.email).toLowerCase();
      const ownerName = asTrimmedString(owner.nome) || 'Responsavel';

      const recipients = Array.from(
        new Set([companyEmail, ownerEmail].filter((e) => e && e.includes('@'))),
      );
      const html = `
        <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
          <h2 style="margin: 0 0 12px 0;">Ponto Certo: periodo de teste encerrado</h2>
          <p style="margin: 0 0 10px 0;">Ola, ${escapeHtml(ownerName)}.</p>
          <p style="margin: 0 0 10px 0;">
            O teste gratuito de <strong>30 dias</strong> de <strong>${escapeHtml(tradeName || 'sua empresa')}</strong> foi concluido.
          </p>
          <p style="margin: 0 0 10px 0;">
            Para <strong>manter o acesso ativo</strong>, a empresa pode aderir ao <strong>modelo pre-pago</strong> diretamente no sistema.
          </p>
          <p style="margin: 0 0 10px 0;">
            Na adesao, emitimos <strong>boleto com vencimento em 5 dias</strong>. Apos a compensacao, o acesso e restabelecido automaticamente.
          </p>
          ${officeFounderOperatingCompanyCredibilityHtml()}
          <p style="margin: 14px 0 0 0;">${officeFounderEmailSignOffInnerHtml()}</p>
        </div>
      `;

      for (const toEmail of recipients) {
        tasks.push(
          enviarEmailHtml({
            toEmail,
            subject: 'Ponto Certo: teste de 30 dias encerrado - proximo passo',
            html,
            fromEmail: emailCfg.fromEmail,
            sendgridKey: emailCfg.sendgridKey,
            smtpUser: emailCfg.smtpUser,
            smtpAppPassword: emailCfg.smtpAppPassword,
          }),
        );
      }

      tasks.push(
        doc.ref.set(
          {
            commercialSettings: {
              allowLogin: false,
              billingStatus: 'trial_expired',
              trialFollowupSentAt: admin.firestore.FieldValue.serverTimestamp(),
              platformNote: 'Trial 30 dias expirado: aviso enviado e acesso bloqueado ate adesao pre-paga.',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        ),
      );
    }

    await Promise.all(tasks);
    return null;
  });

exports.companyStartPrepaidPlanFromTrial = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const commercial = buildDefaultCommercialSettings(settingsData);
  const currentBilling = asRecord(commercial.billingIntegration);
  const companyData = asRecord(settingsData.companyData);
  const owner = await carregarOwnerDaEmpresa(claims.companyId);

  if (!settingsSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Configuracao da empresa nao encontrada.');
  }

  const billingStatus = asTrimmedString(commercial.billingStatus).toLowerCase();
  if (!['trialing', 'trial_expired'].includes(billingStatus)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A adesao pre-paga so pode ser iniciada para empresas em trial ou com trial encerrado.',
    );
  }

  const existingProvider = asTrimmedString(currentBilling.provider).toLowerCase();
  const existingSubscriptionId = asTrimmedString(currentBilling.subscriptionId);
  const existingPaymentLinkUrl =
    asTrimmedString(currentBilling.paymentLinkUrl) ||
    asTrimmedString(currentBilling.checkoutUrl);
  const existingStatus = asTrimmedString(currentBilling.status).toLowerCase();
  const existingDueDate =
    timestampToIsoString(currentBilling.currentPeriodEnd) ||
    timestampToIsoString(currentBilling.dueDate) ||
    asTrimmedString(currentBilling.dueDate);
  if (
    existingProvider === 'asaas' &&
    existingSubscriptionId &&
    existingPaymentLinkUrl &&
    ['pending', 'pending_payment', 'confirmed', 'received'].includes(existingStatus)
  ) {
    return {
      ok: true,
      companyId: claims.companyId,
      paymentLinkUrl: existingPaymentLinkUrl,
      dueDate: existingDueDate,
      monthlyPriceCents: Number(commercial.monthlyPriceCents ?? 0) || 0,
      planTitle: asTrimmedString(commercial.plan) || 'Plano',
      reusedExistingCharge: true,
    };
  }

  const plan = await resolveTrialConversionPlan({settingsData});
  if (plan.monthlyPriceCents <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Nao foi possivel calcular o valor do plano para conversao do trial.',
    );
  }

  const provisioned = await provisionDirectSignupBilling({
    companyId: claims.companyId,
    owner,
    companyData,
    planCode: plan.planCode,
    monthlyPriceCents: plan.monthlyPriceCents,
    description: `Conversao pre-paga do trial | ${claims.companyId}`,
  });

  const nextDueDate = admin.firestore.Timestamp.fromDate(
    new Date(`${provisioned.nextDueDate}T12:00:00.000Z`),
  );
  const nextCommercial = {
    ...commercial,
    plan: plan.planCode,
    lifecycleStatus: 'awaiting_payment',
    billingStatus: 'pending_payment',
    allowLogin: false,
    activationRequired: false,
    activationStatus: 'pending_payment',
    baseSystemPriceCents: plan.monthlyPriceCents,
    monthlyPriceCents: plan.monthlyPriceCents,
    pricingModel: 'prepaid_after_trial',
    platformNote:
      'Trial convertido para adesao pre-paga. Boleto inicial emitido com vencimento em 5 dias.',
    billingIntegration: {
      ...currentBilling,
      provider: 'asaas',
      accessManagedByGateway: true,
      billingType: 'BOLETO',
      cycle: 'MONTHLY',
      customerId: provisioned.customerId,
      subscriptionId: provisioned.subscriptionId,
      paymentLinkUrl: provisioned.paymentLinkUrl,
      checkoutUrl: provisioned.paymentLinkUrl,
      externalReference: claims.companyId,
      status: provisioned.status,
      graceDays: 5,
      graceUntil: null,
      currentPeriodEnd: nextDueDate,
      webhookReady: true,
      blockReason: 'Aguardando pagamento do boleto pre-pago de adesao.',
    },
  };

  await settingsRef.set(
    {
      companyId: claims.companyId,
      commercialSettings: nextCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  const ownerEmail = asTrimmedString(owner.email).toLowerCase();
  if (ownerEmail) {
    const emailCfg = obterConfigEmail();
    const companyName =
      asTrimmedString(companyData.nomeFantasia) || asTrimmedString(companyData.razaoSocial);
    await enviarEmailHtml({
      toEmail: ownerEmail,
      subject: `Ponto Certo: boleto de adesao - ${companyName || 'sua empresa'}`,
      html: `
        <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
          <h2 style="margin: 0 0 12px 0;">Ponto Certo: boleto de adesao disponivel</h2>
          <p style="margin: 0 0 10px 0;">Ola, ${escapeHtml(asTrimmedString(owner.nome) || 'responsavel')}.</p>
          <p style="margin: 0 0 10px 0;">
            O boleto da adesao pre-paga da empresa <strong>${escapeHtml(companyName || claims.companyId)}</strong> esta pronto.
          </p>
          <p style="margin: 0 0 10px 0;">
            <strong>Valor:</strong> ${formatCurrencyBr(plan.monthlyPriceCents)}<br/>
            <strong>Vencimento:</strong> ${escapeHtml(provisioned.nextDueDate)}
          </p>
          <p style="margin: 0 0 10px 0;">
            <a href="${provisioned.paymentLinkUrl}" style="font-weight:bold;">Abrir boleto / pagamento</a><br/>
            <span style="font-size:13px;color:#4b5563;">${provisioned.paymentLinkUrl}</span>
          </p>
          <p style="margin: 0 0 0 0; font-size: 14px; color: #374151;">Apos a confirmacao, seu acesso ao Ponto Certo e restabelecido.</p>
          ${officeFounderOperatingCompanyCredibilityHtml()}
          <p style="margin: 16px 0 0 0;">${officeFounderEmailSignOffInnerHtml()}</p>
        </div>
      `,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  }

  await writeAudit({
    claims,
    module: 'billing',
    action: 'company_start_prepaid_plan_from_trial',
    entityPath: 'company_settings',
    entityId: claims.companyId,
    before: {commercialSettings: commercial},
    after: {
      commercialSettings: nextCommercial,
      paymentLinkUrl: provisioned.paymentLinkUrl,
      nextDueDate: provisioned.nextDueDate,
      monthlyPriceCents: plan.monthlyPriceCents,
    },
  });

  return {
    ok: true,
    companyId: claims.companyId,
    paymentLinkUrl: provisioned.paymentLinkUrl,
    dueDate: provisioned.nextDueDate,
    monthlyPriceCents: plan.monthlyPriceCents,
    planTitle: plan.planTitle,
    reusedExistingCharge: false,
  };
});

exports.publicRequestPasswordResetEmail = functions.https.onCall(async (data) => {
  const email = asTrimmedString(data?.email).toLowerCase();
  if (!email || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'Informe um email valido.');
  }

  const emailCfg = obterConfigEmail();
  const missingEmailCfg = missingInviteConfig(emailCfg);
  if (missingEmailCfg.length) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Envio de email indisponivel: configuracao incompleta (${missingEmailCfg.join(', ')}).`,
    );
  }

  try {
    const resetLink = await admin.auth().generatePasswordResetLink(email);
    const playStoreUrl = emailCfg.apkUrl || DEFAULT_PLAY_STORE_URL;
    const html = `
      <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
        <h2 style="margin: 0 0 12px 0;">Redefinir senha - Ponto Certo</h2>
        <p style="margin: 0 0 10px 0;">
          Recebemos um pedido para criar uma <strong>nova senha</strong> para sua conta.
        </p>
        <p style="margin: 0 0 10px 0;">
          <a href="${resetLink}" style="font-weight:bold;">Definir nova senha</a>
        </p>
        <p style="margin: 0 0 10px 0;">
          Se voce nao fez este pedido, ignore este e-mail — sua senha atual permanece a mesma.
        </p>
        <p style="margin: 0 0 10px 0;">
          <strong>Aplicativo:</strong><br/>
          <a href="${playStoreUrl}">${playStoreUrl}</a>
        </p>
        ${officeFounderOperatingCompanyCredibilityHtml()}
        <p style="margin: 14px 0 0 0;">${officeFounderEmailSignOffInnerHtml()}</p>
      </div>
    `;

    await enviarEmailHtml({
      toEmail: email,
      subject: 'Ponto Certo: redefinicao de senha',
      html,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  } catch (err: any) {
    const code = asTrimmedString(err?.code);
    if (code === 'auth/user-not-found') {
      return { ok: true };
    }
    const message = asTrimmedString(err?.message) || 'Nao foi possivel enviar o email de recuperacao.';
    throw new functions.https.HttpsError('internal', message);
  }

  return { ok: true };
});

exports.publicGetAccountingOfficeSignupPrefill = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  if (!token) {
    return {
      inviterName: '',
      inviterEmail: '',
      officeName: '',
      email: '',
      phone: '',
      accepted: false,
      expired: false,
    };
  }

  const tokenHash = hashPublicToken(token);
  const accSnap = await accountingOfficeInviteRef()
    .where('tokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (!accSnap.empty) {
    const item = asRecord(accSnap.docs[0].data());
    const expiresAt = item.tokenExpiresAt;
    const expired =
      expiresAt instanceof admin.firestore.Timestamp
        ? expiresAt.toMillis() < Date.now()
        : false;

    return {
      inviterName: asTrimmedString(item.inviterName),
      inviterEmail: asTrimmedString(item.inviterEmail),
      officeName: asTrimmedString(item.officeName),
      email: asTrimmedString(item.email),
      phone: asTrimmedString(item.phone),
      accepted: asTrimmedString(item.status) === 'accepted',
      expired,
    };
  }

  const trialSnap = await trialInviteRef()
    .where('tokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (trialSnap.empty) {
    throw new functions.https.HttpsError(
      'not-found',
      'Convite de escritorio nao encontrado ou invalido.',
    );
  }
  const t = asRecord(trialSnap.docs[0].data());
  const tExpires = t.tokenExpiresAt;
  const tExpired =
    tExpires instanceof admin.firestore.Timestamp
      ? tExpires.toMillis() < Date.now()
      : false;
  const st = asTrimmedString(t.status);
  const used = st === 'used' || st === 'deleted';
  return {
    inviterName: asTrimmedString(t.issuedByName),
    inviterEmail: '',
    officeName: asTrimmedString(t.accountantName) || 'Escritorio de contabilidade',
    email: asTrimmedString(t.accountantEmail),
    phone: '',
    accepted: used,
    expired: tExpired,
  };
});

exports.publicSubmitAccountingOfficeSignup = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  const officeName = asTrimmedString(data?.officeName);
  const cnpj = onlyDigits(data?.cnpj);
  const responsibleName = asTrimmedString(data?.responsibleName);
  const phone = asTrimmedString(data?.phone);
  const email = asTrimmedString(data?.email).toLowerCase();
  const password = String(data?.password ?? '');
  const confirmPassword = String(data?.confirmPassword ?? '');
  const address = asTrimmedString(data?.address);
  const city = asTrimmedString(data?.city);
  const state = asTrimmedString(data?.state).toUpperCase();
  const billingChoice = asTrimmedString(data?.billingChoice) || 'office';
  const notes = asTrimmedString(data?.notes);

  if (password != confirmPassword) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A confirmacao de senha nao confere.',
    );
  }

  let accountingInviteId = '';
  let trialInviteDocForOffice: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let invitedByName = '';
  let invitedByEmail = '';
  if (token) {
    const tokenHash = hashPublicToken(token);
    const accSnap = await accountingOfficeInviteRef()
      .where('tokenHash', '==', tokenHash)
      .limit(1)
      .get();
    if (!accSnap.empty) {
      accountingInviteId = accSnap.docs[0].id;
      const inviteData = asRecord(accSnap.docs[0].data());
      const expiresAt = inviteData.tokenExpiresAt;
      const expired =
        expiresAt instanceof admin.firestore.Timestamp
          ? expiresAt.toMillis() < Date.now()
          : false;
      if (expired) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Convite de escritorio expirado.',
        );
      }
      invitedByName = asTrimmedString(inviteData.inviterName);
      invitedByEmail = asTrimmedString(inviteData.inviterEmail);
    } else {
      const trialSnap = await trialInviteRef()
        .where('tokenHash', '==', tokenHash)
        .limit(1)
        .get();
      if (trialSnap.empty) {
        throw new functions.https.HttpsError(
          'not-found',
          'Convite de escritorio nao encontrado ou invalido.',
        );
      }
      const trialData = asRecord(trialSnap.docs[0].data());
      const tStatus = asTrimmedString(trialData.status);
      if (tStatus === 'used' || tStatus === 'deleted') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Este convite de teste ja foi utilizado ou esta encerrado.',
        );
      }
      const tExpires = trialData.tokenExpiresAt;
      const tExpired =
        tExpires instanceof admin.firestore.Timestamp
          ? tExpires.toMillis() < Date.now()
          : false;
      if (tExpired) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Convite de teste de 30 dias expirado.',
        );
      }
      const expectedAccountant = asTrimmedString(trialData.accountantEmail).toLowerCase();
      if (expectedAccountant && email !== expectedAccountant) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Para usar este link de teste, conclua o cadastro com o mesmo email do escritorio indicado no convite (email do contador).',
        );
      }
      trialInviteDocForOffice = trialSnap.docs[0];
      invitedByName = asTrimmedString(trialData.issuedByName);
      invitedByEmail = '';
    }
  }

  const result = await createOrUpdateAccountingOffice({
    officeName,
    cnpj,
    responsibleName,
    phone,
    email,
    password,
    address,
    city,
    state,
    billingChoice,
    notes,
    invitedByName,
    invitedByEmail,
    source: accountingInviteId
      ? 'email_invite'
      : token
        ? 'public_signup'
        : 'public_signup',
    inviteId: accountingInviteId,
  });

  if (accountingInviteId) {
    await accountingOfficeInviteRef().doc(accountingInviteId).set(
      {
        status: 'accepted',
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptedOfficeId: result.officeId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  if (trialInviteDocForOffice) {
    await trialInviteDocForOffice.ref.set(
      {
        status: 'used',
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedOfficeId: result.officeId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  await notificarNovoCadastroAdministrativo({
    signupType: 'office',
    officeId: result.officeId,
    officeName,
    companyDocument: cnpj,
    responsibleName,
    responsibleEmail: email,
  });

  return {
    ok: true,
    officeId: result.officeId,
    officeName,
    email,
    loginUrl: result.loginUrl,
    emailDispatched: result.emailDispatched,
    platformLinked: true,
    message:
      'O escritorio foi cadastrado com sucesso. Agora o proximo passo e entrar no login do contador e cadastrar a primeira empresa da carteira.',
  };
});

exports.publicCreateAccountantWorkspaceAccess = functions.https.onCall(async (data) => {
  try {
    const officeName = asTrimmedString(data?.officeName) || 'Escritorio em configuracao';
    const responsibleName = asTrimmedString(data?.responsibleName);
    const email = asTrimmedString(data?.email).toLowerCase();
    const password = String(data?.password ?? '').trim();
    const confirmPassword = String(data?.confirmPassword ?? '').trim();

    if (!responsibleName || !email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Informe nome e email para criar o acesso do contador.',
      );
    }
    if (password !== confirmPassword) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A confirmacao de senha nao confere.',
      );
    }

    const result = await provisionLightweightOfficeAccess({
      officeName,
      responsibleName,
      email,
      password: password.length > 0 ? password : undefined,
      source: 'public_lightweight_signup',
    });

    await notificarNovoCadastroAdministrativo({
      signupType: 'office',
      officeId: result.officeId,
      officeName,
      responsibleName,
      responsibleEmail: email,
    });

    return {
      ok: true,
      officeId: result.officeId,
      officeName,
      email,
      loginUrl: result.loginUrl,
      emailDispatched: result.emailDispatched,
      platformLinked: true,
      message:
        result.emailDispatched
          ? 'Acesso do contador criado. Enviamos o e-mail com criacao de senha, link web e orientacao da Play Store.'
          : 'Acesso do contador criado. Entre no sistema e complete o perfil real do escritorio quando quiser.',
    };
  } catch (error: unknown) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    const msg = errorMessage(error, 'unknown');
    functions.logger.error('publicCreateAccountantWorkspaceAccess error', {
      message: msg,
      stack: error instanceof Error ? error.stack : undefined,
    });
    if (isLikelyFirebaseAdminIamSigningError(error)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'O pre-cadastro precisa de permissao IAM no Google Cloud: na conta de servico que executa as Cloud Functions, ' +
          'conceda o papel "Token Creator de Conta de Servico" (roles/iam.serviceAccountTokenCreator) ' +
          'sobre a conta firebase-adminsdk do projeto (necessario para links de redefinicao de senha).',
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      `Nao foi possivel concluir o pre-cadastro do contador: ${msg}`,
    );
  }
});

exports.accountantRegisterCompanyIndication = functions.https.onCall(async (data, context) => {
  const {uid} = assertAuth(context);
  const claims = assertClaims(context);
  const accountantProfile = await carregarUsuarioMesmoTenant(uid, claims);
  if (roleParaFirestore(accountantProfile.role) !== 'ACCOUNTANT') {
    throw new functions.https.HttpsError('permission-denied', 'Acesso restrito ao contador.');
  }

  const responsibleName = asTrimmedString(data?.ownerName);
  const legalName = asTrimmedString(data?.legalName);
  const tradeName = asTrimmedString(data?.tradeName) || legalName;
  const cnpj = onlyDigits(data?.cnpj);
  const businessCategory = asTrimmedString(data?.businessCategory) || 'service';
  const stateRegistration = asTrimmedString(data?.stateRegistration);
  const municipalRegistration = asTrimmedString(data?.municipalRegistration);
  const phone = asTrimmedString(data?.phone);
  const companyEmail = asTrimmedString(data?.companyEmail).toLowerCase();
  const address = asTrimmedString(data?.address);
  const registrySnapshot = asRecord(data?.registrySnapshot);
  const companyAccessEnabled = data?.companyAccessEnabled === true;
  const companyAccessEmail = asTrimmedString(data?.companyAccessEmail).toLowerCase();
  const officeBillingChoiceDefault =
    asTrimmedString(accountantProfile.officeBillingChoiceDefault).toLowerCase() === 'company'
      ? 'company'
      : 'office';
  const billingChoiceRaw = asTrimmedString(data?.billingChoice).toLowerCase();
  const billingChoice = billingChoiceRaw === 'company' ? 'company' : officeBillingChoiceDefault;

  if (!responsibleName || !legalName || !tradeName || cnpj.length !== 14) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preencha os dados principais da empresa.',
    );
  }
  if (!phone || !companyEmail || !address) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Telefone, email da empresa e endereco sao obrigatorios.',
    );
  }
  if (businessCategory !== 'service' && !stateRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao estadual obrigatoria para esse ramo.',
    );
  }
  if (businessCategory === 'service' && !municipalRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao municipal obrigatoria para servicos.',
    );
  }
  if (companyAccessEnabled && !companyAccessEmail) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe o email de acesso da empresa quando o acesso estiver habilitado.',
    );
  }

  const existingCompanySnap = await admin
    .firestore()
    .collection('company_settings')
    .where('companyData.cnpj', '==', cnpj)
    .limit(1)
    .get();
  if (!existingCompanySnap.empty) {
    throw new functions.https.HttpsError(
      'already-exists',
      'Ja existe empresa cadastrada com este CNPJ no sistema.',
    );
  }

  const lookupPayload =
    Object.keys(registrySnapshot).length > 0 ? registrySnapshot : await fetchCnpjPayload(cnpj);
  const legalNature = asTrimmedString(data?.legalNature) || asTrimmedString(lookupPayload.legalNature);
  const companySize = asTrimmedString(data?.companySize) || asTrimmedString(lookupPayload.companySize);
  const mainCnaeDescription =
    asTrimmedString(data?.mainCnaeDescription) || asTrimmedString(lookupPayload.mainCnaeDescription);
  const state = asTrimmedString(data?.state) || asTrimmedString(lookupPayload.state);
  const city = asTrimmedString(data?.city) || asTrimmedString(lookupPayload.city);
  const zipCode = onlyDigits(data?.zipCode || lookupPayload.zipCode);
  const street = asTrimmedString(data?.street) || asTrimmedString(lookupPayload.street) || address;
  const number = asTrimmedString(data?.number || lookupPayload.number);
  const neighborhood = asTrimmedString(data?.neighborhood || lookupPayload.neighborhood);
  const complement = asTrimmedString(data?.complement || lookupPayload.complement);

  const accountantEmail = asTrimmedString(accountantProfile.email).toLowerCase();
  const accountantName = asTrimmedString(accountantProfile.nome) || 'Contador';
  const officeId = asTrimmedString(accountantProfile.officeId);
  const officeNameFromUser = asTrimmedString(accountantProfile.officeName);
  const officeDoc = officeId ? await accountingOfficeRef().doc(officeId).get() : null;
  const officeData = asRecord(officeDoc?.data());
  const officeName = asTrimmedString(officeData.officeName) || officeNameFromUser || accountantName;
  const officeEmail = asTrimmedString(officeData.email) || accountantEmail;

  const classification = classifyDirectSignupCompany({
    legalNature,
    companySize,
    mainCnaeDescription,
  });
  const companyId = `comp_${Date.now()}`;
  const companyDisplayCode = buildCompanyDisplayCode({
    cnpj,
    companyName: tradeName,
  });
  const companyData = {
    razaoSocial: legalName,
    nomeFantasia: tradeName,
    responsavelNome: responsibleName,
    cnpj,
    businessCategory,
    inscricaoEstadual: businessCategory === 'service' ? '' : stateRegistration,
    inscricaoEstadualDispensada: businessCategory === 'service',
    inscricaoMunicipalObrigatoria: businessCategory === 'service',
    inscricaoMunicipal: municipalRegistration,
    telefone: phone,
    email: companyEmail,
    endereco: address || street,
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    companyDisplayCode,
    legalNature,
    companySize,
    mainCnaeDescription,
    cep: zipCode,
    rua: street,
    numero: number,
    bairro: neighborhood,
    complemento: complement,
    cidade: city,
    estado: state.toUpperCase(),
  };

  let paymentLinkUrl = '';
  let paymentCustomerId = '';
  let paymentSubscriptionId = '';
  let paymentStatus = billingChoice === 'company' ? 'pending_company_charge' : 'office_billed';
  if (billingChoice === 'company') {
    const provisioned = await provisionDirectSignupBilling({
      companyId,
      owner: {
        nome: responsibleName,
        email: companyAccessEnabled ? companyAccessEmail : companyEmail,
        telefone: phone,
      },
      companyData,
      planCode: 'equipe',
      monthlyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
      description: `Empresa do escritorio | ${tradeName} | ${companyId}`,
    });
    paymentLinkUrl = provisioned.paymentLinkUrl;
    paymentCustomerId = provisioned.customerId;
    paymentSubscriptionId = provisioned.subscriptionId;
    paymentStatus = 'pending_company_charge';
  }

  const commercialSettings = buildDefaultCommercialSettings({
    companyId,
    commercialSettings: {
      plan: 'equipe',
      businessTier: classification.businessTier,
      lifecycleStatus: companyAccessEnabled ? 'active' : 'managed_by_accountant',
      billingStatus: paymentStatus,
      allowLogin: companyAccessEnabled,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired: false,
      activationStatus: companyAccessEnabled ? 'released' : 'not_enabled',
      billingIntegration: {
        provider: billingChoice === 'company' ? 'asaas' : 'office_account',
        accessManagedByGateway: false,
        customerId: paymentCustomerId,
        subscriptionId: paymentSubscriptionId,
        paymentLinkUrl,
        checkoutUrl: paymentLinkUrl,
        externalReference: companyId,
        status: paymentStatus,
        graceDays: 3,
        webhookReady: billingChoice === 'company',
      },
      baseSystemPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
      monthlyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
      seatsIncluded: classification.seatsIncluded,
      contractedAppUsers: classification.seatsIncluded,
      pricingModel: 'accountant_referral',
      platformNote:
        `Empresa indicada por escritorio contabil. Mensalidade base de R$ 97,90 com pagador ${billingChoice === 'company' ? 'empresa' : 'escritorio'}.`,
    },
  });

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  await settingsRef.set(
    {
      companyId,
      companyData,
      companyExperience: {
        type: classification.companyType,
        plan: classification.companyPlan === 'SOLO' ? 'Solo' : 'Equipe',
        validationLabel: classification.validationLabel,
        validationReason: classification.reason,
      },
      commercialSettings,
      accountantOffice: {
        officeId,
        officeName,
        officeEmail,
        accountantName,
        accountantEmail,
        linkedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      accountantCommercial: {
        source: 'accountant_office',
        companyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
        billingChoice,
        paymentLinkUrl,
        companyAccessEnabled,
        companyAccessEmail: companyAccessEnabled ? companyAccessEmail : '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      directSignup: {
        source: 'accountant_register_company',
        classificationReason: classification.reason,
        classificationValidationLabel: classification.validationLabel,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (officeId) {
    await accountingOfficeRef().doc(officeId).set(
      {
        linkedCompaniesCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  await admin.firestore().collection('accountant_links').doc(`${companyId}_${uid}`).set(
    {
      companyId,
      companyName: tradeName,
      companyDocument: cnpj,
      companyDisplayCode,
      accountantUserId: uid,
      accountantName,
      accountantEmail,
      officeId,
      officeName,
      linkedByUserId: uid,
      linkedByName: accountantName,
      status: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  let ownerUid = '';
  let loginUrl = '';
  let companyAccessEmailSent = false;
  if (companyAccessEnabled) {
    const ownerAccess = await ensureCompanyOwnerAccess({
      companyId,
      companyName: tradeName,
      companyDisplayCode,
      ownerName: responsibleName,
      ownerEmail: companyAccessEmail,
      companyData,
      mustChangePassword: true,
    });
    ownerUid = ownerAccess.ownerUid;
    loginUrl = ownerAccess.loginUrl;
    companyAccessEmailSent = true;
  }

  await notificarNovoCadastroAdministrativo({
    signupType: 'company_from_office',
    companyId,
    officeId,
    officeName,
    companyName: tradeName,
    companyDocument: cnpj,
    responsibleName,
    responsibleEmail: companyAccessEnabled ? companyAccessEmail : companyEmail,
    accountantName,
    accountantEmail,
  });

  const companyDataForProvision: Record<string, unknown> = {...companyData};
  try {
    const claimsForProvision: Claims = {
      uid,
      companyId,
      role: 'ACCOUNTANT',
      employeeId: uid,
    };
    await refreshCompanyProvisioningState({
      claims: claimsForProvision,
      companyData: companyDataForProvision,
    });
  } catch (error: unknown) {
    functions.logger.warn('refreshCompanyProvisioningState after accountantRegisterCompanyIndication', {
      companyId,
      error: errorMessage(error, 'unknown'),
    });
  }

  return {
    ok: true,
    companyId,
    companyDisplayCode,
    companyName: tradeName,
    officeId,
    officeName,
    companyAccessEnabled,
    companyAccessEmail: companyAccessEnabled ? companyAccessEmail : '',
    companyAccessEmailSent,
    loginUrl,
    billingChoice,
    companyPriceCents: DEFAULT_ACCOUNTANT_COMPANY_PRICE_CENTS,
    paymentLinkUrl,
    ownerUid,
  };
});

exports.publicRegisterCompanyDirectSignup = functions.https.onCall(async (data) => {
  const ownerEmail = asTrimmedString(data?.ownerEmail).toLowerCase();
  const ownerPassword = String(data?.ownerPassword ?? '');
  const ownerName = asTrimmedString(data?.ownerName);
  const legalName = asTrimmedString(data?.legalName);
  const tradeName = asTrimmedString(data?.tradeName) || legalName;
  const cnpj = onlyDigits(data?.cnpj);
  const businessCategory = asTrimmedString(data?.businessCategory) || 'service';
  const stateRegistration = asTrimmedString(data?.stateRegistration);
  const municipalRegistration = asTrimmedString(data?.municipalRegistration);
  const phone = asTrimmedString(data?.phone);
  const companyEmailRaw = asTrimmedString(data?.companyEmail).toLowerCase();
  const address = asTrimmedString(data?.address);
  const accountantName = asTrimmedString(data?.accountantName);
  const accountantEmail = asTrimmedString(data?.accountantEmail).toLowerCase();
  const registrySnapshot = asRecord(data?.registrySnapshot);
  const trialInviteToken = asTrimmedString(data?.trialInviteToken);

  if (!ownerEmail || !ownerName || !legalName || !tradeName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preencha os dados obrigatorios do responsavel e da empresa.',
    );
  }
  const effectiveOwnerPassword =
    ownerPassword.trim().length > 0 ? ownerPassword : gerarSenhaTemporaria();
  const companyEmail = companyEmailRaw || ownerEmail;
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError('invalid-argument', 'CNPJ invalido.');
  }
  const lookupPayload =
    Object.keys(registrySnapshot).length > 0 ? registrySnapshot : await fetchCnpjPayload(cnpj);
  const legalNature = asTrimmedString(data?.legalNature) || asTrimmedString(lookupPayload.legalNature);
  const companySize = asTrimmedString(data?.companySize) || asTrimmedString(lookupPayload.companySize);
  const mainCnaeDescription =
    asTrimmedString(data?.mainCnaeDescription) || asTrimmedString(lookupPayload.mainCnaeDescription);
  const state = asTrimmedString(data?.state) || asTrimmedString(lookupPayload.state);
  const city = asTrimmedString(data?.city) || asTrimmedString(lookupPayload.city);
  const zipCode = onlyDigits(data?.zipCode || lookupPayload.zipCode);
  const street = asTrimmedString(data?.street) || asTrimmedString(lookupPayload.street) || address;
  const number = asTrimmedString(data?.number || lookupPayload.number);
  const neighborhood = asTrimmedString(data?.neighborhood || lookupPayload.neighborhood);
  const complement = asTrimmedString(data?.complement || lookupPayload.complement);
  const classification = classifyDirectSignupCompany({
    legalNature,
    companySize,
    mainCnaeDescription,
  });
  if (businessCategory !== 'service' && !stateRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao estadual obrigatoria para esse ramo.',
    );
  }
  if (businessCategory === 'service' && !municipalRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao municipal obrigatoria para servicos.',
    );
  }
  if (accountantEmail && !accountantName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe o nome do contador junto com o email.',
    );
  }

  let trialInviteSnap: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  if (trialInviteToken) {
    const tokenHash = hashPublicToken(trialInviteToken);
    const inviteQuery = await trialInviteRef()
      .where('tokenHash', '==', tokenHash)
      .limit(1)
      .get();
    if (inviteQuery.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'Convite de teste nao encontrado ou invalido.',
      );
    }
    const invite = asRecord(inviteQuery.docs[0].data());
    const status = asTrimmedString(invite.status);
    const invitedCompanyEmail = asTrimmedString(invite.companyEmail).toLowerCase();
    const inviteExpiresAt = invite.tokenExpiresAt;
    const expiresAtMillis = inviteExpiresAt instanceof admin.firestore.Timestamp
      ? inviteExpiresAt.toMillis()
      : inviteExpiresAt instanceof Date
        ? inviteExpiresAt.getTime()
        : Number.NaN;
    if (status !== 'issued') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite de teste ja utilizado ou indisponivel.',
      );
    }
    if (!Number.isFinite(expiresAtMillis) || expiresAtMillis < Date.now()) {
      await inviteQuery.docs[0].ref.set(
        {
          status: 'expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite de teste expirado. Solicite um novo link.',
      );
    }
    if (invitedCompanyEmail && invitedCompanyEmail !== ownerEmail && invitedCompanyEmail !== companyEmail) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Este convite de teste nao corresponde ao email informado.',
      );
    }
    trialInviteSnap = inviteQuery.docs[0];
  }

  let existingCompanySnap = await admin
    .firestore()
    .collection('company_settings')
    .where('companyData.cnpj', '==', cnpj)
    .limit(1)
    .get()
    .catch(() => null);
  if (existingCompanySnap && !existingCompanySnap.empty) {
    throw new functions.https.HttpsError(
      'already-exists',
      'Ja existe empresa cadastrada com este CNPJ no sistema.',
    );
  }

  let ownerRecord: admin.auth.UserRecord;
  let previousLightweightCompanyId = '';
  try {
    ownerRecord = await admin.auth().getUserByEmail(ownerEmail);
    const existingUserSnap = await admin.firestore().collection('users').doc(ownerRecord.uid).get();
    if (!existingUserSnap.exists) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de acesso ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    const existingUser = asRecord(existingUserSnap.data());
    const reusableLightweight =
      roleParaFirestore(existingUser.role) === 'OWNER' &&
      existingUser.lightweightProfilePending === true;
    if (!reusableLightweight) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de acesso ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    previousLightweightCompanyId = asTrimmedString(existingUser.companyId);
    await admin.auth().updateUser(ownerRecord.uid, {
      password: effectiveOwnerPassword,
      displayName: ownerName,
    });
  } catch (error: unknown) {
    const typed = error as {code?: string};
    if (typed.code === 'auth/user-not-found') {
      try {
        ownerRecord = await admin.auth().createUser({
          email: ownerEmail,
          password: effectiveOwnerPassword,
          displayName: ownerName,
          emailVerified: false,
        });
      } catch (innerError: unknown) {
        const innerTyped = innerError as {code?: string};
        if (innerTyped.code === 'auth/email-already-exists') {
          throw new functions.https.HttpsError(
            'already-exists',
            'Este email de acesso ja esta em uso. Use outro email ou recupere a senha.',
          );
        }
        throw new functions.https.HttpsError(
          'internal',
          'Nao foi possivel criar o acesso inicial da empresa.',
        );
      }
    } else {
      throw error;
    }
  }

  const companyId = `comp_${Date.now()}`;
  if (previousLightweightCompanyId && previousLightweightCompanyId !== companyId) {
    await markSupersededLightweightCompany({
      previousCompanyId: previousLightweightCompanyId,
      nextCompanyId: companyId,
    });
  }
  const companyDisplayCode = buildCompanyDisplayCode({
    cnpj,
    companyName: tradeName,
  });
  const companyData = {
    razaoSocial: legalName,
    nomeFantasia: tradeName,
    cnpj,
    businessCategory,
    inscricaoEstadual: businessCategory === 'service' ? '' : stateRegistration,
    inscricaoEstadualDispensada: businessCategory === 'service',
    inscricaoMunicipalObrigatoria: businessCategory === 'service',
    inscricaoMunicipal: municipalRegistration,
    telefone: phone,
    email: companyEmail,
    endereco: address || street,
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    companyDisplayCode,
    legalNature,
    companySize,
    mainCnaeDescription,
    cep: zipCode,
    rua: street,
    numero: number,
    bairro: neighborhood,
    complemento: complement,
    cidade: city,
    estado: state.toUpperCase(),
  };

  const publicConfigSnap = await publicSalesConfigRef().get();
  const publicConfig = buildDefaultPublicSalesConfig(asRecord(publicConfigSnap.data()));
  const selectedPlan = asRecord(
    classification.companyPlan === 'SOLO' ? publicConfig.planSolo : publicConfig.planEquipe,
  );
  const planCode = classification.companyPlan === 'SOLO' ? 'solo' : 'equipe';
  const paidMatch = await findExistingPaidDirectSignup({
    ownerEmail,
    planCode,
  });

  let billingData: {
    provider: string;
    accessManagedByGateway: boolean;
    customerId: string;
    subscriptionId: string;
    paymentLinkUrl: string;
    checkoutUrl: string;
    externalReference: string;
    status: string;
    graceDays: number;
    graceUntil?: FirebaseFirestore.Timestamp | null;
    webhookReady: boolean;
  };
  let allowLogin = false;
  let billingStatus = 'pending_payment';
  let lifecycleStatus = 'lead';
  let activationRequired = false;
  let activationStatus = 'not_required';

  if (trialInviteSnap) {
    const graceUntil = admin.firestore.Timestamp.fromMillis(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    );
    billingData = {
      provider: 'manual',
      accessManagedByGateway: true,
      customerId: '',
      subscriptionId: '',
      paymentLinkUrl: '',
      checkoutUrl: '',
      externalReference: companyId,
      status: 'trialing',
      graceDays: 30,
      graceUntil,
      webhookReady: false,
    };
    allowLogin = true;
    billingStatus = 'trialing';
    lifecycleStatus = 'trial';
    activationStatus = 'released';
  } else if (paidMatch.found) {
    billingData = {
      provider: paidMatch.customerId || paidMatch.subscriptionId ? 'asaas' : 'manual',
      accessManagedByGateway: paidMatch.customerId || paidMatch.subscriptionId ? true : false,
      customerId: paidMatch.customerId,
      subscriptionId: paidMatch.subscriptionId,
      paymentLinkUrl: '',
      checkoutUrl: '',
      externalReference: companyId,
      status: 'active',
      graceDays: 3,
      webhookReady: paidMatch.customerId || paidMatch.subscriptionId ? true : false,
    };
    allowLogin = true;
    billingStatus = 'active';
    lifecycleStatus = 'active';
    activationStatus = 'released';
  } else {
    const provisioned = await provisionDirectSignupBilling({
      companyId,
      owner: {
        nome: ownerName,
        email: ownerEmail,
        telefone: phone,
      },
      companyData,
      planCode,
      monthlyPriceCents: Number(selectedPlan.priceCents ?? 0) || 0,
      description: `Plano ${selectedPlan.title} | ${companyId}`,
    });
    billingData = {
      provider: 'asaas',
      accessManagedByGateway: true,
      customerId: provisioned.customerId,
      subscriptionId: provisioned.subscriptionId,
      paymentLinkUrl: provisioned.paymentLinkUrl,
      checkoutUrl: provisioned.paymentLinkUrl,
      externalReference: companyId,
      status: provisioned.status,
      graceDays: 3,
      webhookReady: true,
    };
    allowLogin = false;
    billingStatus = provisioned.status;
    lifecycleStatus = 'awaiting_payment';
    activationStatus = 'pending_payment';
  }

  const commercialSettings = buildDefaultCommercialSettings({
    companyId,
    commercialSettings: {
      plan: planCode,
      businessTier: classification.businessTier,
      lifecycleStatus,
      billingStatus,
      allowLogin,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired,
      activationStatus,
      billingIntegration: billingData,
      baseSystemPriceCents: Number(selectedPlan.priceCents ?? 0) || 0,
      monthlyPriceCents: Number(selectedPlan.priceCents ?? 0) || 0,
      seatsIncluded: classification.seatsIncluded,
      contractedAppUsers: classification.seatsIncluded,
      pricingModel: 'base_plan',
      platformNote: trialInviteSnap
        ? 'Cadastro de teste 90 dias (trial) liberado por convite da plataforma.'
        : paidMatch.found
          ? `Cadastro direto liberado por pagamento ja confirmado via ${paidMatch.source}.`
          : 'Cadastro direto iniciou com cobranca automatica no Asaas.',
    },
  });

  await admin.firestore().collection('users').doc(ownerRecord.uid).set(
    {
      companyId,
      companyDisplayCode,
      companyName: tradeName,
      role: 'OWNER',
      nome: ownerName,
      email: ownerEmail,
      employeeId: ownerRecord.uid,
      mustChangePassword: false,
      companyData,
      lightweightProfilePending: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.auth().setCustomUserClaims(ownerRecord.uid, {
    companyId,
    role: 'OWNER',
    employeeId: ownerRecord.uid,
  });

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  await settingsRef.set(
    {
      companyId,
      companyData,
      companyExperience: {
        type: classification.companyType,
        plan: classification.companyPlan === 'SOLO' ? 'Solo' : 'Equipe',
        validationLabel: classification.validationLabel,
        validationReason: classification.reason,
      },
      commercialSettings,
      directSignup: {
        source: 'public_direct_signup',
        paidBeforeSignup: paidMatch.found,
        paidSource: paidMatch.source,
        classificationReason: classification.reason,
        classificationValidationLabel: classification.validationLabel,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (accountantEmail) {
    await ensureAccountantAccessForCompany({
      companyId,
      companyName: tradeName,
      companyDisplayCode,
      companyDocument: cnpj,
      linkedByUserId: ownerRecord.uid,
      linkedByName: ownerName,
      accountantName,
      accountantEmail,
    });
    await settingsRef.set(
      {
        accountantOnboardingPending: {
          accountantName,
          accountantEmail,
          status: 'pending_accountant_link',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );
  }

  if (trialInviteSnap) {
    await trialInviteSnap.ref.set(
      {
        status: 'used',
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedCompanyId: companyId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  await notificarNovoCadastroAdministrativo({
    signupType: 'company_direct',
    companyId,
    companyName: tradeName,
    companyDocument: cnpj,
    responsibleName: ownerName,
    responsibleEmail: ownerEmail,
    accountantName,
    accountantEmail,
  });

  let emailDispatched = false;
  try {
    const emailCfg = obterConfigEmail();
    const resetLink = await admin.auth().generatePasswordResetLink(ownerEmail);
    const loginUrl =
      `https://gestao-ponto-certo.com/login-empresa?email=${encodeURIComponent(ownerEmail)}`;
    await enviarEmailAcessoInicialEmpresa({
      email: ownerEmail,
      nome: ownerName,
      companyName: tradeName,
      resetLink,
      loginUrl,
      apkUrl: emailCfg.apkUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
    emailDispatched = true;
  } catch (_) {
    emailDispatched = false;
  }

  return {
    ok: true,
    companyId,
    companyDisplayCode,
    planCode,
    planTitle: asTrimmedString(selectedPlan.title),
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    validationLabel: classification.validationLabel,
    validationReason: classification.reason,
    paidBeforeSignup: paidMatch.found,
    billingStatus,
    released: allowLogin,
    paymentLinkUrl: asTrimmedString(billingData.paymentLinkUrl),
    requiresPayment: trialInviteSnap ? false : !paidMatch.found,
    emailDispatched,
  };
});

exports.publicCreateCompanyWorkspaceAccess = functions.https.onCall(async (data) => {
  const ownerEmail = asTrimmedString(data?.ownerEmail).toLowerCase();
  const ownerPassword = String(data?.ownerPassword ?? '').trim();
  const confirmPassword = String(data?.confirmPassword ?? '').trim();
  const ownerName = asTrimmedString(data?.ownerName);
  const companyName =
    asTrimmedString(data?.companyName) || 'Empresa em configuracao';

  if (!ownerEmail || !ownerName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email para criar o acesso da empresa.',
    );
  }
  if (ownerPassword !== confirmPassword) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A confirmacao de senha nao confere.',
    );
  }

  const result = await provisionLightweightCompanyAccess({
    ownerEmail,
    ownerName,
    companyName,
    password: ownerPassword.length > 0 ? ownerPassword : undefined,
    source: 'public_lightweight_access',
  });

  await notificarNovoCadastroAdministrativo({
    signupType: 'company_direct',
    companyId: result.companyId,
    companyName,
    responsibleName: ownerName,
    responsibleEmail: ownerEmail,
  });

  return {
    ok: true,
    companyId: result.companyId,
    companyName,
    emailDispatched: result.emailDispatched,
  };
});

exports.companyCompleteWorkspaceProfile = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);
  await assertNotDemoReadOnly(claims);
  const ownerProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);

  const ownerName = asTrimmedString(data?.ownerName);
  const legalName = asTrimmedString(data?.legalName);
  const tradeName = asTrimmedString(data?.tradeName) || legalName;
  const cnpj = onlyDigits(data?.cnpj);
  const businessCategory = asTrimmedString(data?.businessCategory) || 'service';
  const stateRegistration = asTrimmedString(data?.stateRegistration);
  const municipalRegistration = asTrimmedString(data?.municipalRegistration);
  const phone = asTrimmedString(data?.phone);
  const companyEmailRaw = asTrimmedString(data?.companyEmail).toLowerCase();
  const address = asTrimmedString(data?.address);
  const accountantName = asTrimmedString(data?.accountantName);
  const accountantEmail = asTrimmedString(data?.accountantEmail).toLowerCase();
  const registrySnapshot = asRecord(data?.registrySnapshot);

  if (!ownerName || !legalName || !tradeName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preencha os dados principais do responsavel e da empresa.',
    );
  }
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError('invalid-argument', 'CNPJ invalido.');
  }
  if (!phone || !address) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Telefone e endereco sao obrigatorios.',
    );
  }
  if (businessCategory !== 'service' && !stateRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao estadual obrigatoria para esse ramo.',
    );
  }
  if (businessCategory === 'service' && !municipalRegistration) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Inscricao municipal obrigatoria para servicos.',
    );
  }
  if (accountantEmail && !accountantName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe o nome do contador junto com o email.',
    );
  }

  const existingCompanySnap = await admin
    .firestore()
    .collection('company_settings')
    .where('companyData.cnpj', '==', cnpj)
    .limit(1)
    .get();
  if (!existingCompanySnap.empty && existingCompanySnap.docs[0].id !== claims.companyId) {
    throw new functions.https.HttpsError(
      'already-exists',
      'Ja existe empresa cadastrada com este CNPJ no sistema.',
    );
  }

  const lookupPayload =
    Object.keys(registrySnapshot).length > 0 ? registrySnapshot : await fetchCnpjPayload(cnpj);
  const legalNature = asTrimmedString(data?.legalNature) || asTrimmedString(lookupPayload.legalNature);
  const companySize = asTrimmedString(data?.companySize) || asTrimmedString(lookupPayload.companySize);
  const mainCnaeDescription =
    asTrimmedString(data?.mainCnaeDescription) || asTrimmedString(lookupPayload.mainCnaeDescription);
  const state = asTrimmedString(data?.state) || asTrimmedString(lookupPayload.state);
  const city = asTrimmedString(data?.city) || asTrimmedString(lookupPayload.city);
  const zipCode = onlyDigits(data?.zipCode || lookupPayload.zipCode);
  const street = asTrimmedString(data?.street) || asTrimmedString(lookupPayload.street) || address;
  const number = asTrimmedString(data?.number || lookupPayload.number);
  const neighborhood = asTrimmedString(data?.neighborhood || lookupPayload.neighborhood);
  const complement = asTrimmedString(data?.complement || lookupPayload.complement);
  const classification = classifyDirectSignupCompany({
    legalNature,
    companySize,
    mainCnaeDescription,
  });
  const companyEmail =
    companyEmailRaw || asTrimmedString(ownerProfile.email).toLowerCase();
  const companyDisplayCode = buildCompanyDisplayCode({
    cnpj,
    companyName: tradeName,
  });
  const companyData = {
    razaoSocial: legalName,
    nomeFantasia: tradeName,
    cnpj,
    businessCategory,
    inscricaoEstadual: businessCategory === 'service' ? '' : stateRegistration,
    inscricaoEstadualDispensada: businessCategory === 'service',
    inscricaoMunicipalObrigatoria: businessCategory === 'service',
    inscricaoMunicipal: municipalRegistration,
    telefone: phone,
    email: companyEmailRaw,
    endereco: address || street,
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    companyDisplayCode,
    legalNature,
    companySize,
    mainCnaeDescription,
    cep: zipCode,
    rua: street,
    numero: number,
    bairro: neighborhood,
    complemento: complement,
    cidade: city,
    estado: state.toUpperCase(),
  };

  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  await settingsRef.set(
    {
      companyId: claims.companyId,
      companyData,
      companyExperience: {
        type: classification.companyType,
        plan: classification.companyPlan === 'SOLO' ? 'Solo' : 'Equipe',
        validationLabel: classification.validationLabel,
        validationReason: classification.reason,
      },
      directSignup: {
        source: 'public_lightweight_access',
        lightweightProfilePending: false,
        classificationReason: classification.reason,
        classificationValidationLabel: classification.validationLabel,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.firestore().collection('users').doc(claims.uid).set(
    {
      nome: ownerName,
      companyName: tradeName,
      companyData,
      lightweightProfilePending: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (accountantEmail) {
    await ensureAccountantAccessForCompany({
      companyId: claims.companyId,
      companyName: tradeName,
      companyDisplayCode,
      companyDocument: cnpj,
      linkedByUserId: claims.uid,
      linkedByName: ownerName,
      accountantName,
      accountantEmail,
    });
    await settingsRef.set(
      {
        accountantOnboardingPending: {
          accountantName,
          accountantEmail,
          status: 'pending_accountant_link',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );
  }

  try {
    await refreshCompanyProvisioningState({
      claims,
      companyData: companyData as Record<string, unknown>,
    });
  } catch (error: unknown) {
    functions.logger.warn('refreshCompanyProvisioningState after companyCompleteWorkspaceProfile', {
      companyId: claims.companyId,
      error: errorMessage(error, 'unknown'),
    });
  }

  return {
    ok: true,
    companyId: claims.companyId,
    companyName: tradeName,
    companyDisplayCode,
  };
});

exports.accountantRegisterCompanyTrial30d = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['ACCOUNTANT']);
  const accountantProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  if (roleParaFirestore(accountantProfile.role) !== 'ACCOUNTANT') {
    throw new functions.https.HttpsError('permission-denied', 'Acesso permitido apenas para contador.');
  }

  const ownerEmail = asTrimmedString(data?.ownerEmail).toLowerCase();
  const ownerName = asTrimmedString(data?.ownerName);
  const legalName = asTrimmedString(data?.legalName);
  const tradeName = asTrimmedString(data?.tradeName) || legalName;
  const cnpj = onlyDigits(data?.cnpj);
  const businessCategory = asTrimmedString(data?.businessCategory) || 'service';
  const stateRegistration = asTrimmedString(data?.stateRegistration);
  const municipalRegistration = asTrimmedString(data?.municipalRegistration);
  const phone = asTrimmedString(data?.phone);
  const companyEmailRaw = asTrimmedString(data?.companyEmail).toLowerCase();
  const address = asTrimmedString(data?.address);
  const registrySnapshot = asRecord(data?.registrySnapshot);
  const trialDays = Math.max(1, Math.min(45, Number(data?.trialDays ?? 30) || 30));

  if (!ownerEmail || !ownerName || !legalName || !tradeName) {
    throw new functions.https.HttpsError('invalid-argument', 'Preencha os dados obrigatorios do responsavel e da empresa.');
  }
  const companyEmail = companyEmailRaw || ownerEmail;
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError('invalid-argument', 'CNPJ invalido.');
  }

  const lookupPayload =
    Object.keys(registrySnapshot).length > 0 ? registrySnapshot : await fetchCnpjPayload(cnpj);
  const legalNature = asTrimmedString(data?.legalNature) || asTrimmedString(lookupPayload.legalNature);
  const companySize = asTrimmedString(data?.companySize) || asTrimmedString(lookupPayload.companySize);
  const mainCnaeDescription =
    asTrimmedString(data?.mainCnaeDescription) || asTrimmedString(lookupPayload.mainCnaeDescription);
  const state = asTrimmedString(data?.state) || asTrimmedString(lookupPayload.state);
  const city = asTrimmedString(data?.city) || asTrimmedString(lookupPayload.city);
  const zipCode = onlyDigits(data?.zipCode || lookupPayload.zipCode);
  const street = asTrimmedString(data?.street) || asTrimmedString(lookupPayload.street) || address;
  const number = asTrimmedString(data?.number || lookupPayload.number);
  const neighborhood = asTrimmedString(data?.neighborhood || lookupPayload.neighborhood);
  const complement = asTrimmedString(data?.complement || lookupPayload.complement);

  const classification = classifyDirectSignupCompany({
    legalNature,
    companySize,
    mainCnaeDescription,
  });
  if (businessCategory !== 'service' && !stateRegistration) {
    throw new functions.https.HttpsError('invalid-argument', 'Inscricao estadual obrigatoria para esse ramo.');
  }
  if (businessCategory === 'service' && !municipalRegistration) {
    throw new functions.https.HttpsError('invalid-argument', 'Inscricao municipal obrigatoria para servicos.');
  }

  const existingCompanySnap = await admin
    .firestore()
    .collection('company_settings')
    .where('companyData.cnpj', '==', cnpj)
    .limit(1)
    .get();
  if (!existingCompanySnap.empty) {
    throw new functions.https.HttpsError('already-exists', 'Ja existe uma empresa cadastrada com este CNPJ.');
  }

  let ownerRecord: admin.auth.UserRecord;
  let previousLightweightCompanyId = '';
  try {
    ownerRecord = await admin.auth().getUserByEmail(ownerEmail);
    const existingUserSnap = await admin.firestore().collection('users').doc(ownerRecord.uid).get();
    if (!existingUserSnap.exists) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de responsavel ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    const existingUser = asRecord(existingUserSnap.data());
    const reusableLightweight =
      roleParaFirestore(existingUser.role) === 'OWNER' &&
      existingUser.lightweightProfilePending === true;
    if (!reusableLightweight) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Este email de responsavel ja esta em uso. Use outro email ou recupere a senha.',
      );
    }
    previousLightweightCompanyId = asTrimmedString(existingUser.companyId);
    await admin.auth().updateUser(ownerRecord.uid, {
      password: gerarSenhaTemporaria(),
      displayName: ownerName,
    });
  } catch (error: unknown) {
    const typed = error as { code?: string };
    if (typed.code !== 'auth/user-not-found') {
      throw error;
    }
    const tempPassword = gerarSenhaTemporaria();
    ownerRecord = await admin.auth().createUser({
      email: ownerEmail,
      password: tempPassword,
      displayName: ownerName,
      emailVerified: false,
    });
  }

  const companyId = `comp_${Date.now()}`;
  if (previousLightweightCompanyId && previousLightweightCompanyId !== companyId) {
    await markSupersededLightweightCompany({
      previousCompanyId: previousLightweightCompanyId,
      nextCompanyId: companyId,
    });
  }
  const companyDisplayCode = buildCompanyDisplayCode({
    cnpj,
    companyName: tradeName,
  });
  const companyData = {
    razaoSocial: legalName,
    nomeFantasia: tradeName,
    cnpj,
    businessCategory,
    inscricaoEstadual: businessCategory === 'service' ? '' : stateRegistration,
    inscricaoEstadualDispensada: businessCategory === 'service',
    inscricaoMunicipalObrigatoria: businessCategory === 'service',
    inscricaoMunicipal: municipalRegistration,
    telefone: phone,
    email: companyEmail,
    endereco: address || street,
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    companyDisplayCode,
    legalNature,
    companySize,
    mainCnaeDescription,
    cep: zipCode,
    rua: street,
    numero: number,
    bairro: neighborhood,
    complemento: complement,
    cidade: city,
    estado: state.toUpperCase(),
  };

  const graceUntil = admin.firestore.Timestamp.fromMillis(
    Date.now() + trialDays * 24 * 60 * 60 * 1000,
  );
  const billingData = {
    provider: 'manual',
    accessManagedByGateway: true,
    customerId: '',
    subscriptionId: '',
    paymentLinkUrl: '',
    checkoutUrl: '',
    externalReference: companyId,
    status: 'trialing',
    graceDays: trialDays,
    graceUntil,
    webhookReady: false,
  };
  const commercialSettings = buildDefaultCommercialSettings({
    companyId,
    commercialSettings: {
      plan: classification.companyPlan === 'SOLO' ? 'solo' : 'equipe',
      businessTier: classification.businessTier,
      lifecycleStatus: 'trial',
      billingStatus: 'trialing',
      allowLogin: true,
      requiresApproval: false,
      approvalStatus: 'approved',
      accessControlMode: 'standard',
      activationRequired: false,
      activationStatus: 'released',
      billingIntegration: billingData,
      baseSystemPriceCents: 0,
      monthlyPriceCents: 0,
      seatsIncluded: classification.seatsIncluded,
      contractedAppUsers: classification.seatsIncluded,
      pricingModel: 'trial',
      platformNote: `Trial ${trialDays} dias criado pelo contador parceiro.`,
    },
  });

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  await admin.firestore().collection('users').doc(ownerRecord.uid).set(
    {
      companyId,
      companyDisplayCode,
      companyName: tradeName,
      role: 'OWNER',
      nome: ownerName,
      email: ownerEmail,
      employeeId: ownerRecord.uid,
      mustChangePassword: false,
      companyData,
      lightweightProfilePending: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await admin.auth().setCustomUserClaims(ownerRecord.uid, {
    companyId,
    role: 'OWNER',
    employeeId: ownerRecord.uid,
  });
  await settingsRef.set(
    {
      companyId,
      companyData,
      companyExperience: {
        type: classification.companyType,
        plan: classification.companyPlan === 'SOLO' ? 'Solo' : 'Equipe',
        validationLabel: classification.validationLabel,
        validationReason: classification.reason,
      },
      commercialSettings,
      directSignup: {
        source: 'accountant_trial_signup',
        paidBeforeSignup: false,
        paidSource: '',
        classificationReason: classification.reason,
        classificationValidationLabel: classification.validationLabel,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const accountantEmail = asTrimmedString(accountantProfile.email).toLowerCase();
  const accountantName = asTrimmedString(accountantProfile.nome) || 'Contador';
  if (accountantEmail) {
    await ensureAccountantAccessForCompany({
      companyId,
      companyName: tradeName,
      companyDisplayCode,
      companyDocument: cnpj,
      linkedByUserId: claims.uid,
      linkedByName: accountantName,
      accountantName,
      accountantEmail,
    });
  }

  const emailCfg = obterConfigEmail();
  const resetLink = await admin.auth().generatePasswordResetLink(ownerEmail);
  const loginUrl =
    `https://gestao-ponto-certo.com/login-empresa?email=${encodeURIComponent(ownerEmail)}`;
  const ownerHtml = `
    <div style="font-family: Arial, Helvetica, sans-serif; color: #111; line-height: 1.5;">
      <h2 style="margin: 0 0 12px 0;">Bem-vindo: sua empresa no Ponto Certo</h2>
      <p style="margin: 0 0 10px 0;">Ola, ${escapeHtml(ownerName || 'responsavel')}.</p>
      <p style="margin: 0 0 10px 0;">
        <strong>${escapeHtml(tradeName)}</strong> esta cadastrada no Ponto Certo com
        <strong>teste gratuito de ${trialDays} dias</strong>.
      </p>
      <p style="margin: 0 0 10px 0;">
        O contador parceiro iniciou o cadastro. Para ativar seu acesso:
      </p>
      <ol style="margin: 0 0 14px 0; padding-left: 20px;">
        <li style="margin-bottom: 6px;">Use o link abaixo para <strong>criar sua senha</strong>.</li>
        <li style="margin-bottom: 6px;">Entre no painel e confira os dados principais.</li>
        <li>Na area Fiscal, complete o que faltar para emissao — o sistema guia cada etapa.</li>
      </ol>
      <p style="margin: 0 0 12px 0;">
        <a href="${resetLink}" style="font-weight:bold;">Criar senha de acesso</a>
      </p>
      <p style="margin: 0 0 12px 0;">
        <a href="${loginUrl}" style="font-weight:bold;">Entrar no painel web da empresa</a>
      </p>
      ${buildPlayStoreAccessNoticeHtml(emailCfg.apkUrl)}
      <p style="margin: 0 0 0 0; color: #374151;">
        Ao fim do teste, orientamos sobre continuidade e formalizacao — sem surpresas.
      </p>
      ${officeFounderOperatingCompanyCredibilityHtml()}
      <p style="margin: 14px 0 0 0;">${officeFounderEmailSignOffInnerHtml()}</p>
    </div>
  `;
  await enviarEmailHtml({
    toEmail: ownerEmail,
    subject: `Ponto Certo: ative seu acesso (teste ${trialDays} dias) - ${tradeName}`,
    html: ownerHtml,
    fromEmail: emailCfg.fromEmail,
    sendgridKey: emailCfg.sendgridKey,
    smtpUser: emailCfg.smtpUser,
    smtpAppPassword: emailCfg.smtpAppPassword,
  });

  await notificarNovoCadastroAdministrativo({
    signupType: 'company_trial_from_office',
    companyId,
    companyName: tradeName,
    companyDocument: cnpj,
    responsibleName: ownerName,
    responsibleEmail: ownerEmail,
    accountantName,
    accountantEmail,
  });

  await writeAudit({
    claims,
    module: 'accountant',
    action: 'accountant_register_company_trial',
    entityPath: 'company_settings',
    entityId: companyId,
    before: null,
    after: {
      companyId,
      companyDisplayCode,
      tradeName,
      ownerEmail,
      trialDays,
      graceUntil: graceUntil.toDate().toISOString(),
    },
  });

  return {
    ok: true,
    companyId,
    companyDisplayCode,
    planCode: classification.companyPlan === 'SOLO' ? 'solo' : 'equipe',
    planTitle: classification.companyPlan,
    companyType: classification.companyType,
    companyPlan: classification.companyPlan,
    validationLabel: classification.validationLabel,
    validationReason: classification.reason,
    paidBeforeSignup: false,
    billingStatus: 'trialing',
    released: true,
    paymentLinkUrl: '',
    requiresPayment: false,
  };
});

exports.publicSubmitSalesOnboardingRequest = functions.https.onCall(async (data) => {
  const token = asTrimmedString(data?.token);
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'token obrigatorio.');
  }
  const tokenHash = hashPublicToken(token);
  const snap = await salesOnboardingRef()
    .where('onboardingTokenHash', '==', tokenHash)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new functions.https.HttpsError('not-found', 'Cadastro de onboarding nao encontrado.');
  }

  const requestRef = snap.docs[0].ref;
  const payload = asRecord(data?.payload);
  const legalName = asTrimmedString(payload.legalName);
  const tradeName = asTrimmedString(payload.tradeName);
  const document = onlyDigits(payload.document);
  const ownerName = asTrimmedString(payload.ownerName);
  const ownerEmail = asTrimmedString(payload.ownerEmail).toLowerCase();
  const phone = asTrimmedString(payload.phone);
  const businessCategory = asTrimmedString(payload.businessCategory) || 'service';
  const stateRegistration = asTrimmedString(payload.stateRegistration);
  const municipalRegistration = asTrimmedString(payload.municipalRegistration);
  const zipCode = onlyDigits(payload.zipCode);
  const street = asTrimmedString(payload.street);
  const number = asTrimmedString(payload.number);
  const complement = asTrimmedString(payload.complement);
  const neighborhood = asTrimmedString(payload.neighborhood);
  const city = asTrimmedString(payload.city);
  const state = asTrimmedString(payload.state);
  const preferredLoginEmail = asTrimmedString(payload.preferredLoginEmail).toLowerCase();
  const taxRegime = asTrimmedString(payload.taxRegime);
  const legalNature = asTrimmedString(payload.legalNature);
  const companySize = asTrimmedString(payload.companySize);
  const mainCnae = asTrimmedString(payload.mainCnae);
  const mainCnaeDescription = asTrimmedString(payload.mainCnaeDescription);
  const municipalCode = asTrimmedString(payload.municipalCode);
  const standardServiceCode = asTrimmedString(payload.standardServiceCode);
  const certificatePassword = asTrimmedString(payload.certificatePassword);
  const responsibleLogin = asTrimmedString(payload.responsibleLogin);
  const responsiblePassword = asTrimmedString(payload.responsiblePassword);
  const onboardingMode = asTrimmedString(payload.onboardingMode);
  const accountantName = asTrimmedString(payload.accountantName);
  const accountantEmail = asTrimmedString(payload.accountantEmail).toLowerCase();

  if (!legalName || !tradeName || !document || !ownerName || !ownerEmail || !phone) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Preencha razao social, nome fantasia, documento, responsavel, email e telefone.',
    );
  }
  if (
    onboardingMode !== 'accountant' &&
    ((accountantName && !accountantEmail) || (!accountantName && accountantEmail))
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe nome e email do contador para vincular o escritorio a empresa.',
    );
  }

  const uploadsRaw = Array.isArray(data?.uploads) ? data.uploads : [];
  const uploads: Array<Record<string, unknown>> = [];
  for (const item of uploadsRaw.slice(0, 6)) {
    const upload = asRecord(item);
    const fileName = asTrimmedString(upload.fileName);
    const contentType = asTrimmedString(upload.contentType) || 'application/octet-stream';
    const category = asTrimmedString(upload.category) || 'document';
    const base64 = asTrimmedString(upload.base64);
    if (!fileName || !base64) continue;
    const buffer = Buffer.from(base64, 'base64');
    if (buffer.byteLength > 5 * 1024 * 1024) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Cada arquivo deve ter no maximo 5 MB.',
      );
    }
    const storagePath = `sales_onboarding_uploads/${requestRef.id}/${Date.now()}_${fileName}`;
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    await file.save(buffer, {
      contentType,
      resumable: false,
      metadata: {
        contentType,
      },
    });
    await file.makePublic();
    uploads.push({
      fileName,
      contentType,
      category,
      storagePath,
      publicUrl: file.publicUrl(),
      uploadedAt: new Date().toISOString(),
    });
  }

  const uploadCategories = uploads
    .map((item) => asTrimmedString(item.category))
    .filter((item) => item);
  const missing: string[] = [];
  if (!taxRegime) missing.push('regime tributario');
  if (!municipalRegistration) missing.push('inscricao municipal');
  if (!zipCode) missing.push('cep');
  if (!street) missing.push('rua');
  if (!number) missing.push('numero');
  if (!neighborhood) missing.push('bairro');
  if (!city) missing.push('cidade');
  if (!state) missing.push('estado');
  if (!legalNature) missing.push('natureza juridica');
  if (!companySize) missing.push('porte da empresa');
  if (!mainCnae) missing.push('cnae principal');
  if (!mainCnaeDescription) missing.push('descricao do cnae principal');
  if (!municipalCode) missing.push('codigo do municipio / IBGE');
  if (businessCategory === 'service' && !standardServiceCode) {
    missing.push('codigo padrao de servico');
  }
  if (!certificatePassword) missing.push('senha do certificado digital');
  if (!uploadCategories.includes('cartao_cnpj')) missing.push('cartao CNPJ');
  if (!uploadCategories.includes('documento_responsavel')) {
    missing.push('documento do responsavel');
  }
  if (!uploadCategories.includes('comprovante_endereco')) {
    missing.push('comprovante de endereco');
  }
  if (!uploadCategories.includes('contrato_social')) missing.push('contrato social');
  if (!uploadCategories.includes('certificado_digital_a1')) {
    missing.push('certificado digital A1');
  }
  if (missing.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Nao foi possivel concluir o onboarding sem a base completa para emissao e operacao. Falta: ${missing.join(', ')}.`,
    );
  }

  await requestRef.set(
    {
      status: 'submitted',
      formData: {
        legalName,
        tradeName,
        document,
        ownerName,
        ownerEmail,
        phone,
        businessCategory,
        stateRegistration,
        municipalRegistration,
        zipCode,
        street,
        number,
        complement,
        neighborhood,
        city,
        state,
        preferredLoginEmail,
        taxRegime,
        legalNature,
        companySize,
        mainCnae,
        mainCnaeDescription,
        municipalCode,
        standardServiceCode,
        certificatePassword,
        responsibleLogin,
        responsiblePassword,
        onboardingMode,
        accountantName,
        accountantEmail,
      },
      accountantName,
      accountantEmail,
      uploads,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    ok: true,
    requestId: requestRef.id,
    status: 'submitted',
  };
});

exports.platformGenerateImplementationCharge = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const requestId = asTrimmedString(data?.requestId);
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId obrigatorio.');
  }

  const requestRef = salesOnboardingRef().doc(requestId);
  const snap = await requestRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Onboarding nao encontrado.');
  }
  const item = asRecord(snap.data());
  const implementationFeeCents =
    data?.implementationFeeCents == null
      ? Number(item.implementationFeeCents ?? 0) || 0
      : parseNonNegativeInt(data.implementationFeeCents, 'implementationFeeCents');
  if (implementationFeeCents <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Onboarding sem valor de implantacao.',
    );
  }

  const charge = await createImplementationChargeForOnboarding({
    requestRef,
    item,
    implementationFeeCents,
  });
  if (charge == null) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Onboarding sem customerId ou sem valor de implantacao.',
    );
  }

  return {
    ok: true,
    requestId,
    paymentId: charge.paymentId,
    invoiceUrl: charge.invoiceUrl,
    dueDate: charge.dueDate,
    valueCents: charge.valueCents,
    status: charge.status,
  };
});

exports.platformFinalizeSalesOnboarding = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const requestId = asTrimmedString(data?.requestId);
  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId obrigatorio.');
  }

  const requestRef = salesOnboardingRef().doc(requestId);
  const snap = await requestRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Onboarding nao encontrado.');
  }

  const item = asRecord(snap.data());
  const status = asTrimmedString(item.status);
  if (!['submitted', 'implementation_completed'].includes(status)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'O onboarding precisa estar enviado para virar empresa operacional.',
    );
  }

  const finalized = await finalizeSalesOnboardingToOperationalCompany({
    requestRef,
    item,
  });
  const refreshedSnap = await requestRef.get();
  const refreshedData = asRecord(refreshedSnap.data());
  let implementationCharge: Awaited<ReturnType<typeof createImplementationChargeForOnboarding>> =
    null;
  let implementationChargeError = '';
  if (asTrimmedString(refreshedData.implementationMode) !== 'accountant') {
    try {
      implementationCharge = await createImplementationChargeForOnboarding({
        requestRef,
        item: refreshedData,
      });
      await requestRef.set(
        {
          implementationChargeAutomationError: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    } catch (error) {
      implementationChargeError =
        error instanceof Error ? error.message : 'Falha ao gerar boleto automatico da implantacao.';
      await requestRef.set(
        {
          implementationChargeAutomationError: implementationChargeError,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }
  if (finalized.companyId) {
    await admin
      .firestore()
      .collection('company_settings')
      .doc(finalized.companyId)
      .collection('implementation_records')
      .doc('current')
      .set(
        {
          implementationCharge:
            implementationCharge == null
              ? admin.firestore.FieldValue.delete()
              : {
                  paymentId: implementationCharge.paymentId,
                  invoiceUrl: implementationCharge.invoiceUrl,
                  dueDate: implementationCharge.dueDate,
                  valueCents: implementationCharge.valueCents,
                  status: implementationCharge.status,
                },
          implementationChargeAutomationError:
            implementationChargeError || admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
  }

  return {
    ok: true,
    requestId,
    companyId: finalized.companyId,
    ownerUid: finalized.ownerUid,
    ownerEmail: finalized.ownerEmail,
    companyName: finalized.companyName,
    implementationCharge:
      implementationCharge == null
        ? null
        : {
            paymentId: implementationCharge.paymentId,
            invoiceUrl: implementationCharge.invoiceUrl,
            dueDate: implementationCharge.dueDate,
            valueCents: implementationCharge.valueCents,
            status: implementationCharge.status,
          },
    implementationChargeError,
  };
});

exports.platformUpdateCompanyCommercialSettings = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const beforeSnap = await settingsRef.get();
  const beforeData = asRecord(beforeSnap.data());
  const currentCommercialRaw = commercialSettings(beforeData);
  const currentCommercial = buildDefaultCommercialSettings(beforeData);
  const currentBilling = asRecord(currentCommercial.billingIntegration);
  const currentPlan = asTrimmedString(currentCommercial.plan).toLowerCase() === 'equipe'
    ? 'equipe'
    : 'solo';
  const requestedPlan = (() => {
    const rawPlan = asTrimmedString(data?.plan || currentCommercial.plan).toLowerCase();
    return rawPlan === 'equipe' ? 'equipe' : 'solo';
  })();
  const currentPlanUpgrade = asRecord(currentCommercialRaw.planUpgrade);

  if (currentPlan === 'equipe' && requestedPlan === 'solo') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Empresa ja enquadrada no plano Equipe nao pode voltar para Solo.',
    );
  }

  if (currentPlan === 'solo' && requestedPlan === 'equipe') {
    const upgradeStatus = asTrimmedString(currentPlanUpgrade.status).toLowerCase();
    const upgradePaid = ['paid', 'confirmed', 'received'].includes(upgradeStatus);
    if (!upgradePaid) {
      if (data?.acknowledgePlanUpgradeCharge !== true) {
        return {
          ok: false,
          companyId,
          upgradeChargeRequired: true,
          message:
            'Migrar de Solo para Equipe exige cobranca de aquisicao. Confirme a geracao da cobranca antes de alterar o plano.',
        };
      }

      const companyData = asRecord(beforeData.companyData);
      const charge = await createOrRefreshPlanUpgradeCharge({
        companyId,
        companyData,
        currentCommercial,
        currentPlanUpgrade,
      });
      await settingsRef.set(
        {
          companyId,
          commercialSettings: {
            ...currentCommercialRaw,
            planUpgrade: {
              currentPlan: 'solo',
              targetPlan: 'equipe',
              status: charge.status,
              paymentId: charge.paymentId,
              paymentLinkUrl: charge.paymentLinkUrl,
              dueDate: charge.dueDate,
              amountCents: charge.amountCents,
              externalReference: charge.externalReference,
              requestedAt: admin.firestore.FieldValue.serverTimestamp(),
              requestedByPlatformUid: claims.uid,
            },
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      return {
        ok: false,
        companyId,
        upgradeChargeRequired: true,
        paymentLinkUrl: charge.paymentLinkUrl,
        amountCents: charge.amountCents,
        message:
          'Cobranca de aquisicao gerada. O plano Equipe so pode ser aplicado apos o pagamento.',
      };
    }
  }

  const requestedBillingProvider =
    asTrimmedString(data?.billingProvider) ||
    asTrimmedString(currentBilling.provider) ||
    'manual';
  const requestedBillingAccessManaged =
    data?.billingAccessManagedByGateway == null
      ? currentBilling.accessManagedByGateway === true
      : data.billingAccessManagedByGateway === true;
  const requestedBillingGatewayStatus =
    asTrimmedString(data?.billingGatewayStatus) ||
    asTrimmedString(currentBilling.status) ||
    'pending_setup';
  const requestedCommercialBillingStatus =
    asTrimmedString(data?.billingStatus) || currentCommercial.billingStatus;
  const effectiveBillingStatus =
    requestedBillingAccessManaged && requestedBillingProvider !== 'manual'
      ? requestedBillingGatewayStatus
      : requestedCommercialBillingStatus;

  const afterCommercial = {
    ...currentCommercial,
    plan: requestedPlan,
    businessTier:
      requestedPlan === 'equipe' ? 'empresa' : 'mei',
    lifecycleStatus:
      asTrimmedString(data?.lifecycleStatus) || currentCommercial.lifecycleStatus,
    billingStatus: effectiveBillingStatus,
    approvalStatus:
      asTrimmedString(data?.approvalStatus) || currentCommercial.approvalStatus,
    allowLogin:
      data?.allowLogin == null
        ? currentCommercial.allowLogin
        : data.allowLogin === true,
    requiresApproval:
      data?.requiresApproval == null
        ? currentCommercial.requiresApproval
        : data.requiresApproval === true,
    seatsIncluded:
      data?.seatsIncluded == null
        ? currentCommercial.seatsIncluded
        : parseNonNegativeInt(data.seatsIncluded, 'seatsIncluded'),
    contractedAppUsers:
      data?.contractedAppUsers == null
        ? currentCommercial.contractedAppUsers
        : parseNonNegativeInt(data.contractedAppUsers, 'contractedAppUsers'),
    baseSystemPriceCents:
      data?.baseSystemPriceCents == null
        ? currentCommercial.baseSystemPriceCents
        : parseNonNegativeInt(data.baseSystemPriceCents, 'baseSystemPriceCents'),
    extraAppUserPriceCents:
      data?.extraAppUserPriceCents == null
        ? currentCommercial.extraAppUserPriceCents
        : parseNonNegativeInt(data.extraAppUserPriceCents, 'extraAppUserPriceCents'),
    monthlyPriceCents:
      data?.monthlyPriceCents == null
        ? currentCommercial.monthlyPriceCents
        : parseNonNegativeInt(data.monthlyPriceCents, 'monthlyPriceCents'),
    pricingModel:
      asTrimmedString(data?.pricingModel) || currentCommercial.pricingModel,
    billingIntegration: {
      ...currentBilling,
      provider: requestedBillingProvider,
      accessManagedByGateway: requestedBillingAccessManaged,
      billingType:
        asTrimmedString(data?.billingType) ||
        asTrimmedString(currentBilling.billingType) ||
        'BOLETO',
      cycle:
        asTrimmedString(data?.billingCycle) ||
        asTrimmedString(currentBilling.cycle) ||
        'MONTHLY',
      customerId:
        asTrimmedString(data?.billingCustomerId) ||
        asTrimmedString(currentBilling.customerId),
      subscriptionId:
        asTrimmedString(data?.billingSubscriptionId) ||
        asTrimmedString(currentBilling.subscriptionId),
      paymentLinkUrl:
        asTrimmedString(data?.billingPaymentLinkUrl) ||
        asTrimmedString(currentBilling.paymentLinkUrl),
      checkoutUrl:
        asTrimmedString(data?.billingCheckoutUrl) ||
        asTrimmedString(currentBilling.checkoutUrl),
      externalReference:
        asTrimmedString(data?.billingExternalReference) ||
        asTrimmedString(currentBilling.externalReference) ||
        companyId,
      status: requestedBillingAccessManaged && requestedBillingProvider !== 'manual'
        ? requestedBillingGatewayStatus
        : effectiveBillingStatus,
      graceDays:
        data?.billingGraceDays == null
          ? (() => {
              const currentGraceDays = Number(currentBilling.graceDays);
              return Number.isFinite(currentGraceDays) && currentGraceDays >= 0
                ? Math.trunc(currentGraceDays)
                : 3;
            })()
          : parseNonNegativeInt(data.billingGraceDays, 'billingGraceDays'),
      graceUntil:
        data?.billingGraceUntil == null
          ? currentBilling.graceUntil ?? null
          : parseOptionalDate(data.billingGraceUntil, 'billingGraceUntil'),
      currentPeriodEnd:
        data?.billingCurrentPeriodEnd == null
          ? currentBilling.currentPeriodEnd ?? null
          : parseOptionalDate(data.billingCurrentPeriodEnd, 'billingCurrentPeriodEnd'),
      lastPaymentAt:
        data?.billingLastPaymentAt == null
          ? currentBilling.lastPaymentAt ?? null
          : parseOptionalDate(data.billingLastPaymentAt, 'billingLastPaymentAt'),
      lastPaymentId:
        asTrimmedString(data?.billingLastPaymentId) ||
        asTrimmedString(currentBilling.lastPaymentId),
      lastPaymentStatus:
        asTrimmedString(data?.billingLastPaymentStatus) ||
        asTrimmedString(currentBilling.lastPaymentStatus),
      lastWebhookEventId:
        asTrimmedString(data?.billingLastWebhookEventId) ||
        asTrimmedString(currentBilling.lastWebhookEventId),
      lastWebhookEvent:
        asTrimmedString(data?.billingLastWebhookEvent) ||
        asTrimmedString(currentBilling.lastWebhookEvent),
      lastWebhookAt:
        data?.billingLastWebhookAt == null
          ? currentBilling.lastWebhookAt ?? null
          : parseOptionalDate(data.billingLastWebhookAt, 'billingLastWebhookAt'),
      delinquencyStartedAt:
        data?.billingDelinquencyStartedAt == null
          ? currentBilling.delinquencyStartedAt ?? null
          : parseOptionalDate(data.billingDelinquencyStartedAt, 'billingDelinquencyStartedAt'),
      blockReason:
        asTrimmedString(data?.billingBlockReason) ||
        asTrimmedString(currentBilling.blockReason),
      webhookReady:
        data?.billingWebhookReady == null
          ? currentBilling.webhookReady === true
          : data.billingWebhookReady === true,
    },
    platformNote: asTrimmedString(data?.platformNote),
    calculatedMonthlyPriceCents:
      Number(currentCommercial.calculatedMonthlyPriceCents ?? currentCommercial.monthlyPriceCents ?? 0) ||
      0,
    planUpgrade:
      currentPlan === 'solo' && requestedPlan === 'equipe'
        ? {
            ...currentPlanUpgrade,
            status: 'paid',
            targetPlan: 'equipe',
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            appliedByPlatformUid: claims.uid,
          }
        : currentPlanUpgrade,
    updatedByPlatformAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedByPlatformUid: claims.uid,
  };
  const additionalAppUsers = Math.max(
    0,
    Number(afterCommercial.contractedAppUsers ?? 0) -
      Number(afterCommercial.seatsIncluded ?? 0),
  );
  const calculatedMonthlyPriceCents =
    Number(afterCommercial.baseSystemPriceCents ?? 0) +
    additionalAppUsers * Number(afterCommercial.extraAppUserPriceCents ?? 0);
  afterCommercial.calculatedMonthlyPriceCents = calculatedMonthlyPriceCents;
  if (data?.monthlyPriceCents == null) {
    afterCommercial.monthlyPriceCents = calculatedMonthlyPriceCents;
  }
  afterCommercial.billingIntegration = (await syncAsaasSubscriptionForCommercialSettings({
    commercial: afterCommercial,
    companyId,
  })) as typeof afterCommercial.billingIntegration;

  await settingsRef.set(
    {
      companyId,
      commercialSettings: afterCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'update_company_commercial_settings',
    entityPath: 'company_settings',
    entityId: companyId,
    before: { commercialSettings: commercialSettings(beforeData) },
    after: { commercialSettings: afterCommercial },
  });

  return {
    ok: true,
    companyId,
    commercialSettings: afterCommercial,
  };
});

exports.platformProvisionCompanyBillingAsaas = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const cfg = assertAsaasConfigured();
  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const billingType = asaasBillingType(data?.billingType);
  const cycle = asaasSubscriptionCycle(data?.cycle);
  const nextDueDate = parseOptionalDate(
    data?.nextDueDate || toIsoDateString(new Date(Date.now() + 24 * 60 * 60 * 1000)),
    'nextDueDate',
  );
  if (nextDueDate == null) {
    throw new functions.https.HttpsError('invalid-argument', 'nextDueDate obrigatorio.');
  }

  const owner = await carregarOwnerDaEmpresa(companyId);
  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const currentCommercial = buildDefaultCommercialSettings(settingsData);
  const currentBilling = asRecord(currentCommercial.billingIntegration);
  const companyData = asRecord(settingsData.companyData);
  const externalReference =
    asTrimmedString(data?.externalReference) ||
    asTrimmedString(currentBilling.externalReference) ||
    companyId;
  const description =
    asTrimmedString(data?.description) ||
    `Plano ${asTrimmedString(currentCommercial.plan)} | ${companyId}`;
  const monthlyValue = toAsaasMoneyValue(currentCommercial.monthlyPriceCents);

  let customerId = asTrimmedString(currentBilling.customerId);
  if (!customerId) {
    const customerPayload = buildAsaasCustomerPayload({ owner, companyData });
    const customerResult = await asaasRequest(cfg, '/customers', {
      method: 'POST',
      body: customerPayload,
    });
    customerId = asTrimmedString(customerResult.id);
    if (!customerId) {
      throw new functions.https.HttpsError(
        'internal',
        'Asaas nao retornou customerId ao criar cliente.',
      );
    }
  }

  let subscriptionId = asTrimmedString(currentBilling.subscriptionId);
  let subscriptionPayload: Record<string, unknown> = {
    customer: customerId,
    billingType,
    value: monthlyValue,
    nextDueDate: toIsoDateString(nextDueDate.toDate()),
    cycle,
    description,
    externalReference,
  };
  let subscriptionResult: Record<string, unknown>;
  if (subscriptionId) {
    subscriptionResult = await asaasRequest(
      cfg,
      `/subscriptions/${encodeURIComponent(subscriptionId)}`,
      {
        method: 'PUT',
        body: {
          ...subscriptionPayload,
          updatePendingPayments: true,
        },
      },
    );
  } else {
    subscriptionResult = await asaasRequest(cfg, '/subscriptions', {
      method: 'POST',
      body: subscriptionPayload,
    });
    subscriptionId = asTrimmedString(subscriptionResult.id);
  }

  let paymentLinkUrl = asTrimmedString(currentBilling.paymentLinkUrl);
  try {
    if (subscriptionId) {
      const paymentsResult = await asaasRequest(
        cfg,
        `/subscriptions/${encodeURIComponent(subscriptionId)}/payments`,
      );
      const first = Array.isArray(paymentsResult.data) && paymentsResult.data.length > 0
        ? asRecord(paymentsResult.data[0])
        : {};
      paymentLinkUrl =
        asTrimmedString(first.invoiceUrl) ||
        asTrimmedString(first.bankSlipUrl) ||
        asTrimmedString(first.transactionReceiptUrl) ||
        paymentLinkUrl;
    }
  } catch (_) {
    // Melhor esforco; a assinatura ja foi criada/atualizada.
  }

  const providerStatus =
    asTrimmedString(subscriptionResult.status).toLowerCase() || 'pending_payment';
  const afterCommercial = {
    ...currentCommercial,
    billingStatus:
      providerStatus == 'active' || providerStatus == 'paid'
        ? 'paid'
        : providerStatus,
    billingIntegration: {
      ...currentBilling,
      provider: 'asaas',
      accessManagedByGateway: true,
      billingType,
      cycle,
      customerId,
      subscriptionId,
      paymentLinkUrl,
      checkoutUrl: paymentLinkUrl,
      externalReference,
      status: providerStatus,
      graceDays:
        data?.graceDays == null
          ? Number(currentBilling.graceDays ?? 3) || 3
          : parseNonNegativeInt(data.graceDays, 'graceDays'),
      currentPeriodEnd:
        parseTimestampLike(subscriptionResult.nextDueDate) ?? currentBilling.currentPeriodEnd ?? null,
      blockReason: '',
      webhookReady: true,
    },
    updatedByPlatformAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedByPlatformUid: claims.uid,
  };

  await settingsRef.set(
    {
      companyId,
      commercialSettings: afterCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'platform',
    action: 'provision_company_billing_asaas',
    entityPath: 'company_settings',
    entityId: companyId,
    before: { commercialSettings: commercialSettings(settingsData) },
    after: {
      commercialSettings: afterCommercial,
      asaas: {
        customerId,
        subscriptionId,
        paymentLinkUrl,
        billingType,
        cycle,
      },
    },
  });

  return {
    ok: true,
    companyId,
    provider: 'asaas',
    customerId,
    subscriptionId,
    paymentLinkUrl,
    billingType,
    cycle,
    nextDueDate: toIsoDateString(nextDueDate.toDate()),
  };
});

exports.platformIssueCompanyActivationCode = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  assertPlatformAdmin(claims, userProfile);

  const companyId = asTrimmedString(data?.companyId);
  if (!companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId obrigatorio.');
  }

  const expiresInDays = data?.expiresInDays == null
    ? 30
    : parseNonNegativeInt(data.expiresInDays, 'expiresInDays');
  if (expiresInDays <= 0 || expiresInDays > 365) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'expiresInDays deve ficar entre 1 e 365.',
    );
  }

  const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
  const settingsSnap = await settingsRef.get();
  const beforeData = asRecord(settingsSnap.data());
  const currentCommercial = buildDefaultCommercialSettings(beforeData);
  const code = generateActivationCode();
  const codeHash = hashActivationCode(code);
  const codeLast4 = activationCodeLast4(code);
  const codeRef = admin.firestore().collection('company_activation_codes').doc();
  const now = Date.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now + expiresInDays * 24 * 60 * 60 * 1000,
  );

  const existingIssued = await admin
    .firestore()
    .collection('company_activation_codes')
    .where('companyId', '==', companyId)
    .where('status', '==', 'issued')
    .get();

  const batch = admin.firestore().batch();
  for (const doc of existingIssued.docs) {
    batch.set(
      doc.ref,
      {
        status: 'revoked',
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        revokedByPlatformUid: claims.uid,
        revokedReason: 'Superseded by a newer activation code.',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  batch.set(codeRef, {
    companyId,
    purpose: 'company_access_release',
    status: 'issued',
    codeHash,
    codeLast4,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdByPlatformUid: claims.uid,
  });

  const afterCommercial = {
    ...currentCommercial,
    accessControlMode: 'activation_code',
    activationRequired: true,
    activationStatus: 'code_issued',
    activationCodeLast4: codeLast4,
    activationCodeIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
    activationCodeExpiresAt: expiresAt,
    activationReleasedAt: currentCommercial.activationReleasedAt ?? null,
    activationReleasedByCodeId: asTrimmedString(currentCommercial.activationReleasedByCodeId) || '',
    updatedByPlatformAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedByPlatformUid: claims.uid,
  };

  batch.set(
    settingsRef,
    {
      companyId,
      commercialSettings: afterCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await batch.commit();

  await writeAudit({
    claims,
    module: 'platform',
    action: 'issue_company_activation_code',
    entityPath: 'company_activation_codes',
    entityId: codeRef.id,
    before: { commercialSettings: commercialSettings(beforeData) },
    after: {
      companyId,
      codeId: codeRef.id,
      codeLast4,
      expiresInDays,
      commercialSettings: {
        accessControlMode: 'activation_code',
        activationRequired: true,
        activationStatus: 'code_issued',
      },
    },
  });

  return {
    ok: true,
    companyId,
    codeId: codeRef.id,
    code,
    codeLast4,
    expiresAt: expiresAt.toDate().toISOString(),
  };
});

exports.redeemCompanyActivationCode = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const code = asTrimmedString(data?.code);
  if (!code) {
    throw new functions.https.HttpsError('invalid-argument', 'Codigo obrigatorio.');
  }

  const codeHash = hashActivationCode(code);
  const codesSnap = await admin
    .firestore()
    .collection('company_activation_codes')
    .where('companyId', '==', claims.companyId)
    .where('codeHash', '==', codeHash)
    .limit(1)
    .get();

  if (codesSnap.empty) {
    throw new functions.https.HttpsError('not-found', 'Codigo de liberacao invalido.');
  }

  const codeRef = codesSnap.docs[0].ref;
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);

  await admin.firestore().runTransaction(async (tx) => {
    const [codeSnap, settingsSnap] = await Promise.all([tx.get(codeRef), tx.get(settingsRef)]);
    const codeData = asRecord(codeSnap.data());
    const settingsData = asRecord(settingsSnap.data());
    const commercial = buildDefaultCommercialSettings(settingsData);
    const status = asTrimmedString(codeData.status) || 'issued';
    const expiresAtRaw = codeData.expiresAt;
    const expiresAt = expiresAtRaw instanceof admin.firestore.Timestamp
      ? expiresAtRaw.toMillis()
      : 0;

    if (status === 'redeemed') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Este codigo ja foi utilizado.',
      );
    }
    if (status !== 'issued') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Este codigo nao esta disponivel para uso.',
      );
    }
    if (expiresAt > 0 && expiresAt < Date.now()) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Este codigo expirou. Solicite um novo codigo a plataforma.',
      );
    }

    tx.set(
      codeRef,
      {
        status: 'redeemed',
        redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
        redeemedByUid: claims.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(
      settingsRef,
      {
        companyId: claims.companyId,
        commercialSettings: {
          ...commercial,
          accessControlMode: 'activation_code',
          activationRequired: true,
          activationStatus: 'released',
          activationCodeLast4: asTrimmedString(codeData.codeLast4),
          activationReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
          activationReleasedByCodeId: codeRef.id,
          allowLogin: true,
          updatedByPlatformAt: commercial.updatedByPlatformAt ?? null,
          updatedByPlatformUid: commercial.updatedByPlatformUid ?? null,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAudit({
      claims,
      module: 'auth',
      action: 'redeem_company_activation_code',
      entityPath: 'company_activation_codes',
      entityId: codeRef.id,
      before: {
        status,
        companyId: claims.companyId,
        activationStatus: asTrimmedString(commercial.activationStatus),
      },
      after: {
        status: 'redeemed',
        companyId: claims.companyId,
        activationStatus: 'released',
      },
      tx,
    });
  });

  return {
    ok: true,
    companyId: claims.companyId,
    activationStatus: 'released',
  };
});

exports.companyGetBillingManagementSnapshot = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const cfg = assertAsaasConfigured();
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const commercial = buildDefaultCommercialSettings(settingsData);
  const billing = asRecord(commercial.billingIntegration);
  const subscriptionId = asTrimmedString(billing.subscriptionId);

  if (asTrimmedString(billing.provider).toLowerCase() !== 'asaas' || !subscriptionId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A empresa ainda nao possui assinatura Asaas ativa para gestao.',
    );
  }

  const paymentsResult = await asaasRequest(
    cfg,
    `/subscriptions/${encodeURIComponent(subscriptionId)}/payments`,
  );
  const payments = Array.isArray(paymentsResult.data)
    ? paymentsResult.data.map((item) => asRecord(item))
    : [];
  const selectedPayment = selectAsaasRenewalPayment(payments);
  const renewalUrl =
    primaryAsaasPaymentUrl(selectedPayment) ||
    asTrimmedString(billing.paymentLinkUrl) ||
    asTrimmedString(billing.checkoutUrl);

  const nextBilling = {
    ...billing,
    paymentLinkUrl: renewalUrl || asTrimmedString(billing.paymentLinkUrl),
    checkoutUrl: renewalUrl || asTrimmedString(billing.checkoutUrl),
    lastPaymentId: asTrimmedString(selectedPayment.id) || asTrimmedString(billing.lastPaymentId),
    lastPaymentStatus:
      asTrimmedString(selectedPayment.status).toLowerCase() ||
      asTrimmedString(billing.lastPaymentStatus),
    lastPaymentAt:
      parseTimestampLike(selectedPayment.clientPaymentDate) ??
      billing.lastPaymentAt ??
      null,
    currentPeriodEnd:
      parseTimestampLike(selectedPayment.dueDate) ??
      billing.currentPeriodEnd ??
      null,
  };

  await settingsRef.set(
    {
      companyId: claims.companyId,
      commercialSettings: {
        ...commercial,
        billingIntegration: nextBilling,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    ok: true,
    companyId: claims.companyId,
    renewalUrl,
    paymentId: asTrimmedString(selectedPayment.id),
    paymentStatus: asTrimmedString(selectedPayment.status).toLowerCase(),
    dueDate: asTrimmedString(selectedPayment.dueDate),
    canCancel: true,
    contractedAppUsers: Number(commercial.contractedAppUsers ?? 0) || 0,
    seatsIncluded: Number(commercial.seatsIncluded ?? 0) || 0,
    monthlyPriceCents: Number(commercial.monthlyPriceCents ?? 0) || 0,
  };
});

exports.companyUpdateAdditionalAppAccess = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const currentCommercial = buildDefaultCommercialSettings(settingsData);
  const currentBilling = asRecord(currentCommercial.billingIntegration);
  const seatsIncluded = Number(currentCommercial.seatsIncluded ?? 0) || 0;
  const currentContracted = Number(currentCommercial.contractedAppUsers ?? seatsIncluded) || seatsIncluded;
  const requestedContracted = parseNonNegativeInt(
    data?.contractedAppUsers ?? currentContracted,
    'contractedAppUsers',
  );
  const contractedAppUsers = Math.max(seatsIncluded, requestedContracted);
  const additionalAppUsers = Math.max(0, contractedAppUsers - seatsIncluded);
  const monthlyPriceCents =
    (Number(currentCommercial.baseSystemPriceCents ?? 0) || 0) +
    additionalAppUsers * (Number(currentCommercial.extraAppUserPriceCents ?? 0) || 0);

  const nextCommercial: Record<string, unknown> = {
    ...currentCommercial,
    contractedAppUsers,
    monthlyPriceCents,
    calculatedMonthlyPriceCents: monthlyPriceCents,
    updatedByPlatformAt: currentCommercial.updatedByPlatformAt ?? null,
    updatedByPlatformUid: currentCommercial.updatedByPlatformUid ?? null,
  };

  nextCommercial.billingIntegration = buildDefaultBillingIntegration(nextCommercial);
  if (
    asTrimmedString(currentBilling.provider).toLowerCase() === 'asaas' &&
    asTrimmedString(currentBilling.subscriptionId)
  ) {
    nextCommercial.billingIntegration = (await syncAsaasSubscriptionForCommercialSettings({
      commercial: nextCommercial,
      companyId: claims.companyId,
    })) as typeof nextCommercial.billingIntegration;
  }

  await settingsRef.set(
    {
      companyId: claims.companyId,
      commercialSettings: nextCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'billing',
    action: 'company_update_additional_app_access',
    entityPath: 'company_settings',
    entityId: claims.companyId,
    before: {
      contractedAppUsers: currentContracted,
      monthlyPriceCents: Number(currentCommercial.monthlyPriceCents ?? 0) || 0,
    },
    after: {
      contractedAppUsers,
      monthlyPriceCents,
      additionalAppUsers,
    },
  });

  return {
    ok: true,
    companyId: claims.companyId,
    contractedAppUsers,
    additionalAppUsers,
    monthlyPriceCents,
    paymentLinkUrl: asTrimmedString(asRecord(nextCommercial.billingIntegration).paymentLinkUrl),
  };
});

exports.companyCancelBillingSubscription = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  if (isSupremePlatformCompany(claims.companyId)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'A empresa suprema da plataforma nao utiliza cancelamento de assinatura por este fluxo.',
    );
  }

  const cfg = assertAsaasConfigured();
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = asRecord(settingsSnap.data());
  const currentCommercial = buildDefaultCommercialSettings(settingsData);
  const currentBilling = asRecord(currentCommercial.billingIntegration);
  const subscriptionId = asTrimmedString(currentBilling.subscriptionId);

  if (asTrimmedString(currentBilling.provider).toLowerCase() !== 'asaas' || !subscriptionId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A empresa nao possui assinatura Asaas para cancelamento.',
    );
  }

  await asaasRequest(cfg, `/subscriptions/${encodeURIComponent(subscriptionId)}`, {
    method: 'DELETE',
  });

  const canceledAt = admin.firestore.Timestamp.now();
  const accessUntil = nextCancellationAccessDeadline(currentBilling);
  const reason = asTrimmedString(data?.reason) || 'Cancelamento solicitado pela empresa.';
  const nextBilling = {
    ...currentBilling,
    status: 'canceled',
    blockReason: `Plano cancelado. O acesso fica liberado ate ${toIsoDateString(accessUntil.toDate())}.`,
    graceUntil: accessUntil,
    lastWebhookEvent: 'subscription.deleted',
    lastWebhookAt: canceledAt,
  };
  const nextCommercial = {
    ...currentCommercial,
    billingStatus: 'canceled',
    billingIntegration: nextBilling,
    platformNote: reason,
    updatedByPlatformAt: currentCommercial.updatedByPlatformAt ?? null,
    updatedByPlatformUid: currentCommercial.updatedByPlatformUid ?? null,
  };

  await settingsRef.set(
    {
      companyId: claims.companyId,
      commercialSettings: nextCommercial,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'billing',
    action: 'company_cancel_billing_subscription',
    entityPath: 'company_settings',
    entityId: claims.companyId,
    before: {
      subscriptionId,
      billingStatus: asTrimmedString(currentCommercial.billingStatus),
      currentPeriodEnd: timestampToIsoString(currentBilling.currentPeriodEnd),
    },
    after: {
      subscriptionId,
      billingStatus: 'canceled',
      accessUntil: accessUntil.toDate().toISOString(),
      reason,
    },
  });

  return {
    ok: true,
    companyId: claims.companyId,
    subscriptionId,
    accessUntil: accessUntil.toDate().toISOString(),
    status: 'canceled',
  };
});

exports.asaasWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method === 'GET') {
    res.status(200).json({ ok: true, endpoint: 'asaasWebhook' });
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method-not-allowed' });
    return;
  }

  try {
    const expectedToken = ASAAS_WEBHOOK_TOKEN.value().trim();
    if (expectedToken) {
      const receivedToken = webhookTokenFromRequest(req);
      if (!receivedToken || receivedToken !== expectedToken) {
        res.status(401).json({ ok: false, error: 'invalid-webhook-token' });
        return;
      }
    }

    const payload = asRecord(typeof req.body === 'string' ? JSON.parse(req.body) : req.body);
    const eventId = asTrimmedString(payload.id);
    const eventName = asTrimmedString(payload.event);
    if (!eventId || !eventName) {
      res.status(400).json({ ok: false, error: 'invalid-payload' });
      return;
    }

    const eventRef = admin.firestore().collection('billing_webhook_events').doc(`asaas_${eventId}`);
    const existing = await eventRef.get();
    if (existing.exists) {
      res.status(200).json({ ok: true, duplicate: true });
      return;
    }

    const companyId = await resolveCompanyIdFromAsaasPayload(payload);
    if (!companyId) {
      const payment = asaasEventPaymentData(payload);
      const publicOnboarding =
        eventName === 'PAYMENT_CREATED' ||
        eventName === 'PAYMENT_UPDATED' ||
        eventName === 'PAYMENT_CONFIRMED' ||
        eventName === 'PAYMENT_RECEIVED'
          ? await createOrRefreshPublicSalesOnboarding({
              cfg: assertAsaasConfigured(),
              payment,
              eventId,
              eventName,
            })
          : null;
      await eventRef.set({
        provider: 'asaas',
        eventId,
        eventName,
        status: publicOnboarding == null ? 'unmatched' : 'public-sales-onboarding',
        payload,
        onboardingRequestId: publicOnboarding?.requestId ?? '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(202).json({
        ok: true,
        unmatched: publicOnboarding == null,
        publicSalesOnboarding: publicOnboarding != null,
      });
      return;
    }

    const settingsRef = admin.firestore().collection('company_settings').doc(companyId);
    await admin.firestore().runTransaction(async (tx) => {
      const settingsSnap = await tx.get(settingsRef);
      const settingsData = asRecord(settingsSnap.data());
      const currentCommercialRaw = commercialSettings(settingsData);
      const currentCommercial = buildDefaultCommercialSettings(settingsData);
      const currentBilling = asRecord(currentCommercial.billingIntegration);
      const currentPlanUpgrade = asRecord(currentCommercialRaw.planUpgrade);
      const payment = asaasEventPaymentData(payload);
      const paymentExternalReference = asTrimmedString(payment.externalReference);
      const statusResult = billingStatusFromAsaasEvent(eventName, payment);
      const graceDays = Number(currentBilling.graceDays ?? 3) || 3;
      const nowTs = admin.firestore.Timestamp.now();
      const paymentAt =
        parseTimestampLike(
          payment.clientPaymentDate ||
            payment.paymentDate ||
            payment.confirmedDate ||
            payload.dateCreated,
        ) ?? nowTs;
      const dueAt =
        parseTimestampLike(payment.dueDate || payment.originalDueDate) ?? null;
      const delinquencyStartedAt =
        statusResult.markPaid
          ? null
          : currentBilling.delinquencyStartedAt ?? nowTs;
      const graceUntil =
        statusResult.markPaid
          ? null
          : graceDays > 0
            ? admin.firestore.Timestamp.fromMillis(
                nowTs.toMillis() + graceDays * 24 * 60 * 60 * 1000,
              )
            : null;

      const nextBilling = {
        ...currentBilling,
        provider: 'asaas',
        webhookReady: true,
        status: statusResult.markPaid
          ? 'paid'
          : statusResult.status === 'overdue' || statusResult.status === 'delinquent'
            ? statusResult.status
            : 'pending_payment',
        customerId:
          asTrimmedString(payment.customer) || asTrimmedString(currentBilling.customerId),
        subscriptionId:
          asTrimmedString(payment.subscription) || asTrimmedString(currentBilling.subscriptionId),
        externalReference:
          asTrimmedString(payment.externalReference) ||
          asTrimmedString(currentBilling.externalReference) ||
          companyId,
        currentPeriodEnd: dueAt ?? currentBilling.currentPeriodEnd ?? null,
        lastPaymentAt: statusResult.markPaid ? paymentAt : currentBilling.lastPaymentAt ?? null,
        lastPaymentId: asTrimmedString(payment.id) || asTrimmedString(currentBilling.lastPaymentId),
        lastPaymentStatus:
          asTrimmedString(payment.status) ||
          (statusResult.markPaid ? 'RECEIVED' : asTrimmedString(currentBilling.lastPaymentStatus)),
        lastWebhookEventId: eventId,
        lastWebhookEvent: eventName,
        lastWebhookAt: nowTs,
        delinquencyStartedAt,
        graceUntil,
        blockReason: statusResult.markPaid ? '' : statusResult.blockReason,
      };

      const nextCommercial = {
        ...currentCommercial,
        billingStatus: statusResult.markPaid ? 'paid' : statusResult.status,
        billingIntegration: nextBilling,
        planUpgrade:
          paymentExternalReference === `plan_upgrade_${companyId}_solo_to_equipe`
            ? {
                ...currentPlanUpgrade,
                currentPlan: 'solo',
                targetPlan: 'equipe',
                status: statusResult.markPaid ? 'paid' : nextBilling.status,
                paymentId:
                  asTrimmedString(payment.id) || asTrimmedString(currentPlanUpgrade.paymentId),
                paymentLinkUrl:
                  asTrimmedString(payment.invoiceUrl) ||
                  asTrimmedString(payment.bankSlipUrl) ||
                  asTrimmedString(currentPlanUpgrade.paymentLinkUrl),
                paidAt: statusResult.markPaid ? paymentAt : currentPlanUpgrade.paidAt ?? null,
                lastWebhookEvent: eventName,
                lastWebhookAt: nowTs,
              }
            : currentPlanUpgrade,
      };

      tx.set(
        settingsRef,
        {
          companyId,
          commercialSettings: nextCommercial,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      tx.set(eventRef, {
        provider: 'asaas',
        companyId,
        eventId,
        eventName,
        status: 'processed',
        payload,
        paymentId: asTrimmedString(payment.id),
        paymentStatus: asTrimmedString(payment.status),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    res.status(200).json({ ok: true, companyId, eventId, eventName });
  } catch (error) {
    functions.logger.error('Erro ao processar webhook Asaas.', error);
    res.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : 'internal',
    });
  }
});

exports.createEmployeeAccess = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);

  const nome = String(data?.nome ?? '').trim();
  const email = String(data?.email ?? '').trim().toLowerCase();
  const role = roleParaFirestore(data?.role);

  if (!nome || !email) {
    throw new functions.https.HttpsError('invalid-argument', 'nome e email sao obrigatorios.');
  }

  const emailCfg = obterConfigEmail();
  const missingConfig = missingInviteConfig(emailCfg);
  if (missingConfig.length > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Configuracao de convite incompleta. Defina: ${missingConfig.join(', ')}.`,
    );
  }

  const perfilSolicitante = await carregarUsuario(claims.uid);
  assertCompany(String(perfilSolicitante.companyId ?? ''), claims);

  const companyData = mapCompanyData(perfilSolicitante.companyData);
  const companyName = String(
    perfilSolicitante.companyName ?? companyData?.nomeFantasia ?? '',
  ).trim();

  let userRecord: admin.auth.UserRecord;
  try {
    const senhaTemporaria = gerarSenhaTemporaria();
    userRecord = await admin.auth().createUser({
      email,
      password: senhaTemporaria,
      displayName: nome,
      emailVerified: false,
    });
  } catch (error: unknown) {
    const typed = error as { code?: string };
    if (typed.code === 'auth/email-already-exists') {
      userRecord = await admin.auth().getUserByEmail(email);
    } else {
      throw new functions.https.HttpsError('internal', 'Nao foi possivel criar o usuario no Auth.');
    }
  }

  await admin.firestore().collection('users').doc(userRecord.uid).set(
    {
      companyId: claims.companyId,
      companyName,
      companyData,
      role,
      nome,
      email,
      telefone: null,
      endereco: null,
      apelido: null,
      documento: null,
      pix: null,
      employeeId: userRecord.uid,
      mustChangePassword: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await admin.auth().updateUser(userRecord.uid, { displayName: nome });
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId: claims.companyId,
    role,
    employeeId: userRecord.uid,
  });

  const resetLink = await admin.auth().generatePasswordResetLink(email);
  try {
    try {
      await addTesterToFirebaseAppDistribution({
        email,
        appId: emailCfg.appDistributionAppId,
      });
    } catch (testerError) {
      functions.logger.warn('Falha ao adicionar tester no App Distribution.', {
        email,
        appId: emailCfg.appDistributionAppId,
        error: testerError instanceof Error ? testerError.message : String(testerError),
      });
    }

    await enviarEmailBoasVindasFuncionario({
      email,
      nome,
      nomeEmpresa: companyName,
      resetLink,
      apkUrl: emailCfg.apkUrl,
      fromEmail: emailCfg.fromEmail,
      sendgridKey: emailCfg.sendgridKey,
      smtpUser: emailCfg.smtpUser,
      smtpAppPassword: emailCfg.smtpAppPassword,
    });
  } catch (_) {
    throw new functions.https.HttpsError(
      'internal',
      'Acesso criado, mas falhou o envio do email de acesso. Tente novamente.',
    );
  }

  await writeAudit({
    claims,
    module: 'employees',
    action: 'create_access',
    entityPath: 'users',
    entityId: userRecord.uid,
    before: null,
    after: { role, email },
  });

  return { ok: true, uid: userRecord.uid, emailSent: true };
});

exports.getInviteConfigurationStatus = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);

  const cfg = obterConfigEmail();
  const missing = missingInviteConfig(cfg);
  return {
    configured: missing.length === 0,
    missing,
  };
});

exports.assistantGetCompanyConfigStatus = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const runtimeCfg = await obterConfigAssistantRuntime(claims.companyId);
  const companySecretSnap = await assistantSecretRef(claims.companyId).get();
  const companySecret = asRecord(companySecretSnap.data());

  return {
    source: runtimeCfg.source,
    model: runtimeCfg.model,
    hasCompanyApiKey: !!asTrimmedString(companySecret.apiKey),
    hasPlatformApiKey: !!obterConfigAssistant().apiKey,
    keyPreview: runtimeCfg.source === 'company' ? runtimeCfg.keyPreview : '',
    updatedByName: runtimeCfg.updatedByName ?? '',
    updatedAtIso: runtimeCfg.updatedAtIso ?? '',
  };
});

exports.assistantSaveCompanyApiKey = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER']);

  const apiKey = asTrimmedString(data?.apiKey);
  const remove = data?.remove === true;
  const secretRef = assistantSecretRef(claims.companyId);
  const beforeSnap = await secretRef.get();
  const beforeData = asRecord(beforeSnap.data());
  const userProfile = await carregarUsuarioMesmoTenant(claims.uid, claims);
  const userName = asTrimmedString(userProfile.nome) || 'Owner';

  if (remove) {
    await secretRef.delete();
    await writeAudit({
      claims,
      module: 'assistant',
      action: 'assistant_company_api_key_remove',
      entityPath: 'assistant_secure',
      entityId: claims.companyId,
      before: beforeData,
      after: {
        companyId: claims.companyId,
        keyPreview: '',
        source: 'removed',
      },
    });

    return { ok: true, removed: true };
  }

  if (apiKey.length < 20 || !apiKey.startsWith('sk-')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Informe uma chave valida da OpenAI para a empresa.',
    );
  }

  await secretRef.set(
    {
      companyId: claims.companyId,
      provider: 'openai',
      apiKey,
      keyPreview: maskSecret(apiKey),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedByUid: claims.uid,
      updatedByName: userName,
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'assistant',
    action: 'assistant_company_api_key_save',
    entityPath: 'assistant_secure',
    entityId: claims.companyId,
    before: beforeData,
    after: {
      companyId: claims.companyId,
      provider: 'openai',
      keyPreview: maskSecret(apiKey),
      updatedByUid: claims.uid,
      updatedByName: userName,
    },
  });

  return {
    ok: true,
    removed: false,
    keyPreview: maskSecret(apiKey),
  };
});

exports.runtimeIncidentAnalyze = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertObservabilityAccess(claims);

  const incidentId = asTrimmedString(data?.incidentId);
  if (!incidentId) {
    throw new functions.https.HttpsError('invalid-argument', 'incidentId obrigatorio.');
  }

  const incidentRef = runtimeIncidentRef(incidentId);
  const incidentSnap = await incidentRef.get();
  if (!incidentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Incidente nao encontrado.');
  }

  const incidentData = asRecord(incidentSnap.data());
  assertCompany(asTrimmedString(incidentData.companyId), claims);

  const analysis = analyzeRuntimeIncidentHeuristics(incidentData);
  await incidentRef.set(
    {
      assistantSummary: analysis.summary,
      recommendedAction: analysis.recommendedAction,
      recommendedActionType: analysis.recommendedActionType,
      autoFixEligible: analysis.autoFixEligible,
      humanApprovalRequired: analysis.humanApprovalRequired,
      assistantAnalyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      assistantAnalyzedByUid: claims.uid,
      assistantAnalyzedByRole: claims.role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'runtime_incidents',
    action: 'analyze',
    entityPath: 'runtime_incidents',
    entityId: incidentId,
    before: null,
    after: {
      recommendedActionType: analysis.recommendedActionType,
      autoFixEligible: analysis.autoFixEligible,
    },
  });

  return analysis;
});

exports.runtimeIncidentExecuteSafeAction = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertObservabilityAccess(claims);

  const incidentId = asTrimmedString(data?.incidentId);
  if (!incidentId) {
    throw new functions.https.HttpsError('invalid-argument', 'incidentId obrigatorio.');
  }

  const incidentRef = runtimeIncidentRef(incidentId);
  const incidentSnap = await incidentRef.get();
  if (!incidentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Incidente nao encontrado.');
  }

  const incidentData = asRecord(incidentSnap.data());
  assertCompany(asTrimmedString(incidentData.companyId), claims);

  const analysis = analyzeRuntimeIncidentHeuristics(incidentData);
  if (!analysis.autoFixEligible) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Este incidente ainda nao possui uma acao segura automatizavel.',
    );
  }

  const currentAttempts = parseNonNegativeInt(incidentData.autoFixAttempts ?? 0, 'autoFixAttempts');
  if (analysis.recommendedActionType !== 'refresh_fiscal_provisioning') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'A acao sugerida para este incidente nao possui executor automatico implementado.',
    );
  }

  const userSnap = await admin.firestore().collection('users').doc(claims.uid).get();
  const userData = asRecord(userSnap.data());
  const companyData = mapCompanyData(userData.companyData);
  if (!companyData) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Dados da empresa nao encontrados para reprocessar a automacao fiscal.',
    );
  }

  try {
    const {recommended, focusProvisioning} = await refreshCompanyProvisioningState({
      claims,
      companyData,
    });

    await incidentRef.set(
      {
        assistantSummary: analysis.summary,
        recommendedAction: analysis.recommendedAction,
        recommendedActionType: analysis.recommendedActionType,
        autoFixEligible: analysis.autoFixEligible,
        autoFixStatus: 'executed',
        autoFixAttempts: currentAttempts + 1,
        lastAutoFixAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAutoFixResult: {
          ok: true,
          focusProvisioningStatus: asTrimmedString(focusProvisioning.status),
          focusProvisioningError: asTrimmedString(focusProvisioning.error),
          fiscalRouteType: asTrimmedString(recommended.routing.routeType),
        },
        status: 'resolved',
        resolutionNote:
          'Correcao segura executada: reprocessamento da automacao fiscal da empresa.',
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAudit({
      claims,
      module: 'runtime_incidents',
      action: 'execute_safe_action',
      entityPath: 'runtime_incidents',
      entityId: incidentId,
      before: null,
      after: {
        actionType: analysis.recommendedActionType,
        autoFixStatus: 'executed',
      },
    });

    return {
      ok: true,
      actionType: analysis.recommendedActionType,
      focusProvisioningStatus: asTrimmedString(focusProvisioning.status),
      focusProvisioningError: asTrimmedString(focusProvisioning.error),
    };
  } catch (error: unknown) {
    const message = errorMessage(
      error,
      'Falha ao executar a correcao segura deste incidente.',
    );

    await incidentRef.set(
      {
        assistantSummary: analysis.summary,
        recommendedAction: analysis.recommendedAction,
        recommendedActionType: analysis.recommendedActionType,
        autoFixEligible: analysis.autoFixEligible,
        autoFixStatus: 'failed',
        autoFixAttempts: currentAttempts + 1,
        lastAutoFixAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAutoFixResult: {
          ok: false,
          error: message,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    throw new functions.https.HttpsError('internal', message);
  }
});

exports.runtimeIssueUpsertFromIncident = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertObservabilityAccess(claims);

  const incidentId = asTrimmedString(data?.incidentId);
  if (!incidentId) {
    throw new functions.https.HttpsError('invalid-argument', 'incidentId obrigatorio.');
  }

  const incidentSnap = await runtimeIncidentRef(incidentId).get();
  if (!incidentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Incidente nao encontrado.');
  }

  const incidentData = asRecord(incidentSnap.data());
  assertCompany(asTrimmedString(incidentData.companyId), claims);

  const analysis = analyzeRuntimeIncidentHeuristics(incidentData);
  const fingerprint = buildSystemIssueFingerprint(incidentData);
  const existing = await admin
    .firestore()
    .collection('system_issues')
    .where('companyId', '==', claims.companyId)
    .where('fingerprint', '==', fingerprint)
    .limit(1)
    .get();

  const hasExisting = existing.docs.length > 0;
  const issueRef = hasExisting
    ? existing.docs[0].ref
    : systemIssueRef(admin.firestore().collection('system_issues').doc().id);
  const before = hasExisting ? asRecord(existing.docs[0].data()) : {};
  const occurrenceCount = Number(before.occurrenceCount ?? 0) + 1;
  const status = asTrimmedString(before.status) || 'open';

  await issueRef.set(
    {
      companyId: claims.companyId,
      fingerprint,
      title:
        asTrimmedString(before.title) ||
        `${asTrimmedString(incidentData.category) || 'runtime'} | ${asTrimmedString(incidentData.source) || 'app'}`,
      description:
        asTrimmedString(before.description) || asTrimmedString(incidentData.message),
      module: asTrimmedString(incidentData.category) || 'runtime',
      source: asTrimmedString(incidentData.source) || 'app',
      severity: asTrimmedString(before.severity) || analysis.severity,
      status,
      firstSeenAt: before.firstSeenAt ?? admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      occurrenceCount,
      affectedRoute: asTrimmedString(incidentData.screenLabel),
      affectedUserRole: asTrimmedString(incidentData.reporterRole),
      latestIncidentId: incidentId,
      recommendedAction:
        asTrimmedString(before.recommendedAction) || analysis.recommendedAction,
      recommendedActionType:
        asTrimmedString(before.recommendedActionType) || analysis.recommendedActionType,
      assistantSummary:
        asTrimmedString(before.assistantSummary) || analysis.summary,
      fixStatus: asTrimmedString(before.fixStatus) || 'pending',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: before.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await runtimeIncidentRef(incidentId).set(
    {
      linkedIssueId: issueRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'system_issues',
    action: hasExisting ? 'link_incident' : 'create_from_incident',
    entityPath: 'system_issues',
    entityId: issueRef.id,
    before,
    after: {
      occurrenceCount,
      latestIncidentId: incidentId,
    },
  });

  return {
    ok: true,
    issueId: issueRef.id,
    occurrenceCount,
    created: !hasExisting,
  };
});

exports.runtimeIssueUpdateStatus = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertObservabilityAccess(claims);

  const issueId = asTrimmedString(data?.issueId);
  const status = asTrimmedString(data?.status);
  const fixStatus = asTrimmedString(data?.fixStatus);
  const resolutionNote = asTrimmedString(data?.resolutionNote);

  if (!issueId || !status) {
    throw new functions.https.HttpsError('invalid-argument', 'issueId e status obrigatorios.');
  }

  const issueRef = systemIssueRef(issueId);
  const snap = await issueRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Problema nao encontrado.');
  }

  const before = asRecord(snap.data());
  assertCompany(asTrimmedString(before.companyId), claims);

  await issueRef.set(
    {
      status,
      fixStatus: fixStatus || (status == 'resolved' ? 'done' : 'pending'),
      resolutionNote,
      resolvedAt:
        status == 'resolved'
          ? admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'system_issues',
    action: 'update_status',
    entityPath: 'system_issues',
    entityId: issueId,
    before,
    after: {
      status,
      fixStatus,
      resolutionNote,
    },
  });

  return { ok: true };
});

exports.assistantSendMessage = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT', 'EMPLOYEE']);

  const message = asTrimmedString(data?.message);
  const threadId = asTrimmedString(data?.threadId);
  const route = normalizeAssistantRoute(data?.route) || '/assistant';
  const screenLabel = asTrimmedString(data?.screenLabel).slice(0, 80);

  if (!message) {
    throw new functions.https.HttpsError('invalid-argument', 'message obrigatoria.');
  }

  const assistantCfg = await obterConfigAssistantRuntime(claims.companyId);
  const missingCfg = missingAssistantConfig(assistantCfg);
  if (missingCfg.length > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Assistente nao configurado. Defina: ${missingCfg.join(', ')}.`,
    );
  }

  const [userProfile, settingsSnap] = await Promise.all([
    carregarUsuarioMesmoTenant(claims.uid, claims),
    admin.firestore().collection('company_settings').doc(claims.companyId).get(),
  ]);
  const settingsData = (settingsSnap.data() ?? {}) as Record<string, unknown>;
  assertCanUseAssistant({ claims, settingsData });
  await reserveAssistantBurstQuota(claims);
  const [systemIssuesSummary, runtimeIncidentsSummary] = await Promise.all([
    buildSystemIssuesSummary(claims.companyId),
    isSupremePlatformCompany(claims.companyId)
      ? buildRuntimeIncidentsSummary(claims.companyId)
      : Promise.resolve(''),
  ]);

  let threadRef: FirebaseFirestore.DocumentReference;
  let threadData: Record<string, unknown> = {};

  if (threadId) {
    threadRef = admin.firestore().collection('assistant_threads').doc(threadId);
    const threadSnap = await threadRef.get();
    if (!threadSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Conversa nao encontrada.');
    }
    threadData = (threadSnap.data() ?? {}) as Record<string, unknown>;
    assertCompany(asTrimmedString(threadData.companyId), claims);
  } else {
    threadRef = admin.firestore().collection('assistant_threads').doc();
  }

  const instructions = buildAssistantInstructions({
    claims,
    userProfile,
    companySettings: settingsData,
    route,
    screenLabel,
    systemIssuesSummary,
    runtimeIncidentsSummary,
  });

  const modelResponse = await createOpenAiResponse({
    config: assistantCfg,
    instructions,
    message,
    previousResponseId: asTrimmedString(threadData.lastOpenAiResponseId),
    metadata: {
      companyId: claims.companyId,
      role: claims.role,
      route: route || '/assistant',
    },
  });

  const reply = extractAssistantReply(modelResponse);
  const safeReply = reply || buildAssistantFallbackReply(modelResponse);
  if (!reply) {
    functions.logger.warn('assistantSendMessage returned no usable text', {
      companyId: claims.companyId,
      role: claims.role,
      route: route || '/assistant',
      responseSummary: summarizeAssistantPayloadForLogs(modelResponse),
    });
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const periodKey = currentAssistantPeriodKey();
  const usageData = assistantUsage(settingsData);
  const currentRequestCount =
    asTrimmedString(usageData.periodKey) === periodKey
      ? Number(usageData.requestCount ?? 0)
      : 0;
  const currentTokenCount =
    asTrimmedString(usageData.periodKey) === periodKey
      ? Number(usageData.totalTokens ?? 0)
      : 0;
  const responseUsage = asRecord(modelResponse.usage);
  const totalTokens = Number(responseUsage.total_tokens ?? 0);
  const userName = asTrimmedString(userProfile.nome) || 'Usuario';
  const threadTitle = assistantThreadTitleFromMessage(
    asTrimmedString(threadData.title) || message,
  );
  const messagesRef = threadRef.collection('messages');
  const userMessageRef = messagesRef.doc();
  const assistantMessageRef = messagesRef.doc();
  const isNewThread = !threadId;

  const threadPayload = {
    companyId: claims.companyId,
    createdByUid: asTrimmedString(threadData.createdByUid) || claims.uid,
    createdByName: asTrimmedString(threadData.createdByName) || userName,
    createdByRole: asTrimmedString(threadData.createdByRole) || claims.role,
    memberUids: Array.from(
      new Set(
        [
          ...((Array.isArray(threadData.memberUids)
            ? threadData.memberUids
            : []) as unknown[]).map((item) => asTrimmedString(item)),
          claims.uid,
        ].filter(Boolean),
      ),
    ),
    title: threadTitle,
    lastMessagePreview: safeReply.slice(0, 240),
    lastRoute: route || '/assistant',
    lastScreenLabel: screenLabel,
    lastOpenAiResponseId: asTrimmedString(modelResponse.id),
    updatedAt: now,
    archived: false,
    createdAt: isNewThread ? now : threadData.createdAt ?? now,
  };

  const batch = admin.firestore().batch();
  batch.set(threadRef, threadPayload, { merge: true });
  batch.set(
    admin.firestore().collection('company_settings').doc(claims.companyId),
    {
      companyId: claims.companyId,
      assistantUsage: {
        periodKey,
        requestCount: Math.max(0, currentRequestCount) + 1,
        totalTokens: Math.max(0, currentTokenCount) + (Number.isFinite(totalTokens) ? totalTokens : 0),
        lastRequestAt: now,
        lastRequestBy: claims.uid,
        lastRole: claims.role,
        lastModel: assistantCfg.model,
      },
      updatedAt: now,
    },
    { merge: true },
  );
  batch.set(userMessageRef, {
    companyId: claims.companyId,
    threadId: threadRef.id,
    authorType: 'user',
    authorUid: claims.uid,
    authorName: userName,
    authorRole: claims.role,
    text: message,
    route: route || '/assistant',
    screenLabel,
    createdAt: now,
  });
  batch.set(assistantMessageRef, {
    companyId: claims.companyId,
    threadId: threadRef.id,
    authorType: 'assistant',
    authorUid: 'assistant',
    authorName: 'Assistente Inteligente',
    authorRole: 'ASSISTANT',
    text: safeReply,
    route: route || '/assistant',
    screenLabel,
    provider: 'openai',
    model: assistantCfg.model,
    openAiResponseId: asTrimmedString(modelResponse.id),
    createdAt: now,
  });
  await batch.commit();

  await writeAudit({
    claims,
    module: 'assistant',
    action: 'send_message',
    entityPath: 'assistant_threads',
    entityId: threadRef.id,
    before: null,
    after: {
      route,
      screenLabel,
      model: assistantCfg.model,
    },
  });

  return {
    ok: true,
    threadId: threadRef.id,
    reply: safeReply,
    responseId: asTrimmedString(modelResponse.id),
    model: assistantCfg.model,
  };
});

exports.assistantDebugLatestReplyEphemeral = functions.https.onRequest(async (req, res) => {
  const probeKey = String(req.query.key ?? '').trim();
  if (probeKey !== 'assistant-debug-20260329') {
    res.status(403).json({ ok: false, message: 'forbidden' });
    return;
  }

  const companyId = String(req.query.companyId ?? '').trim();
  if (!isSupremePlatformCompany(companyId)) {
    res.status(403).json({ ok: false, message: 'company_forbidden' });
    return;
  }

  const threadsSnap = await admin
    .firestore()
    .collection('assistant_threads')
    .where('companyId', '==', companyId)
    .get();

  const orderedThreads = [...threadsSnap.docs].sort((a, b) => {
    const aData = asRecord(a.data());
    const bData = asRecord(b.data());
    const aUpdated = aData.updatedAt instanceof admin.firestore.Timestamp
      ? aData.updatedAt.toMillis()
      : 0;
    const bUpdated = bData.updatedAt instanceof admin.firestore.Timestamp
      ? bData.updatedAt.toMillis()
      : 0;
    return bUpdated - aUpdated;
  });

  for (const threadDoc of orderedThreads.slice(0, 10)) {
    const messagesSnap = await threadDoc.ref
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    for (const messageDoc of messagesSnap.docs) {
      const data = asRecord(messageDoc.data());
      if (asTrimmedString(data.authorType) !== 'assistant') continue;
      const text = asTrimmedString(data.text);
      if (!text) continue;

      const createdAt = data.createdAt instanceof admin.firestore.Timestamp
        ? data.createdAt.toDate().toISOString()
        : '';
      res.status(200).json({
        ok: true,
        threadId: threadDoc.id,
        messageId: messageDoc.id,
        text,
        model: asTrimmedString(data.model),
        createdAt,
      });
      return;
    }
  }

  res.status(404).json({ ok: false, message: 'latest_reply_not_found' });
});

exports.assistantSendMessageHttp = HEAVY_RUNTIME.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, message: 'method_not_allowed' });
    return;
  }

  const route = normalizeAssistantRoute(req.body?.route) || '/assistant';
  const screenLabel = asTrimmedString(req.body?.screenLabel).slice(0, 80);
  const requestedMessage = asTrimmedString(req.body?.message);
  const requestedThreadId = asTrimmedString(req.body?.threadId);

  try {
    const authHeader = String(req.headers.authorization ?? '').trim();
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length).trim()
      : '';
    if (!token) {
      res.status(401).json({ ok: false, message: 'missing_token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(token);
    const companyId = String(decoded.companyId ?? '').trim();
    const role = roleParaFirestore(decoded.role);
    const employeeId = String(decoded.employeeId ?? '').trim();
    const uid = String(decoded.uid ?? decoded.sub ?? '').trim();
    const claims: Claims = { uid, companyId, role, employeeId };
    assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT', 'EMPLOYEE']);

    const message = requestedMessage;
    if (!message) {
      res.status(400).json({ ok: false, message: 'message obrigatoria.' });
      return;
    }

    const assistantCfg = await obterConfigAssistantRuntime(claims.companyId);
    const missingCfg = missingAssistantConfig(assistantCfg);
    if (missingCfg.length > 0) {
      res.status(412).json({
        ok: false,
        message: `Assistente nao configurado. Defina: ${missingCfg.join(', ')}.`,
      });
      return;
    }

    const [userProfile, settingsSnap] = await Promise.all([
      carregarUsuarioMesmoTenant(claims.uid, claims),
      admin.firestore().collection('company_settings').doc(claims.companyId).get(),
    ]);
    const settingsData = (settingsSnap.data() ?? {}) as Record<string, unknown>;
    assertCanUseAssistant({ claims, settingsData });
    await reserveAssistantBurstQuota(claims);
    const [systemIssuesSummary, runtimeIncidentsSummary] = await Promise.all([
      buildSystemIssuesSummary(claims.companyId),
      isSupremePlatformCompany(claims.companyId)
        ? buildRuntimeIncidentsSummary(claims.companyId)
        : Promise.resolve(''),
    ]);

    let threadRef: FirebaseFirestore.DocumentReference;
    let threadData: Record<string, unknown> = {};
    if (requestedThreadId) {
      threadRef = admin.firestore().collection('assistant_threads').doc(requestedThreadId);
      const threadSnap = await threadRef.get();
      if (!threadSnap.exists) {
        res.status(404).json({ ok: false, message: 'Conversa nao encontrada.' });
        return;
      }
      threadData = (threadSnap.data() ?? {}) as Record<string, unknown>;
      assertCompany(asTrimmedString(threadData.companyId), claims);
    } else {
      threadRef = admin.firestore().collection('assistant_threads').doc();
    }

    const instructions = buildAssistantInstructions({
      claims,
      userProfile,
      companySettings: settingsData,
      route,
      screenLabel,
      systemIssuesSummary,
      runtimeIncidentsSummary,
    });

    const modelResponse = await createOpenAiResponse({
      config: assistantCfg,
      instructions,
      message,
      previousResponseId: asTrimmedString(threadData.lastOpenAiResponseId),
      metadata: {
        companyId: claims.companyId,
        role: claims.role,
        route: route || '/assistant',
      },
    });

    const reply = extractAssistantReply(modelResponse);
    const safeReply = reply || buildAssistantFallbackReply(modelResponse);

    const now = admin.firestore.FieldValue.serverTimestamp();
    const periodKey = currentAssistantPeriodKey();
    const usageData = assistantUsage(settingsData);
    const currentRequestCount =
      asTrimmedString(usageData.periodKey) === periodKey
        ? Number(usageData.requestCount ?? 0)
        : 0;
    const currentTokenCount =
      asTrimmedString(usageData.periodKey) === periodKey
        ? Number(usageData.totalTokens ?? 0)
        : 0;
    const responseUsage = asRecord(modelResponse.usage);
    const totalTokens = Number(responseUsage.total_tokens ?? 0);
    const userName = asTrimmedString(userProfile.nome) || 'Usuario';
    const threadTitle = assistantThreadTitleFromMessage(
      asTrimmedString(threadData.title) || message,
    );
    const messagesRef = threadRef.collection('messages');
    const userMessageRef = messagesRef.doc();
    const assistantMessageRef = messagesRef.doc();
    const isNewThread = !requestedThreadId;
    const threadPayload = {
      companyId: claims.companyId,
      createdByUid: asTrimmedString(threadData.createdByUid) || claims.uid,
      createdByName: asTrimmedString(threadData.createdByName) || userName,
      createdByRole: asTrimmedString(threadData.createdByRole) || claims.role,
      memberUids: Array.from(
        new Set(
          [
            ...((Array.isArray(threadData.memberUids)
              ? threadData.memberUids
              : []) as unknown[]).map((item) => asTrimmedString(item)),
            claims.uid,
          ].filter(Boolean),
        ),
      ),
      title: threadTitle,
      lastMessagePreview: safeReply.slice(0, 240),
      lastRoute: route || '/assistant',
      lastScreenLabel: screenLabel,
      lastOpenAiResponseId: asTrimmedString(modelResponse.id),
      updatedAt: now,
      archived: false,
      createdAt: isNewThread ? now : threadData.createdAt ?? now,
    };

    const batch = admin.firestore().batch();
    batch.set(threadRef, threadPayload, { merge: true });
    batch.set(
      admin.firestore().collection('company_settings').doc(claims.companyId),
      {
        companyId: claims.companyId,
        assistantUsage: {
          periodKey,
          requestCount: Math.max(0, currentRequestCount) + 1,
          totalTokens: Math.max(0, currentTokenCount) + (Number.isFinite(totalTokens) ? totalTokens : 0),
          lastRequestAt: now,
          lastRequestBy: claims.uid,
          lastRole: claims.role,
          lastModel: assistantCfg.model,
        },
        updatedAt: now,
      },
      { merge: true },
    );
    batch.set(userMessageRef, {
      companyId: claims.companyId,
      threadId: threadRef.id,
      authorType: 'user',
      authorUid: claims.uid,
      authorName: userName,
      authorRole: claims.role,
      text: message,
      route: route || '/assistant',
      screenLabel,
      createdAt: now,
    });
    batch.set(assistantMessageRef, {
      companyId: claims.companyId,
      threadId: threadRef.id,
      authorType: 'assistant',
      authorUid: 'assistant',
      authorName: 'Assistente Inteligente',
      authorRole: 'ASSISTANT',
      text: safeReply,
      route: route || '/assistant',
      screenLabel,
      provider: 'openai',
      model: assistantCfg.model,
      openAiResponseId: asTrimmedString(modelResponse.id),
      createdAt: now,
    });
    await batch.commit();

    await writeAudit({
      claims,
      module: 'assistant',
      action: 'send_message_http',
      entityPath: 'assistant_threads',
      entityId: threadRef.id,
      before: null,
      after: {
        route,
        screenLabel,
        model: assistantCfg.model,
      },
    });

    res.status(200).json({
      ok: true,
      threadId: threadRef.id,
      reply: safeReply,
      model: assistantCfg.model,
      responseId: asTrimmedString(modelResponse.id),
    });
  } catch (error) {
    const message = errorMessage(error, 'Falha ao consultar o Assistente Inteligente.');
    const statusCode = httpStatusFromError(error);
    functions.logger.error('assistantSendMessageHttp failed', {
      message,
      error: String(error),
    });
    const authHeader = String(req.headers.authorization ?? '').trim();
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length).trim()
      : '';
    if (token) {
      try {
        const decoded = await admin.auth().verifyIdToken(token);
        const companyId = String(decoded.companyId ?? '').trim();
        const uid = String(decoded.uid ?? decoded.sub ?? '').trim();
        const role = roleParaFirestore(decoded.role);
        await writeBackendRuntimeIncident({
          companyId,
          reporterUserId: uid,
          reporterName: 'Assistente Inteligente',
          reporterRole: role || 'SYSTEM',
          source: 'assistant_http',
          category: 'assistant_integration',
          severity: 'error',
          message,
          stackTrace: String(error ?? ''),
          screenLabel: screenLabel || 'Assistente Inteligente',
          route,
          metadata: {
            requestedMessage: requestedMessage.slice(0, 240),
          },
        });
      } catch (incidentError) {
        functions.logger.error('assistantSendMessageHttp incident logging failed', {
          incidentError: String(incidentError),
        });
      }
    }
    res.status(statusCode).json({ ok: false, message });
  }
});

exports.observabilityExportSupremeEphemeral = functions.https.onRequest(async (req, res) => {
  const probeKey = String(req.query.key ?? '').trim();
  if (probeKey !== 'observability-export-20260329') {
    res.status(403).json({ ok: false, message: 'forbidden' });
    return;
  }

  const companyId = String(req.query.companyId ?? '').trim();
  if (!isSupremePlatformCompany(companyId)) {
    res.status(403).json({ ok: false, message: 'company_forbidden' });
    return;
  }
  const format = String(req.query.format ?? 'json').trim().toLowerCase();

  const [incidentsSnap, issuesSnap] = await Promise.all([
    admin.firestore().collection('runtime_incidents').where('companyId', '==', companyId).get(),
    admin.firestore().collection('system_issues').where('companyId', '==', companyId).get(),
  ]);

  const incidents = [...incidentsSnap.docs]
    .sort((a, b) => {
      const aData = asRecord(a.data());
      const bData = asRecord(b.data());
      const aTime = aData.updatedAt instanceof admin.firestore.Timestamp
        ? aData.updatedAt.toMillis()
        : 0;
      const bTime = bData.updatedAt instanceof admin.firestore.Timestamp
        ? bData.updatedAt.toMillis()
        : 0;
      return bTime - aTime;
    })
    .slice(0, 200)
    .map((doc) => ({ id: doc.id, ...doc.data() }));

  const issues = [...issuesSnap.docs]
    .sort((a, b) => {
      const aData = asRecord(a.data());
      const bData = asRecord(b.data());
      const aTime = aData.lastSeenAt instanceof admin.firestore.Timestamp
        ? aData.lastSeenAt.toMillis()
        : 0;
      const bTime = bData.lastSeenAt instanceof admin.firestore.Timestamp
        ? bData.lastSeenAt.toMillis()
        : 0;
      return bTime - aTime;
    })
    .slice(0, 200)
    .map((doc) => ({ id: doc.id, ...doc.data() }));

  const payload = {
    ok: true,
    exportedAt: new Date().toISOString(),
    companyId,
    incidents,
    issues,
  };

  if (format === 'md' || format === 'markdown') {
    const lines: string[] = [
      '# Snapshot De Observabilidade',
      '',
      `- exportado em: ${payload.exportedAt}`,
      `- companyId: ${payload.companyId}`,
      `- incidentes: ${payload.incidents.length}`,
      `- problemas: ${payload.issues.length}`,
      '',
      '## Incidentes',
      '',
    ];

    for (const incident of payload.incidents) {
      const row = asRecord(incident);
      lines.push(`### ${asTrimmedString(row.id)}`);
      lines.push(`- status: ${asTrimmedString(row.status)}`);
      lines.push(`- source: ${asTrimmedString(row.source)}`);
      lines.push(`- category: ${asTrimmedString(row.category)}`);
      lines.push(`- severity: ${asTrimmedString(row.severity)}`);
      lines.push(`- screenLabel: ${asTrimmedString(row.screenLabel)}`);
      lines.push(`- message: ${asTrimmedString(row.message)}`);
      if (asTrimmedString(row.assistantSummary)) {
        lines.push(`- assistantSummary: ${asTrimmedString(row.assistantSummary)}`);
      }
      if (asTrimmedString(row.recommendedAction)) {
        lines.push(`- recommendedAction: ${asTrimmedString(row.recommendedAction)}`);
      }
      lines.push('');
    }

    lines.push('## Problemas Confirmados');
    lines.push('');

    for (const issue of payload.issues) {
      const row = asRecord(issue);
      lines.push(`### ${asTrimmedString(row.id)}`);
      lines.push(`- status: ${asTrimmedString(row.status)}`);
      lines.push(`- fixStatus: ${asTrimmedString(row.fixStatus)}`);
      lines.push(`- module: ${asTrimmedString(row.module)}`);
      lines.push(`- source: ${asTrimmedString(row.source)}`);
      lines.push(`- title: ${asTrimmedString(row.title)}`);
      lines.push(`- description: ${asTrimmedString(row.description)}`);
      if (asTrimmedString(row.recommendedAction)) {
        lines.push(`- recommendedAction: ${asTrimmedString(row.recommendedAction)}`);
      }
      lines.push('');
    }

    res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename=\"observabilidade_${companyId}.md\"`,
    );
    res.status(200).send(lines.join('\n'));
    return;
  }

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename=\"observabilidade_${companyId}.json\"`,
  );
  res.status(200).json(payload);
});

exports.observabilityCleanupSupremeEphemeral = functions.https.onRequest(async (req, res) => {
  const probeKey = String(req.query.key ?? '').trim();
  if (probeKey !== 'observability-cleanup-20260330') {
    res.status(403).json({ ok: false, message: 'forbidden' });
    return;
  }

  const companyId = String(req.query.companyId ?? '').trim();
  if (!isSupremePlatformCompany(companyId)) {
    res.status(403).json({ ok: false, message: 'company_forbidden' });
    return;
  }

  const incidentsSnap = await admin
    .firestore()
    .collection('runtime_incidents')
    .where('companyId', '==', companyId)
    .where('status', '==', 'open')
    .get();

  const summaryMap = new Map<string, number>();
  const batch = admin.firestore().batch();

  incidentsSnap.docs.forEach((doc) => {
    const data = asRecord(doc.data());
    const source = asTrimmedString(data.source) || 'runtime';
    const message = asTrimmedString(data.message) || 'Falha sem mensagem';
    const key = `${source}: ${message}`;
    summaryMap.set(key, (summaryMap.get(key) ?? 0) + 1);
    batch.delete(doc.ref);
  });

  if (!incidentsSnap.empty) {
    await batch.commit();
  }

  const summary = [...summaryMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([label, count]) => `${count}x ${label}`)
    .join(' | ');

  res.status(200).json({
    ok: true,
    companyId,
    deletedCount: incidentsSnap.size,
    summary,
  });
});

async function refreshCompanyProvisioningState(params: {
  claims: Claims;
  companyData: Record<string, unknown>;
}): Promise<{
  recommended: Awaited<ReturnType<typeof buildRecommendedFiscalSetup>>;
  focusProvisioning: Record<string, unknown>;
}> {
  const settingsRef = admin
    .firestore()
    .collection('company_settings')
    .doc(params.claims.companyId);
  const settingsSnap = await settingsRef.get();
  const currentSettings = asRecord(settingsSnap.data());
  const recommended = await buildRecommendedFiscalSetup({
    companyId: params.claims.companyId,
    companyData: params.companyData,
    currentSettings,
  });

  await settingsRef.set(
    {
      companyId: params.claims.companyId,
      companyData: params.companyData,
      commercialSettings: buildDefaultCommercialSettings(currentSettings),
      fiscalRouting: recommended.routing,
      fiscalRealIntegration: recommended.realIntegration,
      fiscalFeatures: recommended.fiscalFeatures,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const mergedSettings = await mergeFiscalSecureSettings(params.claims.companyId, {
    ...currentSettings,
    companyData: params.companyData,
    fiscalRouting: recommended.routing,
    fiscalRealIntegration: recommended.realIntegration,
    fiscalFeatures: recommended.fiscalFeatures,
  });
  const focusProvisioning = await autoProvisionFocusCompanyIfReady({
    claims: params.claims,
    companyData: params.companyData,
    settingsData: mergedSettings,
  });

  return {
    recommended,
    focusProvisioning,
  };
}

function resolveCompanyDataFromSettingsOrUser(
  settingsData: Record<string, unknown>,
  userData?: Record<string, unknown>,
): Record<string, unknown> | null {
  const settingsCompanyData = mapCompanyData(settingsData.companyData);
  if (settingsCompanyData) return settingsCompanyData;
  const userCompanyData = mapCompanyData(userData?.companyData);
  if (userCompanyData) return userCompanyData;
  return null;
}

exports.syncCompanyProfile = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  const settingsSnap = await admin
    .firestore()
    .collection('company_settings')
    .doc(claims.companyId)
    .get();
  const settingsData = asRecord(settingsSnap.data());
  if (claims.role === 'ACCOUNTANT') {
    assertCanOperateFiscalInvoices({claims, settingsData});
  } else {
    assertRole(claims, ['OWNER', 'MANAGER']);
  }

  const companyName = String(data?.companyName ?? '').trim();
  const companyData = mapCompanyData(data?.companyData);

  if (!companyName || !companyData) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'companyName e companyData sao obrigatorios.',
    );
  }

  const query = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', claims.companyId)
    .get();

  let atualizados = 0;
  let batch = admin.firestore().batch();
  let contadorNoBatch = 0;

  for (const doc of query.docs) {
    batch.update(doc.ref, {
      companyName,
      companyData,
      companyProfileUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    contadorNoBatch += 1;
    atualizados += 1;

    if (contadorNoBatch === 450) {
      await batch.commit();
      batch = admin.firestore().batch();
      contadorNoBatch = 0;
    }
  }

  if (contadorNoBatch > 0) {
    await batch.commit();
  }

  const {recommended, focusProvisioning} = await refreshCompanyProvisioningState({
    claims,
    companyData,
  });

  await writeAudit({
    claims,
    module: 'company',
    action: 'sync_profile',
    entityPath: 'users',
    entityId: claims.companyId,
    before: null,
    after: {
      companyName,
      updatedUsers: atualizados,
      fiscalRouteType: recommended.routing.routeType,
      fiscalProvider: recommended.routing.provider,
      focusNfseApi: recommended.routing.focusNfseApi,
      focusProvisioningStatus: focusProvisioning.status,
    },
  });

  return {
    ok: true,
    atualizados,
    fiscalRouteType: recommended.routing.routeType,
    fiscalProvider: recommended.routing.provider,
    focusNfseApi: recommended.routing.focusNfseApi,
    requiresManualReview: recommended.routing.requiresManualReview === true,
    focusProvisioningStatus: focusProvisioning.status,
    focusProvisioningMissing: focusProvisioning.missing,
  };
});

exports.fiscalRefreshCompanyProvisioning = functions.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  const [userSnap, settingsSnap] = await Promise.all([
    admin.firestore().collection('users').doc(claims.uid).get(),
    admin.firestore().collection('company_settings').doc(claims.companyId).get(),
  ]);
  const settingsData = asRecord(settingsSnap.data());
  if (claims.role === 'ACCOUNTANT') {
    assertCanOperateFiscalInvoices({claims, settingsData});
  } else {
    assertRole(claims, ['OWNER', 'MANAGER']);
  }
  const userData = asRecord(userSnap.data());
  const companyData = resolveCompanyDataFromSettingsOrUser(settingsData, userData);
  if (!companyData) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Dados da empresa nao encontrados para reprocessar a automacao fiscal.',
    );
  }

  const companyName = asTrimmedString(
    userData.companyName || companyData.nomeFantasia || companyData.razaoSocial,
  );
  const {recommended, focusProvisioning} = await refreshCompanyProvisioningState({
    claims,
    companyData,
  });

  await writeAudit({
    claims,
    module: 'company',
    action: 'refresh_fiscal_provisioning',
    entityPath: 'company_settings',
    entityId: claims.companyId,
    before: null,
    after: {
      companyName,
      fiscalRouteType: recommended.routing.routeType,
      fiscalProvider: recommended.routing.provider,
      focusNfseApi: recommended.routing.focusNfseApi,
      focusProvisioningStatus: focusProvisioning.status,
    },
  });

  return {
    ok: true,
    companyName,
    fiscalRouteType: recommended.routing.routeType,
    fiscalProvider: recommended.routing.provider,
    focusNfseApi: recommended.routing.focusNfseApi,
    requiresManualReview: recommended.routing.requiresManualReview === true,
    focusProvisioningStatus: focusProvisioning.status,
    focusProvisioningMissing: focusProvisioning.missing,
    focusProvisioningError: asTrimmedString(focusProvisioning.error),
    focusCompanyId: asTrimmedString(focusProvisioning.focusCompanyId),
  };
});

exports.updateEmployeeProfile = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);

  const employeeUid = String(data?.employeeUid ?? '').trim();
  const nome = String(data?.nome ?? '').trim();
  const role = roleParaFirestore(data?.role);
  const documento = data?.documento == null ? null : String(data.documento).trim();
  const pix = data?.pix == null ? null : String(data.pix).trim();
  const telefone = data?.telefone == null ? null : String(data.telefone).trim();
  const email = data?.email == null ? null : String(data.email).trim().toLowerCase();
  const endereco = data?.endereco == null ? null : String(data.endereco).trim();
  const apelido = data?.apelido == null ? null : String(data.apelido).trim();

  if (!employeeUid || !nome) {
    throw new functions.https.HttpsError('invalid-argument', 'employeeUid e nome sao obrigatorios.');
  }

  const employeeRef = admin.firestore().collection('users').doc(employeeUid);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(employeeRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Perfil do funcionario nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const after: FirebaseFirestore.DocumentData = {
      companyId: claims.companyId,
      role,
      nome,
      documento,
      pix,
      telefone,
      email,
      endereco,
      apelido,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(employeeRef, after, { merge: true });
    await writeAudit({
      claims,
      module: 'employees',
      action: 'update_profile',
      entityPath: 'users',
      entityId: employeeUid,
      before,
      after: {
        ...after,
        updatedAt: 'serverTimestamp',
      },
      tx,
    });
  });

  const updateAuthPayload: admin.auth.UpdateRequest = { displayName: nome };
  if (email) {
    updateAuthPayload.email = email;
  }

  try {
    await admin.auth().updateUser(employeeUid, updateAuthPayload);
    await admin.auth().setCustomUserClaims(employeeUid, {
      companyId: claims.companyId,
      role,
      employeeId: employeeUid,
    });
  } catch (_) {
    // Nao bloqueia persistencia do Firestore se apenas o Auth falhar.
  }

  return { ok: true };
});

exports.setEmployeeActiveStatus = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);

  const employeeUid = String(data?.employeeUid ?? '').trim();
  const ativo = data?.ativo === true;
  if (!employeeUid) {
    throw new functions.https.HttpsError('invalid-argument', 'employeeUid obrigatorio.');
  }

  const employeeRef = admin.firestore().collection('users').doc(employeeUid);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(employeeRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Perfil do funcionario nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const companyIdBefore = String(before.companyId ?? '');
    if (isSupremePlatformCompany(companyIdBefore) && !ativo) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Contas da empresa suprema da plataforma nao podem ser desativadas.',
      );
    }

    tx.set(
      employeeRef,
      {
        companyId: claims.companyId,
        ativo,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await writeAudit({
      claims,
      module: 'employees',
      action: 'set_active_status',
      entityPath: 'users',
      entityId: employeeUid,
      before,
      after: {
        ativo,
        updatedAt: 'serverTimestamp',
      },
      tx,
    });
  });

  try {
    await admin.auth().updateUser(employeeUid, { disabled: !ativo });
  } catch (_) {
    // Nao bloqueia o ajuste do Firestore se o Auth falhar.
  }

  return { ok: true, ativo };
});

exports.employeesGetBaseSnapshot = functions.https.onCall(async (_data, context) => {
  const claims = await assertOperatorFromProfile(context);

  const snapshot = await admin
    .firestore()
    .collection('users')
    .where('companyId', '==', claims.companyId)
    .get();

  const all = snapshot.docs
    .map((doc) => {
      const data = doc.data();
      const role = roleParaFirestore(data.role);
      const ativo = data.ativo !== false;
      const updatedAtRaw = data.updatedAt;
      const createdAtRaw = data.createdAt;
      const updatedAtIso =
        updatedAtRaw instanceof admin.firestore.Timestamp
          ? updatedAtRaw.toDate().toISOString()
          : createdAtRaw instanceof admin.firestore.Timestamp
            ? createdAtRaw.toDate().toISOString()
            : '';
      return {
        id: doc.id,
        nome: asTrimmedString(data.nome) || asTrimmedString(data.displayName) || 'Sem nome',
        email: asTrimmedString(data.email),
        role,
        ativo,
        updatedAtIso,
        normalizedRole: normalizarRole(data.role),
      };
    })
    .filter((item) => isVisibleEmployeeRole(item.normalizedRole))
    .map((item) => {
      const { normalizedRole, ...rest } = item;
      return rest;
    });

  all.sort((a, b) => b.updatedAtIso.localeCompare(a.updatedAtIso));

  const owners = all.filter((item) => item.role === 'OWNER');
  const managers = all.filter((item) => item.role === 'MANAGER');
  const accountants = all.filter((item) => item.role === 'ACCOUNTANT');
  const employees = all.filter((item) => item.role === 'EMPLOYEE');
  const operational = all.filter((item) => item.role === 'MANAGER' || item.role === 'EMPLOYEE');
  const activeUsers = all.filter((item) => item.ativo).length;
  const inactiveUsers = all.length - activeUsers;

  return {
    ok: true,
    companyId: claims.companyId,
    totalUsers: all.length,
    activeUsers,
    inactiveUsers,
    owners: owners.length,
    managers: managers.length,
    accountants: accountants.length,
    employees: employees.length,
    operationalEmployees: operational.length,
    sample: all.slice(0, 10),
    exportedAtIso: new Date().toISOString(),
  };
});

exports.paymentsCreate = functions.https.onCall(async (data, context) => {
  const claims = await assertOperatorFromProfile(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
  await assertNotDemoReadOnly(claims);

  const employeeId = String(data?.employeeId ?? '').trim();
  const competenceYear = parsePositiveInt(data?.competenceYear, 'competenceYear');
  const competenceMonth = parsePositiveInt(data?.competenceMonth, 'competenceMonth');
  const grossCents = parseNonNegativeInt(data?.grossCents, 'grossCents');
  const discountsCents = parseNonNegativeInt(data?.discountsCents, 'discountsCents');
  const dueDate = parseOptionalDate(data?.dueDate, 'dueDate');
  const markAsPaid = parseOptionalBoolean(data?.markAsPaid, 'markAsPaid') === true;

  if (!employeeId || competenceMonth < 1 || competenceMonth > 12) {
    throw new functions.https.HttpsError('invalid-argument', 'employeeId/competencia invalidos.');
  }

  const employeeProfile = await carregarUsuarioMesmoTenant(employeeId, claims);
  const paymentType = normalizePaymentType(
    data?.paymentType,
    employeeProfile.compensationType,
  );

  const existingPayments = await admin
    .firestore()
    .collection('payments')
    .where('companyId', '==', claims.companyId)
    .where('employeeId', '==', employeeId)
    .where('competenceYear', '==', competenceYear)
    .where('competenceMonth', '==', competenceMonth)
    .get();

  const activeExistingPayments = existingPayments.docs.filter((doc) => {
    const current = asRecord(doc.data());
    return asTrimmedString(current.status).toUpperCase() !== 'CANCELED';
  });

  if (paymentType === 'MONTHLY' && activeExistingPayments.length > 0) {
    const latestExisting = activeExistingPayments
      .map((doc) => asRecord(doc.data()))
      .sort((a, b) => paymentLaunchReferenceLabel(b).localeCompare(paymentLaunchReferenceLabel(a)))[0];
    const existingStatus = asTrimmedString(latestExisting.status).toUpperCase() || 'PENDING';
    throw new functions.https.HttpsError(
      'already-exists',
      `Pagamento mensal ja existe para esta competencia. Status: ${existingStatus}. Referencia: ${paymentLaunchReferenceLabel(latestExisting)}.`,
    );
  }

  if (paymentType !== 'MONTHLY') {
    const batch = admin.firestore().batch();
    let hasRepair = false;
    for (const doc of activeExistingPayments) {
      const current = asRecord(doc.data());
      if (!asTrimmedString(current.paymentType)) {
        batch.set(doc.ref, { paymentType }, { merge: true });
        hasRepair = true;
      }
    }
    if (hasRepair) {
      await batch.commit();
    }
  }

  const netCents = grossCents - discountsCents;
  if (netCents < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'descontos nao podem superar o bruto.');
  }

  const ref = admin.firestore().collection('payments').doc();
  await admin.firestore().runTransaction(async (tx) => {
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    const initialStatus = markAsPaid ? 'PAID' : 'PENDING';
    const after: FirebaseFirestore.DocumentData = {
      companyId: claims.companyId,
      employeeId,
      competenceYear,
      competenceMonth,
      grossCents,
      discountsCents,
      netCents,
      paymentType,
      dueDate,
      status: initialStatus,
      paidAt: markAsPaid ? admin.firestore.FieldValue.serverTimestamp() : null,
      confirmationAt: null,
      contestedAt: null,
      contestReason: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdByUserId: claims.uid,
    };

    tx.set(ref, after);
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      null,
      0,
      paymentSummaryBucket(after),
      paymentSummaryAmount(after),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'create',
      entityPath: 'payments',
      entityId: ref.id,
      before: null,
      after: {
        ...after,
        createdAt: 'serverTimestamp',
        updatedAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId: ref.id,
    paymentData: {
      companyId: claims.companyId,
      employeeId,
      competenceYear,
      competenceMonth,
      netCents,
      paymentType,
      dueDate,
      status: markAsPaid ? 'PAID' : 'PENDING',
      paidAt: markAsPaid ? admin.firestore.Timestamp.now() : null,
    },
    claims,
  });

  return { ok: true, paymentId: ref.id };
});

exports.paymentsCreateBulk = functions.https.onCall(async (data, context) => {
  const claims = await assertOperatorFromProfile(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
  await assertNotDemoReadOnly(claims);

  const competenceYear = parsePositiveInt(data?.competenceYear, 'competenceYear');
  const competenceMonth = parsePositiveInt(data?.competenceMonth, 'competenceMonth');
  const rawItems = Array.isArray(data?.items) ? data.items : [];
  if (competenceMonth < 1 || competenceMonth > 12 || rawItems.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'competencia ou lote de pagamentos invalido.',
    );
  }

  const normalizedItems: Array<{
    employeeId: string;
    grossCents: number;
    discountsCents: number;
    paymentType: string;
    dueDate: admin.firestore.Timestamp | null;
    markAsPaid: boolean;
  }> = rawItems
    .map((raw: unknown) => {
      const item = asRecord(raw);
      return {
        employeeId: asTrimmedString(item.employeeId),
        grossCents: parseNonNegativeInt(item.grossCents, 'grossCents'),
        discountsCents: parseNonNegativeInt(item.discountsCents, 'discountsCents'),
        paymentType: asTrimmedString(item.paymentType).toUpperCase(),
        dueDate: parseOptionalDate(item.dueDate, 'dueDate'),
        markAsPaid: parseOptionalBoolean(item.markAsPaid, 'markAsPaid') === true,
      };
    });
  const items = normalizedItems.filter((item) => item.employeeId.length > 0);

  if (items.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Nenhum funcionario valido informado para o lote.',
    );
  }

  const created: Array<Record<string, string>> = [];
  const skipped: Array<Record<string, string>> = [];
  const failed: Array<Record<string, string>> = [];
  const processedEmployeeIds = new Set<string>();

  for (const item of items) {
    if (processedEmployeeIds.has(item.employeeId)) {
      skipped.push({
        employeeId: item.employeeId,
        message: 'Funcionario duplicado no mesmo lote.',
      });
      continue;
    }
    processedEmployeeIds.add(item.employeeId);

    const netCents = item.grossCents - item.discountsCents;
    if (netCents < 0) {
      failed.push({
        employeeId: item.employeeId,
        message: 'Descontos nao podem superar o valor bruto.',
      });
      continue;
    }
    if (item.grossCents <= 0) {
      skipped.push({
        employeeId: item.employeeId,
        message: 'Valor bruto zerado para a competencia.',
      });
      continue;
    }

    try {
      const employeeProfile = await carregarUsuarioMesmoTenant(item.employeeId, claims);
      item.paymentType = normalizePaymentType(
        item.paymentType,
        employeeProfile.compensationType,
      );
      const existing = await admin
        .firestore()
        .collection('payments')
        .where('companyId', '==', claims.companyId)
        .where('employeeId', '==', item.employeeId)
        .where('competenceYear', '==', competenceYear)
        .where('competenceMonth', '==', competenceMonth)
        .get();

      const activeExistingPayments = existing.docs.filter((doc) => {
        const current = asRecord(doc.data());
        return asTrimmedString(current.status).toUpperCase() !== 'CANCELED';
      });

      if (item.paymentType === 'MONTHLY' && activeExistingPayments.length > 0) {
        const latestExisting = activeExistingPayments
          .map((doc) => asRecord(doc.data()))
          .sort((a, b) => paymentLaunchReferenceLabel(b).localeCompare(paymentLaunchReferenceLabel(a)))[0];
        const existingStatus =
          asTrimmedString(latestExisting.status).toUpperCase() || 'PENDING';
        skipped.push({
          employeeId: item.employeeId,
          message:
            `Pagamento mensal ja existe para esta competencia. ` +
            `Status: ${existingStatus}. Referencia: ${paymentLaunchReferenceLabel(latestExisting)}.`,
        });
        continue;
      }

      if (item.paymentType !== 'MONTHLY') {
        const batch = admin.firestore().batch();
        let hasRepair = false;
        for (const doc of activeExistingPayments) {
          const current = asRecord(doc.data());
          if (!asTrimmedString(current.paymentType)) {
            batch.set(doc.ref, { paymentType: item.paymentType }, { merge: true });
            hasRepair = true;
          }
        }
        if (hasRepair) {
          await batch.commit();
        }
      }

      const ref = admin.firestore().collection('payments').doc();
      await admin.firestore().runTransaction(async (tx) => {
        const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
        const initialStatus = item.markAsPaid ? 'PAID' : 'PENDING';
        const after: FirebaseFirestore.DocumentData = {
          companyId: claims.companyId,
          employeeId: item.employeeId,
          competenceYear,
          competenceMonth,
          grossCents: item.grossCents,
          discountsCents: item.discountsCents,
          netCents,
          paymentType: item.paymentType,
          dueDate: item.dueDate,
          status: initialStatus,
          paidAt: item.markAsPaid ? admin.firestore.FieldValue.serverTimestamp() : null,
          confirmationAt: null,
          contestedAt: null,
          contestReason: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdByUserId: claims.uid,
        };

        tx.set(ref, after);
        await applyRuntimeSummaryDelta(
          tx,
          claims.companyId,
          'finance',
          null,
          0,
          paymentSummaryBucket(after),
          paymentSummaryAmount(after),
          runtimeSummaryCurrent,
        );
        await writeAudit({
          claims,
          module: 'payments',
          action: 'create_bulk',
          entityPath: 'payments',
          entityId: ref.id,
          before: null,
          after: {
            ...after,
            createdAt: 'serverTimestamp',
            updatedAt: 'serverTimestamp',
          },
          tx,
        });
      });

      await syncFinanceMovementForPayment({
        paymentRef: ref,
        paymentId: ref.id,
        paymentData: {
          companyId: claims.companyId,
          employeeId: item.employeeId,
          competenceYear,
          competenceMonth,
          netCents,
          paymentType: item.paymentType,
          dueDate: item.dueDate,
          status: item.markAsPaid ? 'PAID' : 'PENDING',
          paidAt: item.markAsPaid ? admin.firestore.Timestamp.now() : null,
        },
        claims,
      });

      created.push({
        employeeId: item.employeeId,
        paymentId: ref.id,
      });
    } catch (error) {
      const message =
        error instanceof functions.https.HttpsError
          ? error.message
          : error instanceof Error
              ? error.message
              : 'Falha interna ao lancar pagamento.';
      failed.push({
        employeeId: item.employeeId,
        message,
      });
    }
  }

  return {
    ok: true,
    createdCount: created.length,
    skippedCount: skipped.length,
    failedCount: failed.length,
    created,
    skipped,
    failed,
  };
});

exports.paymentsUpdate = functions.https.onCall(async (data, context) => {
  const claims = await assertOperatorFromProfile(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const paymentId = String(data?.paymentId ?? '').trim();
  const employeeId = String(data?.employeeId ?? '').trim();
  const competenceYear = parsePositiveInt(data?.competenceYear, 'competenceYear');
  const competenceMonth = parsePositiveInt(data?.competenceMonth, 'competenceMonth');
  const grossCents = parseNonNegativeInt(data?.grossCents, 'grossCents');
  const discountsCents = parseNonNegativeInt(data?.discountsCents, 'discountsCents');

  if (!paymentId || !employeeId || competenceMonth < 1 || competenceMonth > 12) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId/employeeId/competencia invalidos.',
    );
  }

  await carregarUsuarioMesmoTenant(employeeId, claims);

  const netCents = grossCents - discountsCents;
  if (netCents < 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'descontos nao podem superar o bruto.',
    );
  }

  const ref = admin.firestore().collection('payments').doc(paymentId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(
      tx,
      claims.companyId,
      'finance',
    );
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const currentStatus = asTrimmedString(before.status).toUpperCase();
    if (currentStatus === 'CANCELED') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Pagamento cancelado nao pode ser editado.',
      );
    }

    const after: FirebaseFirestore.DocumentData = {
      employeeId,
      competenceYear,
      competenceMonth,
      competencia: `${competenceYear}-${String(competenceMonth).padStart(2, '0')}`,
      grossCents,
      discountsCents,
      netCents,
      valorCents: netCents,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      paymentSummaryBucket(asRecord(before)),
      paymentSummaryAmount(asRecord(before)),
      paymentSummaryBucket({ ...asRecord(before), ...after }),
      paymentSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'update',
      entityPath: 'payments',
      entityId: paymentId,
      before,
      after: {
        ...after,
        updatedAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId,
    paymentData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.paymentsMarkPaid = functions.https.onCall(async (data, context) => {
  const claims = await assertOperatorFromProfile(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const paymentId = String(data?.paymentId ?? '').trim();
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId obrigatorio.');
  }

  const ref = admin.firestore().collection('payments').doc(paymentId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const after: FirebaseFirestore.DocumentData = {
      status: 'PAID',
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      paymentSummaryBucket(asRecord(before)),
      paymentSummaryAmount(asRecord(before)),
      paymentSummaryBucket({ ...asRecord(before), ...after }),
      paymentSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'mark_paid',
      entityPath: 'payments',
      entityId: paymentId,
      before,
      after: {
        status: 'PAID',
        paidAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId,
    paymentData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.paymentsConfirm = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  await assertNotDemoReadOnly(claims);

  const paymentId = String(data?.paymentId ?? '').trim();
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId obrigatorio.');
  }

  const ref = admin.firestore().collection('payments').doc(paymentId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);
    ensureEmployeeOwner(String(before.employeeId ?? ''), claims);

    const statusAtual = String(before.status ?? '').toUpperCase();
    if (statusAtual !== 'PAID') {
      throw new functions.https.HttpsError('failed-precondition', 'Somente pagamento PAID pode ser confirmado.');
    }

    const after: FirebaseFirestore.DocumentData = {
      status: 'CONFIRMED',
      confirmationAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      paymentSummaryBucket(asRecord(before)),
      paymentSummaryAmount(asRecord(before)),
      paymentSummaryBucket({ ...asRecord(before), ...after }),
      paymentSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'confirm',
      entityPath: 'payments',
      entityId: paymentId,
      before,
      after: {
        status: 'CONFIRMED',
        confirmationAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId,
    paymentData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.paymentsContest = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  await assertNotDemoReadOnly(claims);

  const paymentId = String(data?.paymentId ?? '').trim();
  const reason = String(data?.reason ?? '').trim();
  if (!paymentId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId e reason obrigatorios.');
  }

  const ref = admin.firestore().collection('payments').doc(paymentId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);
    ensureEmployeeOwner(String(before.employeeId ?? ''), claims);

    const statusAtual = String(before.status ?? '').toUpperCase();
    if (statusAtual !== 'PAID') {
      throw new functions.https.HttpsError('failed-precondition', 'Somente pagamento PAID pode ser contestado.');
    }

    const after: FirebaseFirestore.DocumentData = {
      status: 'CONTESTED',
      contestedAt: admin.firestore.FieldValue.serverTimestamp(),
      contestReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      paymentSummaryBucket(asRecord(before)),
      paymentSummaryAmount(asRecord(before)),
      paymentSummaryBucket({ ...asRecord(before), ...after }),
      paymentSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'contest',
      entityPath: 'payments',
      entityId: paymentId,
      before,
      after: {
        status: 'CONTESTED',
        contestedAt: 'serverTimestamp',
        contestReason: reason,
      },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId,
    paymentData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.paymentsCancel = functions.https.onCall(async (data, context) => {
  const claims = await assertOperatorFromProfile(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const paymentId = String(data?.paymentId ?? '').trim();
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId obrigatorio.');
  }

  const ref = admin.firestore().collection('payments').doc(paymentId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Pagamento nao encontrado.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const after: FirebaseFirestore.DocumentData = {
      status: 'CANCELED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      paymentSummaryBucket(asRecord(before)),
      paymentSummaryAmount(asRecord(before)),
      paymentSummaryBucket({ ...asRecord(before), ...after }),
      paymentSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'payments',
      action: 'cancel',
      entityPath: 'payments',
      entityId: paymentId,
      before,
      after: { status: 'CANCELED' },
      tx,
    });
  });

  await syncFinanceMovementForPayment({
    paymentRef: ref,
    paymentId,
    paymentData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.debtsCreate = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const employeeId = String(data?.employeeId ?? '').trim();
  const title = String(data?.title ?? '').trim();
  const type = String(data?.type ?? '').trim().toUpperCase();
  const amountCents = parsePositiveInt(data?.amountCents, 'amountCents');
  const dueDate = parseOptionalDate(data?.dueDate, 'dueDate');

  if (!employeeId || !title || (type !== 'DEBT' && type !== 'ADVANCE')) {
    throw new functions.https.HttpsError('invalid-argument', 'Dados invalidos para divida/adiantamento.');
  }

  await carregarUsuarioMesmoTenant(employeeId, claims);

  const ref = admin.firestore().collection('debts').doc();
  await admin.firestore().runTransaction(async (tx) => {
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    const after: FirebaseFirestore.DocumentData = {
      companyId: claims.companyId,
      employeeId,
      title,
      type,
      amountCents,
      dueDate,
      status: 'OPEN',
      settledAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdByUserId: claims.uid,
    };

    tx.set(ref, after);
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      null,
      0,
      debtSummaryBucket(after),
      debtSummaryAmount(after),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'debts',
      action: 'create',
      entityPath: 'debts',
      entityId: ref.id,
      before: null,
      after: {
        ...after,
        createdAt: 'serverTimestamp',
        updatedAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForDebt({
    debtRef: ref,
    debtId: ref.id,
    debtData: {
      companyId: claims.companyId,
      employeeId,
      title,
      type,
      amountCents,
      dueDate,
      status: 'OPEN',
    },
    claims,
  });

  return { ok: true, debtId: ref.id };
});

exports.debtsSettle = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const debtId = String(data?.debtId ?? '').trim();
  if (!debtId) {
    throw new functions.https.HttpsError('invalid-argument', 'debtId obrigatorio.');
  }

  const ref = admin.firestore().collection('debts').doc(debtId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Divida nao encontrada.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const after: FirebaseFirestore.DocumentData = {
      status: 'SETTLED',
      settledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      debtSummaryBucket(asRecord(before)),
      debtSummaryAmount(asRecord(before)),
      debtSummaryBucket({ ...asRecord(before), ...after }),
      debtSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'debts',
      action: 'settle',
      entityPath: 'debts',
      entityId: debtId,
      before,
      after: {
        status: 'SETTLED',
        settledAt: 'serverTimestamp',
      },
      tx,
    });
  });

  await syncFinanceMovementForDebt({
    debtRef: ref,
    debtId,
    debtData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.debtsCancel = functions.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);
  await assertNotDemoReadOnly(claims);

  const debtId = String(data?.debtId ?? '').trim();
  if (!debtId) {
    throw new functions.https.HttpsError('invalid-argument', 'debtId obrigatorio.');
  }

  const ref = admin.firestore().collection('debts').doc(debtId);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const runtimeSummaryCurrent = await readRuntimeSummarySection(tx, claims.companyId, 'finance');
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Divida nao encontrada.');
    }

    const before = snap.data() ?? {};
    assertCompany(String(before.companyId ?? ''), claims);

    const after: FirebaseFirestore.DocumentData = {
      status: 'CANCELED',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(ref, after, { merge: true });
    await applyRuntimeSummaryDelta(
      tx,
      claims.companyId,
      'finance',
      debtSummaryBucket(asRecord(before)),
      debtSummaryAmount(asRecord(before)),
      debtSummaryBucket({ ...asRecord(before), ...after }),
      debtSummaryAmount({ ...asRecord(before), ...after }),
      runtimeSummaryCurrent,
    );
    await writeAudit({
      claims,
      module: 'debts',
      action: 'cancel',
      entityPath: 'debts',
      entityId: debtId,
      before,
      after: { status: 'CANCELED' },
      tx,
    });
  });

  await syncFinanceMovementForDebt({
    debtRef: ref,
    debtId,
    debtData: {
      companyId: claims.companyId,
      ...(await ref.get()).data(),
    },
    claims,
  });

  return { ok: true };
});

exports.fiscalSyncFocusCompany = HEAVY_RUNTIME.https.onCall(async (_data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER']);

  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const [userSnap, settingsSnap] = await Promise.all([
    admin.firestore().collection('users').doc(claims.uid).get(),
    settingsRef.get(),
  ]);
  const companyData = resolveCompanyDataFromSettingsOrUser(
    asRecord(settingsSnap.data()),
    asRecord(userSnap.data()),
  );
  if (!companyData) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Dados da empresa nao encontrados para sincronizar com a Focus.',
    );
  }

  const settingsData = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  assertCanOperateFiscalInvoices({
    claims,
    settingsData,
  });
  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (!providerIsFocus(asTrimmedString(setup.provider))) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Selecione Focus NFe como provedor para usar esta sincronizacao.',
    );
  }

  const result = await syncFocusCompany({
    claims,
    companyData,
    settingsData,
  });
  await settingsRef.set(
    {
      focusProvisioning: {
        status: 'SYNCED',
        missing: [],
        focusCompanyId: asTrimmedString(result.id),
        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await mergeFiscalHomologationChecklist({
    companyId: claims.companyId,
    patch: {
      providerConnectionValidated: true,
    },
  });

  return {
    ok: true,
    focusCompanyId: asTrimmedString(result.id),
    certificadoValidoAte: asTrimmedString(result.certificado_valido_ate),
    certificadoCnpj: asTrimmedString(result.certificado_cnpj),
  };
});

exports.fiscalIssueServiceInvoice = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
  await assertNotDemoReadOnly(claims);

  const invoiceId = String(data?.invoiceId ?? '').trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError('invalid-argument', 'invoiceId obrigatorio.');
  }

  const invoiceRef = admin.firestore().collection('service_invoices').doc(invoiceId);
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const [invoiceSnap, settingsSnap] = await Promise.all([invoiceRef.get(), settingsRef.get()]);

  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Nota fiscal nao encontrada.');
  }

  const invoiceData = invoiceSnap.data() ?? {};
  assertCompany(String(invoiceData.companyId ?? ''), claims);
  functions.logger.info('fiscalIssueServiceInvoice start', {
    invoiceId,
    companyId: claims.companyId,
    invoiceCompanyId: String((invoiceData as any).companyId ?? ''),
    currentStatus: String((invoiceData as any).status ?? ''),
  });

  const settingsData = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  assertCanOperateFiscalInvoices({
    claims,
    settingsData,
  });
  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (
    !providerIsFocus(asTrimmedString(setup.provider)) &&
    !asTrimmedString(setup.apiBaseUrl)
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configure a Base URL da emissao real antes de emitir.',
    );
  }

  validateInvoiceReadinessForOfficialIssue({
    invoiceData,
    settingsData,
  });
  await validateInvoiceSourceTaskConsistency({
    invoiceData,
    claims,
  });

  if (providerIsFocus(asTrimmedString(setup.provider))) {
    const userSnap = await admin.firestore().collection('users').doc(claims.uid).get();
    const companyData = resolveCompanyDataFromSettingsOrUser(
      settingsData,
      asRecord(userSnap.data()),
    );
    if (companyData) {
      await syncFocusCompany({
        claims,
        companyData,
        settingsData,
      });
    }
  }

  let providerResponse: Record<string, unknown>;
  try {
    providerResponse = await callFiscalProvider({
      setup,
      operation: 'issue',
      invoiceId,
      invoiceData,
      claims,
    });
  } catch (error: unknown) {
    await persistInvoiceAttemptFailure({
      invoiceRef,
      invoiceId,
      claims,
      attemptStatus: 'FAILED',
      fallbackMessage: 'Falha ao emitir oficialmente a nota.',
      auditAction: 'issue_service_invoice_failed',
      error,
    });
    throw error;
  }

  const pr = asRecord(providerResponse);
  const officialNumber =
    extractFocusOfficialNfseNumber(pr) ||
    asTrimmedString(providerResponse.officialNumber) ||
    asTrimmedString(providerResponse.invoiceNumber) ||
    asTrimmedString(providerResponse.number) ||
    asTrimmedString(providerResponse.nfseNumber);
  const officialPortalUrl =
    asTrimmedString(providerResponse.officialPortalUrl) ||
    asTrimmedString(providerResponse.portalUrl) ||
    asTrimmedString(providerResponse.url);
  const protocol =
    asTrimmedString(providerResponse.protocol) ||
    asTrimmedString(providerResponse.receipt) ||
    asTrimmedString(providerResponse.requestId);
  const statusRaw = coalesceFocusNfseStatusRawForNormalize(pr) || pr.status;
  const status = normalizeOfficialInvoiceStatus(
    statusRaw,
    providerResponse.provider,
    'APPROVED',
  );
  functions.logger.info('fiscalIssueServiceInvoice provider result', {
    invoiceId,
    companyId: claims.companyId,
    provider: asTrimmedString((providerResponse as any).provider),
    environment: asTrimmedString((providerResponse as any).environment),
    rawStatus: String((providerResponse as any).status ?? ''),
    coalescedStatus: asTrimmedString(statusRaw),
    normalizedStatus: status,
    officialNumber,
    protocol,
    officialPortalUrl,
  });

  await invoiceRef.set(
    {
      status,
      officialNumber,
      officialPortalUrl,
      officialProtocol: protocol,
      officialProvider: asTrimmedString(providerResponse.provider),
      officialEnvironment: asTrimmedString(providerResponse.environment),
      officialIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEmissionAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEmissionAttemptStatus: 'SUCCESS',
      officialResponse: providerResponse,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  functions.logger.info('fiscalIssueServiceInvoice persisted', {
    invoiceId,
    companyId: claims.companyId,
    normalizedStatus: status,
    officialNumber,
  });

  await writeAudit({
    claims,
    module: 'fiscal',
    action: 'issue_service_invoice',
    entityPath: 'service_invoices',
    entityId: invoiceId,
    before: null,
    after: {
      status,
      officialNumber,
      officialPortalUrl,
      protocol,
      provider: asTrimmedString(providerResponse.provider),
      environment: asTrimmedString(providerResponse.environment),
    },
  });
  if (status.toUpperCase() === 'APPROVED' || officialNumber.trim().length > 0) {
    await ensureFinanceMovementForInvoice({
      invoiceRef,
      invoiceId,
      invoiceData,
      claims,
      status,
      officialNumber,
    });
    await mergeFiscalHomologationChecklist({
      companyId: claims.companyId,
      patch: {
        providerConnectionValidated: true,
        pilotInvoiceValidated: true,
      },
    });
  }

  return {
    ok: true,
    invoiceId,
    status,
    officialNumber,
    officialPortalUrl,
    protocol,
    provider: asTrimmedString(providerResponse.provider),
    environment: asTrimmedString(providerResponse.environment),
  };
});

exports.fiscalCancelServiceInvoice = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);
  await assertNotDemoReadOnly(claims);

  const invoiceId = String(data?.invoiceId ?? '').trim();
  const reason = String(data?.reason ?? '').trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError('invalid-argument', 'invoiceId obrigatorio.');
  }

  const invoiceRef = admin.firestore().collection('service_invoices').doc(invoiceId);
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const [invoiceSnap, settingsSnap] = await Promise.all([invoiceRef.get(), settingsRef.get()]);

  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Nota fiscal nao encontrada.');
  }

  const invoiceData = invoiceSnap.data() ?? {};
  assertCompany(String(invoiceData.companyId ?? ''), claims);

  const settingsData = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  assertCanOperateFiscalInvoices({
    claims,
    settingsData,
  });
  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (
    !providerIsFocus(asTrimmedString(setup.provider)) &&
    !asTrimmedString(setup.apiBaseUrl)
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configure a Base URL da emissao real antes de cancelar.',
    );
  }

  let providerResponse: Record<string, unknown>;
  try {
    providerResponse = await callFiscalProvider({
      setup,
      operation: 'cancel',
      invoiceId,
      invoiceData,
      claims,
      reason,
    });
  } catch (error: unknown) {
    await persistInvoiceAttemptFailure({
      invoiceRef,
      invoiceId,
      claims,
      attemptStatus: 'CANCEL_FAILED',
      fallbackMessage: 'Falha ao cancelar oficialmente a nota.',
      auditAction: 'cancel_service_invoice_failed',
      error,
    });
    throw error;
  }

  const status = normalizeOfficialInvoiceStatus(
    providerResponse.status,
    providerResponse.provider,
    'CANCELED',
  );
  const cancelProtocol =
    asTrimmedString(providerResponse.cancelProtocol) ||
    asTrimmedString(providerResponse.protocol) ||
    asTrimmedString(providerResponse.receipt) ||
    asTrimmedString(providerResponse.requestId);

  await invoiceRef.set(
    {
      status,
      cancellationReason: reason,
      canceledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelProtocol,
      lastEmissionAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEmissionAttemptStatus: 'CANCELED',
      cancelResponse: providerResponse,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit({
    claims,
    module: 'fiscal',
    action: 'cancel_service_invoice',
    entityPath: 'service_invoices',
    entityId: invoiceId,
    before: null,
    after: {
      status,
      reason,
      cancelProtocol,
      provider: asTrimmedString(providerResponse.provider),
      environment: asTrimmedString(providerResponse.environment),
    },
  });

  return {
    ok: true,
    invoiceId,
    status,
    cancelProtocol,
    provider: asTrimmedString(providerResponse.provider),
    environment: asTrimmedString(providerResponse.environment),
  };
});

exports.fiscalRefreshServiceInvoiceStatus = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);

  const invoiceId = String(data?.invoiceId ?? '').trim();
  if (!invoiceId) {
    throw new functions.https.HttpsError('invalid-argument', 'invoiceId obrigatorio.');
  }

  const invoiceRef = admin.firestore().collection('service_invoices').doc(invoiceId);
  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const [invoiceSnap, settingsSnap] = await Promise.all([invoiceRef.get(), settingsRef.get()]);

  if (!invoiceSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Nota fiscal nao encontrada.');
  }

  const invoiceData = invoiceSnap.data() ?? {};
  assertCompany(String(invoiceData.companyId ?? ''), claims);
  functions.logger.info('fiscalRefreshServiceInvoiceStatus start', {
    invoiceId,
    companyId: claims.companyId,
    invoiceCompanyId: String((invoiceData as any).companyId ?? ''),
    currentStatus: String((invoiceData as any).status ?? ''),
  });

  const settingsData = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  assertCanOperateFiscalInvoices({
    claims,
    settingsData,
  });
  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (
    !providerIsFocus(asTrimmedString(setup.provider)) &&
    !asTrimmedString(setup.apiBaseUrl)
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configure a integracao fiscal real antes de consultar o status oficial.',
    );
  }

  let providerResponse: Record<string, unknown>;
  try {
    providerResponse = await callFiscalProvider({
      setup,
      operation: 'query',
      invoiceId,
      invoiceData,
      claims,
    });
  } catch (error: unknown) {
    await persistInvoiceAttemptFailure({
      invoiceRef,
      invoiceId,
      claims,
      attemptStatus: 'QUERY_FAILED',
      fallbackMessage: 'Falha ao consultar status oficial da nota.',
      auditAction: 'refresh_service_invoice_status_failed',
      error,
    });
    throw error;
  }
  functions.logger.info('fiscalRefreshServiceInvoiceStatus provider result', {
    invoiceId,
    companyId: claims.companyId,
    provider: asTrimmedString((providerResponse as any).provider),
    environment: asTrimmedString((providerResponse as any).environment),
    rawStatus: String((providerResponse as any).status ?? ''),
    officialNumber:
      asTrimmedString((providerResponse as any).officialNumber) ||
      asTrimmedString((providerResponse as any).invoiceNumber) ||
      asTrimmedString((providerResponse as any).number) ||
      asTrimmedString((providerResponse as any).nfseNumber),
  });
  const persisted = await persistOfficialInvoiceStatus({
    invoiceRef,
    invoiceData,
    providerResponse,
  });
  functions.logger.info('fiscalRefreshServiceInvoiceStatus persisted', {
    invoiceId,
    companyId: claims.companyId,
    status: persisted.status,
    officialNumber: persisted.officialNumber,
    lastAttemptStatus: persisted.lastAttemptStatus,
  });

  await writeAudit({
    claims,
    module: 'fiscal',
    action: 'refresh_service_invoice_status',
    entityPath: 'service_invoices',
    entityId: invoiceId,
    before: null,
    after: {
      status: persisted.status,
      officialNumber: persisted.officialNumber,
      officialPortalUrl: persisted.officialPortalUrl,
      protocol: persisted.protocol,
      provider: asTrimmedString(providerResponse.provider),
      environment: asTrimmedString(providerResponse.environment),
      lastAttemptStatus: persisted.lastAttemptStatus,
    },
  });
  if (
    persisted.status.toUpperCase() === 'APPROVED' ||
    persisted.officialNumber.trim().length > 0
  ) {
    await ensureFinanceMovementForInvoice({
      invoiceRef,
      invoiceId,
      invoiceData,
      claims,
      status: persisted.status,
      officialNumber: persisted.officialNumber,
    });
    await mergeFiscalHomologationChecklist({
      companyId: claims.companyId,
      patch: {
        providerConnectionValidated: true,
        pilotInvoiceValidated: true,
      },
    });
  }

  return {
    ok: true,
    invoiceId,
    status: persisted.status,
    officialNumber: persisted.officialNumber,
    officialPortalUrl: persisted.officialPortalUrl,
    protocol: persisted.protocol,
    provider: asTrimmedString(providerResponse.provider),
    environment: asTrimmedString(providerResponse.environment),
    lastAttemptStatus: persisted.lastAttemptStatus,
  };
});

exports.fiscalReconcileProcessingInvoices = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);

  const rawInvoiceIds = Array.isArray(data?.invoiceIds) ? data.invoiceIds : [];
  const invoiceIds = rawInvoiceIds
    .map((value: unknown) => String(value ?? '').trim())
    .filter((value: string) => value.length > 0)
    .slice(0, 20);
  if (invoiceIds.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'invoiceIds obrigatorio para reconciliar notas em processamento.',
    );
  }

  const settingsRef = admin.firestore().collection('company_settings').doc(claims.companyId);
  const settingsSnap = await settingsRef.get();
  const settingsData = await mergeFiscalSecureSettings(
    claims.companyId,
    asRecord(settingsSnap.data()),
  );
  const setup = asRecord(settingsData.fiscalRealIntegration);
  if (
    !providerIsFocus(asTrimmedString(setup.provider)) &&
    !asTrimmedString(setup.apiBaseUrl)
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configure a integracao fiscal real antes de reconciliar notas em processamento.',
    );
  }

  const results: Array<Record<string, unknown>> = [];
  let updatedCount = 0;
  let failedCount = 0;

  for (const invoiceId of invoiceIds) {
    const invoiceRef = admin.firestore().collection('service_invoices').doc(invoiceId);
    const invoiceSnap = await invoiceRef.get();
    if (!invoiceSnap.exists) {
      failedCount += 1;
      results.push({
        invoiceId,
        ok: false,
        message: 'Nota fiscal nao encontrada.',
      });
      continue;
    }

    const invoiceData = invoiceSnap.data() ?? {};
    try {
      assertCompany(String(invoiceData.companyId ?? ''), claims);
      const providerResponse = await callFiscalProvider({
        setup,
        operation: 'query',
        invoiceId,
        invoiceData,
        claims,
      });
      const persisted = await persistOfficialInvoiceStatus({
        invoiceRef,
        invoiceData,
        providerResponse,
      });
      await writeAudit({
        claims,
        module: 'fiscal',
        action: 'reconcile_processing_invoice',
        entityPath: 'service_invoices',
        entityId: invoiceId,
        before: null,
        after: {
          status: persisted.status,
          officialNumber: persisted.officialNumber,
          officialPortalUrl: persisted.officialPortalUrl,
          protocol: persisted.protocol,
          provider: asTrimmedString(providerResponse.provider),
          environment: asTrimmedString(providerResponse.environment),
          lastAttemptStatus: persisted.lastAttemptStatus,
        },
      });
      if (
        persisted.status.toUpperCase() === 'APPROVED' ||
        persisted.officialNumber.trim().length > 0
      ) {
        await ensureFinanceMovementForInvoice({
          invoiceRef,
          invoiceId,
          invoiceData,
          claims,
          status: persisted.status,
          officialNumber: persisted.officialNumber,
        });
        await mergeFiscalHomologationChecklist({
          companyId: claims.companyId,
          patch: {
            providerConnectionValidated: true,
            pilotInvoiceValidated: true,
          },
        });
      }
      updatedCount += 1;
      results.push({
        invoiceId,
        ok: true,
        status: persisted.status,
        officialNumber: persisted.officialNumber,
        lastAttemptStatus: persisted.lastAttemptStatus,
      });
    } catch (error: unknown) {
      const message = await persistInvoiceAttemptFailure({
        invoiceRef,
        invoiceId,
        claims,
        attemptStatus: 'QUERY_FAILED',
        fallbackMessage: 'Falha ao reconciliar nota em processamento.',
        auditAction: 'reconcile_processing_invoice_failed',
        error,
      });
      failedCount += 1;
      results.push({
        invoiceId,
        ok: false,
        message,
      });
    }
  }

  return {
    ok: failedCount === 0,
    updatedCount,
    failedCount,
    results,
  };
});

exports.fiscalDiagnoseServiceCatalog = HEAVY_RUNTIME.https.onCall(async (data, context) => {
  const claims = assertClaims(context);
  assertRole(claims, ['OWNER', 'MANAGER', 'ACCOUNTANT']);

  const applyFix = Boolean((data as any)?.applyFix);
  const dryRun = !applyFix;
  const settingsSnap = await admin
    .firestore()
    .collection('company_settings')
    .doc(claims.companyId)
    .get();
  const settingsData = asRecord(settingsSnap.data());
  const integrationSetup = asRecord(settingsData.fiscalRealIntegration);
  const usesFocusNational =
    providerIsFocus(asTrimmedString(integrationSetup.provider)) &&
    asTrimmedString(integrationSetup.focusNfseApi).toLowerCase() === 'national';

  const onlyDigitsLocal = (value: unknown): string =>
    String(value ?? '')
      .replace(/\D/g, '')
      .trim();

  const normalizeCnaeLocal = (value: unknown): string => {
    const digits = onlyDigitsLocal(value);
    if (!digits) return '';
    if (digits.length === 7) return digits;
    if (digits.length === 8 && digits.endsWith('0')) return digits.substring(0, 7);
    if (digits.length > 7) return digits.substring(0, 7);
    return digits;
  };

  const formatNationalSubitem = (digitsInput: string): string => {
    const digits = onlyDigitsLocal(digitsInput);
    if (!digits) return '';
    const padded =
      digits.length === 5 ? `0${digits}` : digits.length === 4 ? `00${digits}` : digits;
    if (padded.length < 6) return digitsInput.trim();
    const code = padded.substring(0, 6);
    return `${code.substring(0, 2)}.${code.substring(2, 4)}.${code.substring(4, 6)}`;
  };

  const suggestNationalCode = (params: {
    serviceCodeRaw: string;
    municipalCodeRaw: string;
    cnae: string;
    name: string;
  }): { code: string; reason: string } => {
    const serviceDigits = onlyDigitsLocal(params.serviceCodeRaw);
    const municipalDigits = onlyDigitsLocal(params.municipalCodeRaw);
    const familyDigits = serviceDigits || municipalDigits;
    const name = (params.name || '').toLowerCase();
    const cnae = params.cnae;

    const is702Family = familyDigits === '702' || familyDigits.startsWith('702');
    const is705Family = familyDigits === '705' || familyDigits.startsWith('705');

    const mentionsInstall = name.includes('instal');
    const mentionsMaint = name.includes('manut');
    const mentionsRepair =
      name.includes('repar') ||
      name.includes('corret') ||
      name.includes('prevent') ||
      name.includes('conserv');
    const mentionsAssist = name.includes('assist');
    const mentionsTech = name.includes('tecnic') || name.includes('tecnica');
    const mentionsBuilding =
      name.includes('edif') ||
      name.includes('predi') ||
      name.includes('imovel') ||
      name.includes('obra') ||
      name.includes('reforma');
    const mentionsRoads =
      name.includes('estrad') || name.includes('ponte') || name.includes('porto');

    // CNAE 4321500 (instalação elétrica): align with backend heuristics and your workflow
    if (cnae === '4321500') {
      if (mentionsInstall && (is702Family || familyDigits.length < 6)) {
        return { code: '070202', reason: 'CNAE 4321500 + instal* => 07.02.02 (070202)' };
      }
      if (is705Family || familyDigits.length < 6) {
        if (mentionsAssist) {
          // Assistencia tecnica costuma cair fora da familia 07; exigir revisao do contador.
          return { code: '', reason: 'Assistencia tecnica: exigir codigo explicito do contador.' };
        }
        if (mentionsTech) {
          return { code: '', reason: 'Servico tecnico: exigir codigo explicito do contador.' };
        }
        if (mentionsMaint || mentionsRepair) {
          // Predial/edificacao -> 07.05.01 (070501). Sem indicio de predial, exigir codigo explicito.
          const isPredial =
            name.includes('predial') ||
            name.includes('edific') ||
            name.includes('predi') ||
            name.includes('imovel') ||
            name.includes('condomin') ||
            name.includes('quadro') ||
            name.includes('edificio');
          if (isPredial) {
            return { code: '070501', reason: 'CNAE 4321500 + manut/repar predial => 07.05.01 (070501)' };
          }
          return { code: '', reason: 'Manutencao eletrica sem indicio predial: exigir codigo explicito do contador.' };
        }
      }
    }

    // Construction repair category based on official LC 116 wording:
    // 070501 = edificios e congeneres; 070502 = estradas/pontes/portos e congeneres
    if (mentionsBuilding) {
      return { code: '070501', reason: 'Texto sugere reparo/reforma de edificios => 07.05.01 (070501)' };
    }
    if (mentionsRoads) {
      return { code: '070502', reason: 'Texto sugere reparo/reforma de estradas/pontes/portos => 07.05.02 (070502)' };
    }

    return { code: '', reason: 'Sem sugestao segura.' };
  };

  const snap = await admin
    .firestore()
    .collection('fiscal_service_catalog')
    .where('companyId', '==', claims.companyId)
    .get();

  const results: Array<Record<string, unknown>> = [];
  let changed = 0;
  let flagged = 0;

  for (const doc of snap.docs) {
    const raw = doc.data() ?? {};
    const name = String((raw as any).name ?? '').trim();
    const serviceCodeRaw = String((raw as any).serviceCode ?? '').trim();
    const municipalCodeRaw = String((raw as any).municipalServiceCode ?? '').trim();
    const cnae = normalizeCnaeLocal((raw as any).cnae);

    const derived = focusNationalTaxCode({
      service: {
        serviceCode: serviceCodeRaw,
        municipalServiceCode: municipalCodeRaw,
        cnae,
        description: name,
      },
      emitter: { mainCnae: cnae },
      invoiceData: { serviceDescription: name },
    });

    const serviceDigits = onlyDigitsLocal(serviceCodeRaw);
    const municipalDigits = onlyDigitsLocal(municipalCodeRaw);
    const hasCompleteSubitem = serviceDigits.length >= 6 || municipalDigits.length >= 6;
    const suggestion = usesFocusNational
      ? suggestNationalCode({
        serviceCodeRaw,
        municipalCodeRaw,
        cnae,
        name,
      })
      : { code: '', reason: 'Empresa fora do fluxo Focus NFSe Nacional.' };

    const suggestedDisplay = suggestion.code ? formatNationalSubitem(suggestion.code) : '';
    const needsReview = usesFocusNational &&
      (
        (serviceDigits.length > 0 && serviceDigits.length < 6) ||
        (municipalDigits.length > 0 && municipalDigits.length < 6) ||
        (!hasCompleteSubitem && suggestion.code.length === 0)
      );

    const patch: Record<string, unknown> = {};
    if (usesFocusNational) {
      if (suggestion.code) {
        patch.serviceCode = formatNationalSubitem(suggestion.code);
        patch.municipalServiceCode = formatNationalSubitem(suggestion.code);
      } else {
        if (serviceDigits.length >= 6) patch.serviceCode = formatNationalSubitem(serviceDigits);
        if (municipalDigits.length >= 6) {
          patch.municipalServiceCode = formatNationalSubitem(municipalDigits);
        }
      }
    }
    if (cnae && cnae !== String((raw as any).cnae ?? '').trim()) {
      patch.cnae = cnae;
    }
    if (needsReview) {
      if (!String((raw as any).name ?? '').includes('[REVISAR CODIGO]')) {
        patch.name = `${name} [REVISAR CODIGO]`.trim();
      }
      if ((raw as any).active !== false) {
        patch.active = false;
      }
    }

    const willChange = Object.keys(patch).length > 0;
    if (willChange && applyFix) {
      await doc.ref.set(
        {
          ...patch,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      changed += 1;
    }
    if (needsReview) flagged += 1;

    results.push({
      id: doc.id,
      name,
      serviceCode: serviceCodeRaw,
      municipalServiceCode: municipalCodeRaw,
      cnae: String((raw as any).cnae ?? '').trim(),
      normalizedCnae: cnae,
      derivedNationalTaxCode: derived,
      usesFocusNational,
      suggestion: suggestion.code,
      suggestionDisplay: suggestedDisplay,
      suggestionReason: suggestion.reason,
      needsReview,
      wouldPatch: willChange ? patch : null,
    });
  }

  return {
    ok: true,
    dryRun,
    companyId: claims.companyId,
    total: results.length,
    flagged,
    changed,
    items: results,
  };
});

exports.lookupBrazilCnpj = functions.https.onCall(async (data, context) => {
  await assertOperatorFromProfile(context);

  const cnpj = onlyDigits(data?.cnpj);
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError('invalid-argument', 'CNPJ invalido.');
  }

  const cacheKey = `cnpj_${cnpj}`;
  const cached = await readRegistryCache(cacheKey);
  if (cached) {
    const normalized = applyCnpjPayloadSanitizedFields(asRecord(cached));
    return { ...normalized, cacheHit: true };
  }

  const payload = await fetchCnpjPayload(cnpj);
  const normalized = applyCnpjPayloadSanitizedFields(asRecord(payload));
  await writeRegistryCache(cacheKey, normalized);

  return { ...normalized, cacheHit: false };
});

exports.lookupBrazilCnpjForSignup = functions.https.onCall(async (data) => {
  const cnpj = onlyDigits(data?.cnpj);
  if (cnpj.length !== 14) {
    throw new functions.https.HttpsError('invalid-argument', 'CNPJ invalido.');
  }

  const cacheKey = `cnpj_signup_${cnpj}`;
  const cached = await readRegistryCache(cacheKey);
  if (cached) {
    const normalized = applyCnpjPayloadSanitizedFields(asRecord(cached));
    return { ...normalized, cacheHit: true };
  }

  const payload = await fetchCnpjPayload(cnpj);
  const normalized = applyCnpjPayloadSanitizedFields(asRecord(payload));
  await writeRegistryCache(cacheKey, normalized);
  return { ...normalized, cacheHit: false };
});

exports.lookupBrazilCep = functions.https.onCall(async (data, context) => {
  await assertOperatorFromProfile(context);

  const cep = onlyDigits(data?.cep);
  if (cep.length !== 8) {
    throw new functions.https.HttpsError('invalid-argument', 'CEP invalido.');
  }

  const cacheKey = `cep_${cep}`;
  const cached = await readRegistryCache(cacheKey);
  if (cached) {
    return { ...cached, cacheHit: true };
  }

  const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`);
  if (!response.ok) {
    throw new functions.https.HttpsError(
      'not-found',
      'Nao foi possivel localizar dados para este CEP.',
    );
  }

  const raw = (await response.json()) as { erro?: boolean } & Record<string, unknown>;
  if (raw.erro === true) {
    throw new functions.https.HttpsError(
      'not-found',
      'Nao foi possivel localizar dados para este CEP.',
    );
  }

  const payload = mapCepPayload(raw);
  await writeRegistryCache(cacheKey, payload);

  return { ...payload, cacheHit: false };
});

exports.syncFinanceMovementRuntimeSummary = functions.firestore
  .document('finance_movements/{movementId}')
  .onWrite(async (change) => {
    const beforeData = asRecord(change.before.data());
    const afterData = asRecord(change.after.data());
    const companyId =
      asTrimmedString(afterData.companyId) || asTrimmedString(beforeData.companyId);
    if (!companyId) return;

    await admin.firestore().runTransaction(async (tx) => {
      await applyFinanceMovementSummaryDelta(tx, companyId, beforeData, afterData);
    });
  });

exports.syncFiscalInvoiceRuntimeSummary = functions.firestore
  .document('service_invoices/{invoiceId}')
  .onWrite(async (change) => {
    const beforeData = asRecord(change.before.data());
    const afterData = asRecord(change.after.data());
    const companyId =
      asTrimmedString(afterData.companyId) || asTrimmedString(beforeData.companyId);
    if (!companyId) return;

    await rebuildFiscalInvoiceRuntimeSummary(companyId);
  });

initVendasPublicExports(exports as Record<string, unknown>, {
  obterConfigEmail,
  enviarEmailHtml,
  escapeHtml,
});
