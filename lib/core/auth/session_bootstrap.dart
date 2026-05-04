import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/accountant_company_context_service.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/auth/session_hydrate_from_auth.dart';
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
      final container = ProviderScope.containerOf(context);
      await loadRiverpodSessionForAuthUser(
        container: container,
        user: user,
        accountantCompanyContextService: _accountantContextService,
      );
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
