import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> syncClaimsForCurrentUser() async {
  try {
    await FirebaseFunctions.instance.httpsCallable('authSyncClaims').call();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return true;
  } on FirebaseFunctionsException {
    // Fluxo de login/cadastro nao deve falhar se a callable ainda nao estiver deployada.
    return false;
  } catch (_) {
    return false;
  }
}
