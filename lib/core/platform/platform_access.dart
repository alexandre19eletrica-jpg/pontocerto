import 'package:flutter/foundation.dart';
import 'package:pontocerto/core/auth/session.dart';

bool get isWebPlatform => kIsWeb;

const supremePlatformCompanyIds = <String>{
  'comp_1771754418259',
  'comp_17717554418259',
};

bool isSupremePlatformCompanyId(String companyId) {
  return supremePlatformCompanyIds.contains(companyId.trim());
}

bool hasSupremePlatformAccess(Session? session) {
  return session != null &&
      session.role == Role.owner &&
      isSupremePlatformCompanyId(session.companyId);
}

/// Mesma ideia de [platformAdminEmails] + OWNER no Cloud Functions: empresa suprema
/// **ou** e-mail na lista (env `PLATFORM_ADMIN_EMAILS` no build web, ver script de deploy).
Set<String> _platformAdminEmailsFromBuild() {
  const raw = String.fromEnvironment('PLATFORM_ADMIN_EMAILS', defaultValue: '');
  if (raw.trim().isEmpty) return {};
  return raw
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
}

/// Rota `/platform-admin` e checagem na pagina: dono suprema **ou** dono com e-mail
/// autorizado (alinhado ao backend). Outros modulos "supremos" (observabilidade etc.)
/// continuam usando apenas [hasSupremePlatformAccess].
bool canAccessPlatformAdminRoute(Session? session) {
  if (session == null || session.role != Role.owner) return false;
  if (isSupremePlatformCompanyId(session.companyId)) return true;
  final e = session.email.trim().toLowerCase();
  if (e.isEmpty) return false;
  return _platformAdminEmailsFromBuild().contains(e);
}
