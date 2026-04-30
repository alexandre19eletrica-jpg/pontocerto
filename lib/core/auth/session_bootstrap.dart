import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/accountant_company_context_service.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_access_state.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/core/monitoring/runtime_incident_reporter.dart';

final sessionBootstrapReadyProvider = StateProvider<bool>((ref) => false);

class SessionBootstrap extends ConsumerStatefulWidget {
  const SessionBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends ConsumerState<SessionBootstrap> {
  final _accountantContextService = AccountantCompanyContextService();
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    final firebaseAvailable = ref.read(firebaseAvailableProvider);
    if (!firebaseAvailable) {
      ref.read(sessionBootstrapReadyProvider.notifier).state = true;
      return;
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_handleAuthUser);
  }

  Future<void> _handleAuthUser(User? user) async {
    if (!mounted) return;
    if (user == null) {
      ref.read(sessionProvider.notifier).logout();
      RuntimeIncidentReporter.instance.attachSession(null);
      ref.read(sessionBootstrapReadyProvider.notifier).state = true;
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) {
        ref.read(sessionProvider.notifier).logout();
      } else {
        var companyId = data['companyId']?.toString() ?? '';
        final role = (data['role']?.toString() ?? '').trim().toUpperCase();
        if (role == 'ACCOUNTANT' || role == 'CONTADOR') {
          final resolution = await _accountantContextService.resolveAccessibleCompany(
            userId: user.uid,
            userData: data,
          );
          if (!resolution.hasAccessibleCompany) {
            ref
                .read(sessionProvider.notifier)
                .definirSessaoPorMapa(userId: user.uid, dados: data);
            final currentSession = ref.read(sessionProvider);
            RuntimeIncidentReporter.instance.attachSession(currentSession);
            return;
          }
          companyId = resolution.companyId;
          if ((data['currentCompanyId']?.toString().trim() ?? '') != companyId) {
            await _accountantContextService.selectCompany(companyId);
          }
        } else if (companyId.isNotEmpty) {
          if (!isSupremePlatformCompanyId(companyId)) {
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
              ref.read(sessionProvider.notifier).logout();
              return;
            }
          }
        }
        ref
            .read(sessionProvider.notifier)
            .definirSessaoPorMapa(
              userId: user.uid,
              dados: {
                ...data,
                'companyId': companyId,
              },
            );
        final currentSession = ref.read(sessionProvider);
        RuntimeIncidentReporter.instance.attachSession(currentSession);
      }
    } catch (_) {
      ref.read(sessionProvider.notifier).logout();
      RuntimeIncidentReporter.instance.attachSession(null);
    } finally {
      ref.read(sessionBootstrapReadyProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(sessionBootstrapReadyProvider);
    if (!ready) {
      return const Material(
        color: Color(0xFFF4F8FF),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
