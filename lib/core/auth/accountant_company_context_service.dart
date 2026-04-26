import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pontocerto/core/company/company_access_state.dart';

class AccountantCompanyContextResolution {
  const AccountantCompanyContextResolution({
    required this.companyId,
    required this.blockedMessage,
    required this.hasLinkedCompanies,
  });

  final String companyId;
  final String blockedMessage;
  final bool hasLinkedCompanies;

  bool get hasAccessibleCompany => companyId.trim().isNotEmpty;
}

class AccountantCompanyContextService {
  AccountantCompanyContextService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<AccountantCompanyContextResolution> resolveAccessibleCompany({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    final linksSnap = await _firestore
        .collection('accountant_links')
        .where('accountantUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    final preferredCurrentCompanyId =
        userData['currentCompanyId']?.toString().trim() ?? '';
    final fallbackCompanyId = userData['companyId']?.toString().trim() ?? '';

    final scoredLinks = linksSnap.docs
        .map((doc) {
          final data = doc.data();
          final updatedAt = data['updatedAt'];
          final updatedAtMillis = updatedAt is Timestamp
              ? updatedAt.millisecondsSinceEpoch
              : updatedAt is DateTime
              ? updatedAt.millisecondsSinceEpoch
              : updatedAt is String
              ? (DateTime.tryParse(updatedAt)?.millisecondsSinceEpoch ?? 0)
              : 0;
          return (
            companyId: data['companyId']?.toString().trim() ?? '',
            updatedAtMillis: updatedAtMillis,
          );
        })
        .where((entry) => entry.companyId.isNotEmpty)
        .toList()
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));

    final orderedCompanyIds = <String>[
      if (preferredCurrentCompanyId.isNotEmpty) preferredCurrentCompanyId,
      if (fallbackCompanyId.isNotEmpty &&
          fallbackCompanyId != preferredCurrentCompanyId)
        fallbackCompanyId,
      ...scoredLinks.map((entry) => entry.companyId),
    ].toSet().toList();

    String blockedMessage = '';
    for (final companyId in orderedCompanyIds) {
      final settingsSnap = await _firestore
          .collection('company_settings')
          .doc(companyId)
          .get();
      final accessState = CompanyAccessState.fromSettings(
        settingsSnap.data() ?? <String, dynamic>{},
        companyId: companyId,
      );
      if (accessState.allowLogin) {
        return AccountantCompanyContextResolution(
          companyId: companyId,
          blockedMessage: '',
          hasLinkedCompanies: orderedCompanyIds.isNotEmpty,
        );
      }
      if (blockedMessage.isEmpty && accessState.message.trim().isNotEmpty) {
        blockedMessage = accessState.message.trim();
      }
    }

    return AccountantCompanyContextResolution(
      companyId: '',
      blockedMessage: blockedMessage,
      hasLinkedCompanies: orderedCompanyIds.isNotEmpty,
    );
  }

  Future<void> selectCompany(String companyId) async {
    final normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await _functions
          .httpsCallable('authSelectAccountantCompany')
          .call(<String, dynamic>{'companyId': normalizedCompanyId});
      await currentUser.getIdToken(true);
      return;
    } on FirebaseFunctionsException {
      await _firestore.collection('users').doc(currentUser.uid).set({
        'currentCompanyId': normalizedCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
