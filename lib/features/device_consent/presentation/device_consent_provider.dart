import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/device_consent/domain/device_consent.dart';

class DeviceConsentsNotifier extends Notifier<List<DeviceConsent>> {
  static const String legalTermsVersion = 'v2.0-2026-03-07';
  static const String legalStatement =
      'Declaro, de forma livre e informada, que autorizo o uso do meu celular pessoal '
      'como ferramenta de trabalho no app da empresa para registro de ponto e rotinas operacionais, '
      'ciente das condicoes do termo e da possibilidade de revogacao.';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<DeviceConsent> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return <DeviceConsent>[];
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <DeviceConsent>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('device_consents')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('device_consents')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)];
      },
      onError: (error, stackTrace) {
        // Mantem o estado atual em falha temporaria.
      },
    );
  }

  DeviceConsent _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final acceptedAtRaw = map['acceptedAt'];
    final revokedAtRaw = map['revokedAt'];

    final acceptedAt = acceptedAtRaw is Timestamp
        ? acceptedAtRaw.toDate()
        : DateTime.tryParse(acceptedAtRaw?.toString() ?? '');
    final revokedAt = revokedAtRaw is Timestamp
        ? revokedAtRaw.toDate()
        : DateTime.tryParse(revokedAtRaw?.toString() ?? '');

    return DeviceConsent(
      employeeId: map['employeeId']?.toString() ?? doc.id,
      companyId: map['companyId']?.toString() ?? '',
      accepted: map['accepted'] == true,
      acceptedStatement: map['acceptedStatement']?.toString() ?? '',
      acceptedAt: acceptedAt,
      revokedAt: revokedAt,
      termsVersion: map['termsVersion']?.toString() ?? legalTermsVersion,
      appVersion: map['appVersion']?.toString(),
      devicePlatform: map['devicePlatform']?.toString(),
      timeZone: map['timeZone']?.toString(),
      acceptedByUid: map['acceptedByUid']?.toString(),
    );
  }

  Future<void> acceptOwnDeviceUse({String termsVersion = legalTermsVersion}) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final info = await PackageInfo.fromPlatform();
    final appVersion = '${info.version}+${info.buildNumber}';

    await FirebaseFirestore.instance.collection('device_consents').doc(uid).set({
      'companyId': sessao.companyId,
      'employeeId': uid,
      'accepted': true,
      'acceptedByUid': uid,
      'acceptedStatement': legalStatement,
      'acceptedAt': FieldValue.serverTimestamp(),
      'revokedAt': null,
      'termsVersion': termsVersion,
      'appVersion': appVersion,
      'devicePlatform': platform,
      'timeZone': DateTime.now().timeZoneName,
      'ipAddress': 'not_collected_client_side',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> revokeOwnDeviceUse() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;

    await FirebaseFirestore.instance.collection('device_consents').doc(uid).set({
      'companyId': sessao.companyId,
      'employeeId': uid,
      'accepted': false,
      'acceptedByUid': uid,
      'acceptedStatement': legalStatement,
      'termsVersion': legalTermsVersion,
      'revokedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final deviceConsentsProvider = NotifierProvider<DeviceConsentsNotifier, List<DeviceConsent>>(
  DeviceConsentsNotifier.new,
);
