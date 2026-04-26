const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function main() {
  const email = String(process.argv[2] || '').trim().toLowerCase();
  if (!email) {
    throw new Error('Informe o email. Ex.: node promote-user-owner.js alexandre19eletrica@gmail.com');
  }

  const userRecord = await admin.auth().getUserByEmail(email);
  const userRef = admin.firestore().collection('users').doc(userRecord.uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new Error(`Documento users/${userRecord.uid} nao encontrado para ${email}.`);
  }

  const data = userSnap.data() || {};
  const companyId = String(data.companyId || '').trim();
  const nome = String(data.nome || userRecord.displayName || '').trim();

  if (!companyId) {
    throw new Error(`O usuario ${email} nao possui companyId no Firestore.`);
  }

  await userRef.set(
    {
      role: 'OWNER',
      nome,
      email,
      employeeId: userRecord.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    companyId,
    role: 'OWNER',
    employeeId: userRecord.uid,
  });

  console.log(
    JSON.stringify(
      {
        ok: true,
        uid: userRecord.uid,
        email,
        companyId,
        role: 'OWNER',
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error?.message || error);
  process.exit(1);
});
