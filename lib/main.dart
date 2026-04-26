import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/app/app.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/firebase/firebase_init.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/core/monitoring/runtime_incident_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      RuntimeIncidentReporter.instance.capture(
        source: 'flutter',
        error: details.exception,
        stackTrace: details.stack,
        severity: 'error',
        category: 'ui',
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled async error: $error');
    unawaited(
      RuntimeIncidentReporter.instance.capture(
        source: 'platform_dispatcher',
        error: error,
        stackTrace: stack,
        severity: 'critical',
        category: 'async',
      ),
    );
    return true;
  };

  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFFF4F7FA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              SizedBox(height: 10),
              Text(
                'Ocorreu uma falha de tela. Volte e tente novamente.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  var firebaseDisponivel = true;
  final nomeEmpresaCache = await lerNomeEmpresaCache();
  try {
    await initFirebase();
  } catch (_) {
    firebaseDisponivel = false;
  }

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            firebaseAvailableProvider.overrideWithValue(firebaseDisponivel),
            nomeEmpresaCacheProvider.overrideWith((ref) => nomeEmpresaCache),
          ],
          child: const App(),
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Zone error: $error');
      unawaited(
        RuntimeIncidentReporter.instance.capture(
          source: 'zone',
          error: error,
          stackTrace: stackTrace,
          severity: 'critical',
          category: 'zone',
        ),
      );
    },
  );
}
