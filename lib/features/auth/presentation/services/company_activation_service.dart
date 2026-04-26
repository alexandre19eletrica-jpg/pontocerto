import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';

class CompanyActivationService {
  CompanyActivationService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<void> ensureSignedIn({
    required String email,
    required String password,
  }) async {
    if (_auth.currentUser != null) return;
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await syncClaimsForCurrentUser();
  }

  Future<void> redeemCode(String code) async {
    final callable = _functions.httpsCallable('redeemCompanyActivationCode');
    await callable.call(<String, dynamic>{'code': code});
    await syncClaimsForCurrentUser();
  }

  Future<Map<String, dynamic>?> currentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<Map<String, dynamic>?> currentCompanySettings() async {
    final profile = await currentUserProfile();
    final companyId = profile?['companyId']?.toString() ?? '';
    if (companyId.isEmpty) return null;
    final snap = await _firestore.collection('company_settings').doc(companyId).get();
    return snap.data();
  }
}
