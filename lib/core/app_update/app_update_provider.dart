import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';

final currentAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.active,
    required this.latestVersion,
    required this.message,
    required this.force,
    this.updateUrl,
  });

  final bool active;
  final String latestVersion;
  final String message;
  final bool force;
  final String? updateUrl;
}

final appUpdateConfigProvider = StreamProvider<AppUpdateConfig?>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);
  if (!firebaseDisponivel || sessao == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('app_updates')
      .doc(sessao.companyId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final map = doc.data() ?? <String, dynamic>{};
    final latestVersion = map['latestVersion']?.toString().trim() ?? '';
    if (latestVersion.isEmpty) return null;
    final rawMessage = map['message']?.toString().trim() ?? '';
    final sanitizedMessage = rawMessage
        .split('\n')
        .where((line) => !line.toLowerCase().contains('versao atual'))
        .join('\n')
        .trim();
    return AppUpdateConfig(
      active: map['active'] == true,
      latestVersion: latestVersion,
      message: sanitizedMessage.isNotEmpty
          ? sanitizedMessage
          : 'Existe uma nova atualizacao do app. Atualize para continuar com estabilidade e seguranca.',
      force: map['force'] == true,
      updateUrl: map['updateUrl']?.toString(),
    );
  });
});
