import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';

import 'sales_analytics_service.dart';

class PublicDemoAccessResult {
  const PublicDemoAccessResult({
    required this.targetRoute,
    required this.profile,
    required this.visitors,
    required this.companyUnique,
    required this.accountantUnique,
  });

  final String targetRoute;
  final String profile;
  final int visitors;
  final int companyUnique;
  final int accountantUnique;

  factory PublicDemoAccessResult.fromMap(Map<String, dynamic> map) {
    return PublicDemoAccessResult(
      targetRoute: map['targetRoute']?.toString() ?? '/home',
      profile: map['profile']?.toString() ?? '',
      visitors: (map['visitors'] as num?)?.toInt() ?? 0,
      companyUnique: (map['companyUnique'] as num?)?.toInt() ?? 0,
      accountantUnique: (map['accountantUnique'] as num?)?.toInt() ?? 0,
    );
  }
}

class PublicDemoAccessService {
  PublicDemoAccessService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    SalesAnalyticsService? analytics,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _auth = auth ?? FirebaseAuth.instance,
       _analytics = analytics ?? SalesAnalyticsService();

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final SalesAnalyticsService _analytics;

  Future<PublicDemoAccessResult> openDemo({
    required String profile,
    required String pagePath,
  }) async {
    final callable = _functions.httpsCallable('publicOpenDemoAccess');
    final tracking = await _analytics.currentTrackingPayload();
    try {
      await _auth.signOut();
    } catch (_) {}
    final response = await callable.call(<String, dynamic>{
      'profile': profile,
      'pagePath': pagePath,
      ...tracking,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final customToken = data['customToken']?.toString() ?? '';
    if (customToken.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Token demo ausente.',
      );
    }
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _auth.signInWithCustomToken(customToken);
    } on FirebaseAuthException {
      await _auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _auth.signInWithCustomToken(customToken);
    }
    await syncClaimsForCurrentUser();
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}

    return PublicDemoAccessResult.fromMap(data);
  }

  Future<PublicDemoAccessResult> getSummary() async {
    final callable = _functions.httpsCallable('publicGetDemoAccessSummary');
    final response = await callable.call(<String, dynamic>{});
    return PublicDemoAccessResult.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
