import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/accountant_company_context_service.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_access_state.dart';
import 'package:pontocerto/core/monitoring/runtime_incident_reporter.dart';
import 'package:pontocerto/core/platform/platform_access.dart';

/// Carrega [sessionProvider] a partir do utilizador Firebase Auth já autenticado
/// (Firestore `users` + regras de acesso empresa). Também utilizado pelo demo
/// após `signInWithCustomToken` para evitar corrida com o redirect do GoRouter.
Future<void> loadRiverpodSessionForAuthUser({
  required ProviderContainer container,
  required User user,
  required AccountantCompanyContextService accountantCompanyContextService,
}) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null) {
      container.read(sessionProvider.notifier).logout();
      RuntimeIncidentReporter.instance.attachSession(null);
      return;
    }

    var companyId = data['companyId']?.toString() ?? '';
    final role = (data['role']?.toString() ?? '').trim().toUpperCase();
    if (role == 'ACCOUNTANT' || role == 'CONTADOR') {
      final resolution = await accountantCompanyContextService.resolveAccessibleCompany(
        userId: user.uid,
        userData: data,
      );
      if (!resolution.hasAccessibleCompany) {
        container
            .read(sessionProvider.notifier)
            .definirSessaoPorMapa(userId: user.uid, dados: data);
        final currentSession = container.read(sessionProvider);
        RuntimeIncidentReporter.instance.attachSession(currentSession);
        return;
      }
      companyId = resolution.companyId;
      if ((data['currentCompanyId']?.toString().trim() ?? '') != companyId) {
        await accountantCompanyContextService.selectCompany(companyId);
      }
    } else if (companyId.isNotEmpty) {
      if (!isSupremePlatformCompanyId(companyId) &&
          !isPublicDemoWorkspaceCompanyId(companyId)) {
        final settingsSnap = await FirebaseFirestore.instance
            .collection('company_settings')
            .doc(companyId)
            .get();
        final accessState = CompanyAccessState.fromSettings(
          settingsSnap.data() ?? <String, dynamic>{},
          companyId: companyId,
        );
        if (!accessState.allowLogin) {
          await FirebaseAuth.instance.signOut();
          container.read(sessionProvider.notifier).logout();
          RuntimeIncidentReporter.instance.attachSession(null);
          return;
        }
      }
    }
    container.read(sessionProvider.notifier).definirSessaoPorMapa(
          userId: user.uid,
          dados: {
            ...data,
            'companyId': companyId,
          },
        );
    final currentSession = container.read(sessionProvider);
    RuntimeIncidentReporter.instance.attachSession(currentSession);
  } catch (_) {
    container.read(sessionProvider.notifier).logout();
    RuntimeIncidentReporter.instance.attachSession(null);
  }
}
