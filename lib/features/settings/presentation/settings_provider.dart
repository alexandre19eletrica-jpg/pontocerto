import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';

class CompanySettings {
  const CompanySettings({
    required this.enableGpsCameraPunch,
    required this.enableEmployeeDebtSuggestion,
    required this.enableAttachmentsOnJustification,
  });

  final bool enableGpsCameraPunch;
  final bool enableEmployeeDebtSuggestion;
  final bool enableAttachmentsOnJustification;

  CompanySettings copyWith({
    bool? enableGpsCameraPunch,
    bool? enableEmployeeDebtSuggestion,
    bool? enableAttachmentsOnJustification,
  }) {
    return CompanySettings(
      enableGpsCameraPunch: enableGpsCameraPunch ?? this.enableGpsCameraPunch,
      enableEmployeeDebtSuggestion:
          enableEmployeeDebtSuggestion ?? this.enableEmployeeDebtSuggestion,
      enableAttachmentsOnJustification: enableAttachmentsOnJustification ??
          this.enableAttachmentsOnJustification,
    );
  }
}

class SettingsNotifier extends Notifier<CompanySettings> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  CompanySettings build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return const CompanySettings(
      enableGpsCameraPunch: false,
      enableEmployeeDebtSuggestion: false,
      enableAttachmentsOnJustification: false,
    );
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) return;

    _sub = FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .snapshots()
        .listen((doc) {
      final map = doc.data() ?? <String, dynamic>{};
      state = CompanySettings(
        enableGpsCameraPunch: map['enableGpsCameraPunch'] == true,
        enableEmployeeDebtSuggestion: map['enableEmployeeDebtSuggestion'] == true,
        enableAttachmentsOnJustification: map['enableAttachmentsOnJustification'] == true,
      );
    }, onError: (_) {
      // Mantem estado atual se leitura remota falhar temporariamente.
    });
  }

  Future<void> toggleGpsCameraPunch() async {
    state = state.copyWith(enableGpsCameraPunch: !state.enableGpsCameraPunch);
    await _persist();
    _registrarAuditoria('toggleGpsCameraPunch');
  }

  Future<void> toggleDebtSuggestion() async {
    state = state.copyWith(
      enableEmployeeDebtSuggestion: !state.enableEmployeeDebtSuggestion,
    );
    await _persist();
    _registrarAuditoria('toggleDebtSuggestion');
  }

  Future<void> toggleAttachments() async {
    state = state.copyWith(
      enableAttachmentsOnJustification:
          !state.enableAttachmentsOnJustification,
    );
    await _persist();
    _registrarAuditoria('toggleAttachments');
  }

  Future<void> _persist() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .set({
      'companyId': sessao.companyId,
      'enableGpsCameraPunch': state.enableGpsCameraPunch,
      'enableEmployeeDebtSuggestion': state.enableEmployeeDebtSuggestion,
      'enableAttachmentsOnJustification': state.enableAttachmentsOnJustification,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'settings', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, CompanySettings>(
  SettingsNotifier.new,
);

class AppUpdateSettings {
  const AppUpdateSettings({
    required this.active,
    required this.latestVersion,
    required this.message,
    required this.force,
    required this.updateUrl,
  });

  final bool active;
  final String latestVersion;
  final String message;
  final bool force;
  final String updateUrl;
}

final appUpdateSettingsProvider = StreamProvider<AppUpdateSettings>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);

  if (!firebaseDisponivel || sessao == null) {
    return Stream.value(const AppUpdateSettings(
      active: false,
      latestVersion: '',
      message: '',
      force: false,
      updateUrl: '',
    ));
  }

  return FirebaseFirestore.instance
      .collection('app_updates')
      .doc(sessao.companyId)
      .snapshots()
      .map((doc) {
    final map = doc.data() ?? <String, dynamic>{};
    return AppUpdateSettings(
      active: map['active'] == true,
      latestVersion: map['latestVersion']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      force: map['force'] == true,
      updateUrl: map['updateUrl']?.toString() ?? '',
    );
  });
});

extension SettingsAppUpdateActions on SettingsNotifier {
  Future<void> saveAppUpdateSettings({
    required bool active,
    required bool force,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final docRef = FirebaseFirestore.instance.collection('app_updates').doc(sessao.companyId);
    final atual = await docRef.get();
    final atualMap = atual.data() ?? <String, dynamic>{};
    final info = await PackageInfo.fromPlatform();
    final versaoAtual = '${info.version}+${info.buildNumber}';
    final linkUltimaAtualizacao = (atualMap['updateUrl']?.toString().trim().isNotEmpty == true)
        ? atualMap['updateUrl'].toString().trim()
        : 'https://play.google.com/store/apps/details?id=br.com.alexandresousa.pontocerto';
    final mensagem = 'Nova versao disponivel ($versaoAtual). Atualize para continuar com seguranca e estabilidade.';

    await docRef.set({
      'companyId': sessao.companyId,
      'active': active,
      'latestVersion': versaoAtual,
      'message': mensagem,
      'force': force,
      'updateUrl': linkUltimaAtualizacao,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': sessao.userId,
    }, SetOptions(merge: true));
    _registrarAuditoria('saveAppUpdateSettings');
  }
}
