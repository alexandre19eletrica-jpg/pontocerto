const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const sendgridMail = require("@sendgrid/mail");

admin.initializeApp();

function gerarSenhaTemporaria() {
  const base = crypto.randomBytes(9).toString("base64url");
  return `${base}A1!`;
}

function normalizarRole(valor) {
  return String(valor || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function roleParaFirestore(valor) {
  const normalizado = normalizarRole(valor);
  if (normalizado === "owner") return "OWNER";
  if (normalizado === "manager") return "MANAGER";
  return "EMPLOYEE";
}

async function carregarUsuario(uid) {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Perfil do usuario autenticado nao encontrado.",
    );
  }
  const data = snap.data() || {};
  return {snap, data};
}

function validarGestaoEmpresa(perfil) {
  const role = roleParaFirestore(perfil.role);
  if (role !== "OWNER" && role !== "MANAGER") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Apenas OWNER ou MANAGER pode executar esta acao.",
    );
  }
}

function obterConfigEmail() {
  const cfg = functions.config();
  const sendgridKey = cfg?.sendgrid?.key || "";
  const fromEmail = cfg?.mail?.from || "";
  const apkUrl =
    cfg?.app?.apk_url ||
    "https://play.google.com/apps/internaltest/4701693750364446376";
  return {
    sendgridKey: String(sendgridKey).trim(),
    fromEmail: String(fromEmail).trim(),
    apkUrl: String(apkUrl).trim(),
  };
}

async function enviarEmailBoasVindasFuncionario({
  email,
  nome,
  nomeEmpresa,
  resetLink,
  apkUrl,
  fromEmail,
}) {
  const assunto = `Acesso ao PontoCerto - ${nomeEmpresa || "Sua empresa"}`;
  const html = `
    <div style="font-family: Arial, sans-serif; color: #111;">
      <h2>Bem-vindo(a), ${nome}!</h2>
      <p>Seu acesso ao app <strong>PontoCerto</strong> foi criado.</p>
      <p><a href="${resetLink}">Clique aqui para definir sua senha</a></p>
      ${
        apkUrl
          ? `<p><a href="${apkUrl}">Clique aqui para instalar o aplicativo pela Play Store</a></p>`
          : '<p><a href="https://play.google.com/apps/internaltest/4701693750364446376">Clique aqui para instalar o aplicativo pela Play Store</a></p>'
      }
      <p>Depois de definir a senha, abra o app e entre com seu email.</p>
    </div>
  `;

  await sendgridMail.send({
    to: email,
    from: fromEmail,
    subject: assunto,
    html,
  });
}

exports.createEmployeeAccess = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Usuario nao autenticado.",
    );
  }

  const companyId = String(data?.companyId || "").trim();
  const nome = String(data?.nome || "").trim();
  const email = String(data?.email || "").trim().toLowerCase();
  const role = roleParaFirestore(data?.role);

  if (!companyId || !nome || !email) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Dados obrigatorios ausentes.",
    );
  }

  const authUid = context.auth.uid;
  const {data: perfilSolicitante} = await carregarUsuario(authUid);
  validarGestaoEmpresa(perfilSolicitante);

  if (String(perfilSolicitante.companyId || "") !== companyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "CompanyId invalido para o usuario autenticado.",
    );
  }

  const companyData = perfilSolicitante.companyData || null;
  const companyName = String(
    perfilSolicitante.companyName ||
      (companyData && companyData.nomeFantasia) ||
      "",
  ).trim();

  let userRecord;
  try {
    const senhaTemporaria = gerarSenhaTemporaria();
    userRecord = await admin.auth().createUser({
      email,
      password: senhaTemporaria,
      displayName: nome,
      emailVerified: false,
    });
  } catch (error) {
    if (error && error.code === "auth/email-already-exists") {
      userRecord = await admin.auth().getUserByEmail(email);
    } else {
      throw new functions.https.HttpsError(
        "internal",
        "Nao foi possivel criar o usuario no Auth.",
      );
    }
  }

  await admin.firestore().collection("users").doc(userRecord.uid).set({
    companyId,
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
  }, {merge: true});

  await admin.auth().updateUser(userRecord.uid, {
    displayName: nome,
  });

  let emailSent = false;
  const emailCfg = obterConfigEmail();
  if (emailCfg.sendgridKey && emailCfg.fromEmail) {
    try {
      sendgridMail.setApiKey(emailCfg.sendgridKey);
      const resetLink = await admin.auth().generatePasswordResetLink(email);
      await enviarEmailBoasVindasFuncionario({
        email,
        nome,
        nomeEmpresa: companyName,
        resetLink,
        apkUrl: emailCfg.apkUrl,
        fromEmail: emailCfg.fromEmail,
      });
      emailSent = true;
    } catch (error) {
      emailSent = false;
    }
  }

  return {
    ok: true,
    uid: userRecord.uid,
    emailSent,
  };
});

exports.syncCompanyProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Usuario nao autenticado.",
    );
  }

  const authUid = context.auth.uid;
  const {data: perfilSolicitante} = await carregarUsuario(authUid);
  validarGestaoEmpresa(perfilSolicitante);

  const companyId = String(data?.companyId || "").trim();
  const companyName = String(data?.companyName || "").trim();
  const companyData = data?.companyData;

  if (!companyId || !companyName || !companyData || typeof companyData !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "companyId, companyName e companyData sao obrigatorios.",
    );
  }

  if (String(perfilSolicitante.companyId || "") !== companyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "CompanyId invalido para o usuario autenticado.",
    );
  }

  const query = await admin.firestore()
    .collection("users")
    .where("companyId", "==", companyId)
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

  return {ok: true, atualizados};
});

exports.updateEmployeeProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Usuario nao autenticado.",
    );
  }

  const authUid = context.auth.uid;
  const {data: perfilSolicitante} = await carregarUsuario(authUid);
  validarGestaoEmpresa(perfilSolicitante);

  const employeeUid = String(data?.employeeUid || "").trim();
  const companyId = String(data?.companyId || "").trim();
  const nome = String(data?.nome || "").trim();
  const role = roleParaFirestore(data?.role);
  const documento = data?.documento == null ? null : String(data.documento).trim();
  const pix = data?.pix == null ? null : String(data.pix).trim();
  const telefone = data?.telefone == null ? null : String(data.telefone).trim();
  const email = data?.email == null ? null : String(data.email).trim().toLowerCase();
  const endereco = data?.endereco == null ? null : String(data.endereco).trim();
  const apelido = data?.apelido == null ? null : String(data.apelido).trim();

  if (!employeeUid || !companyId || !nome) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "employeeUid, companyId e nome sao obrigatorios.",
    );
  }

  if (String(perfilSolicitante.companyId || "") !== companyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "CompanyId invalido para o usuario autenticado.",
    );
  }

  const employeeRef = admin.firestore().collection("users").doc(employeeUid);
  const employeeSnap = await employeeRef.get();
  if (!employeeSnap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "Perfil do funcionario nao encontrado.",
    );
  }

  const employeeData = employeeSnap.data() || {};
  if (String(employeeData.companyId || "") !== companyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Funcionario fora da empresa informada.",
    );
  }

  await employeeRef.set({
    companyId,
    role,
    nome,
    documento,
    pix,
    telefone,
    email,
    endereco,
    apelido,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  const updateAuthPayload = {displayName: nome};
  if (email) {
    updateAuthPayload.email = email;
  }

  try {
    await admin.auth().updateUser(employeeUid, updateAuthPayload);
  } catch (_) {
    // Nao bloqueia persistencia do Firestore se apenas o Auth falhar.
  }

  return {ok: true};
});
