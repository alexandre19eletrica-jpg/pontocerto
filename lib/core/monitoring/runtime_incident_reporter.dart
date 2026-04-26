import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pontocerto/core/auth/session.dart';

class RuntimeIncidentReporter {
  RuntimeIncidentReporter._();

  static final RuntimeIncidentReporter instance = RuntimeIncidentReporter._();

  Session? _session;
  final List<_PendingIncident> _pending = <_PendingIncident>[];
  String? _currentScreenLabel;
  String? _currentRoute;
  String? _appVersionLabel;
  Future<void>? _packageInfoFuture;

  void attachSession(Session? session) {
    _session = session;
    if (session != null) {
      unawaited(_flushPending());
    }
  }

  void updateContext({
    String? screenLabel,
    String? route,
  }) {
    _currentScreenLabel = _normalizeText(screenLabel);
    _currentRoute = _normalizeText(route);
  }

  Future<void> capture({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    String severity = 'error',
    String category = 'runtime',
    String? screenLabel,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _ensurePackageInfo();
      final normalizedScreenLabel =
          _normalizeText(screenLabel) ?? _currentScreenLabel ?? _currentRoute;
      final normalizedExtra = _normalizeExtra(extra ?? const <String, dynamic>{});
      final message = _normalizeError(error);
      final fingerprint = _fingerprintFrom(
        source: source,
        category: category,
        message: message,
        screenLabel: normalizedScreenLabel,
      );
      final payload = _PendingIncident(
        source: source,
        message: message,
        stackTrace: _shortStack(stackTrace),
        severity: severity,
        category: category,
        screenLabel: normalizedScreenLabel,
        extra: <String, dynamic>{
          ...normalizedExtra,
          'route': _currentRoute ?? Uri.base.path,
          'currentUrl': kIsWeb ? Uri.base.toString() : '',
          'platformLabel': _platformLabel(),
          'appVersion': _appVersionLabel ?? '',
          'errorType': error.runtimeType.toString(),
        },
        fingerprint: fingerprint,
        capturedAt: DateTime.now(),
      );

      final session = _session;
      if (session == null) {
        if (_pending.length >= 20) {
          _pending.removeAt(0);
        }
        _pending.add(payload);
        return;
      }

      await _write(session, payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RuntimeIncidentReporter.capture failed: $e');
      }
    }
  }

  Future<void> _flushPending() async {
    final session = _session;
    if (session == null || _pending.isEmpty) return;
    final snapshot = List<_PendingIncident>.from(_pending);
    _pending.clear();
    for (final item in snapshot) {
      try {
        await _write(session, item);
      } catch (_) {
        // Melhor esforco. Mantem a app rodando.
      }
    }
  }

  Future<void> _write(Session session, _PendingIncident payload) async {
    final now = FieldValue.serverTimestamp();
    final ref = FirebaseFirestore.instance
        .collection('runtime_incidents')
        .doc('incident_${payload.fingerprint}');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final previous = snapshot.data() ?? <String, dynamic>{};
      final occurrenceCount =
          ((previous['occurrenceCount'] as num?)?.toInt() ?? 0) + 1;

      transaction.set(ref, {
        'companyId': session.companyId,
        'reporterUserId': session.userId,
        'reporterName': session.nome,
        'reporterRole': session.role.name,
        'source': payload.source,
        'category': payload.category,
        'severity': payload.severity,
        'status': 'open',
        'message': payload.message,
        'stackTrace': payload.stackTrace,
        'screenLabel': payload.screenLabel,
        'extra': payload.extra,
        'fingerprint': payload.fingerprint,
        'occurrenceCount': occurrenceCount,
        'firstSeenAt': snapshot.exists ? previous['firstSeenAt'] ?? now : now,
        'lastSeenAt': now,
        'capturedAtClient': payload.capturedAt.toIso8601String(),
        'createdAt': snapshot.exists ? previous['createdAt'] ?? now : now,
        'updatedAt': now,
        'resolvedAt': FieldValue.delete(),
        'ignoredAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _ensurePackageInfo() async {
    if (_appVersionLabel != null) return;
    _packageInfoFuture ??= () async {
      try {
        final info = await PackageInfo.fromPlatform();
        _appVersionLabel = '${info.version}+${info.buildNumber}';
      } catch (_) {
        _appVersionLabel = '';
      }
    }();
    await _packageInfoFuture;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String? _normalizeText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> _normalizeExtra(Map<String, dynamic> extra) {
    final normalized = <String, dynamic>{};
    for (final entry in extra.entries) {
      normalized[entry.key] = _normalizeValue(entry.value);
    }
    return normalized;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      if (value.isNaN || value.isInfinite) {
        return value.toString();
      }
      return value;
    }
    if (value is String || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Iterable) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, dynamic item) => MapEntry(key.toString(), _normalizeValue(item)),
      );
    }
    return value.toString();
  }

  String _fingerprintFrom({
    required String source,
    required String category,
    required String message,
    required String? screenLabel,
  }) {
    final raw = '${source.trim()}|${category.trim()}|${screenLabel ?? ''}|${message.trim()}';
    var hash = 0;
    for (final codeUnit in raw.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _normalizeError(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'Falha sem mensagem';
    if (text.length <= 500) return text;
    return '${text.substring(0, 497)}...';
  }

  String _shortStack(StackTrace? stackTrace) {
    if (stackTrace == null) return '';
    final text = stackTrace.toString().trim();
    if (text.length <= 4000) return text;
    return '${text.substring(0, 3997)}...';
  }
}

class _PendingIncident {
  const _PendingIncident({
    required this.source,
    required this.message,
    required this.stackTrace,
    required this.severity,
    required this.category,
    required this.screenLabel,
    required this.extra,
    required this.fingerprint,
    required this.capturedAt,
  });

  final String source;
  final String message;
  final String stackTrace;
  final String severity;
  final String category;
  final String? screenLabel;
  final Map<String, dynamic> extra;
  final String fingerprint;
  final DateTime capturedAt;
}
