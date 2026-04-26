import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateLauncher {
  static const String _fallbackPackageName = 'br.com.alexandresousa.pontocerto';
  static const int _highPriorityThreshold = 4;
  static const int _staleDaysThreshold = 7;

  static Future<bool> open({String? updateUrl}) async {
    final packageName = await _resolvePackageName();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (_shouldResumeImmediateFlow(info)) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }
        if (_shouldPerformImmediateUpdate(info)) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }
      } catch (_) {
        // Em falha do fluxo nativo, segue para fallback via URL.
      }
    }

    final candidates = <Uri>{};

    final remote = updateUrl?.trim() ?? '';
    if (remote.isNotEmpty) {
      final normalized = _normalizeUrl(remote);
      final parsed = Uri.tryParse(normalized);
      if (parsed != null) candidates.add(parsed);
    }

    candidates.add(Uri.parse('market://details?id=$packageName'));
    candidates.add(Uri.parse('https://play.google.com/store/apps/details?id=$packageName'));
    candidates.add(Uri.parse('https://play.google.com/store/apps'));

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.externalApplication)) {
        return true;
      }
    }

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
    }

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.platformDefault)) {
        return true;
      }
    }

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.inAppBrowserView)) {
        return true;
      }
    }

    return false;
  }

  static Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  static Future<String> _resolvePackageName() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final packageName = info.packageName.trim();
      if (packageName.isNotEmpty) return packageName;
    } catch (_) {
      // Usa fallback fixo quando o package não puder ser resolvido.
    }
    return _fallbackPackageName;
  }

  static String _normalizeUrl(String input) {
    final raw = input.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('market://')) {
      return raw;
    }
    if (raw.startsWith('play.google.com/')) {
      return 'https://$raw';
    }
    return raw;
  }

  static bool _shouldResumeImmediateFlow(AppUpdateInfo info) {
    return info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress;
  }

  static bool _shouldPerformImmediateUpdate(AppUpdateInfo info) {
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (!info.immediateUpdateAllowed) {
      return false;
    }
    if (info.updatePriority >= _highPriorityThreshold) {
      return true;
    }
    final staleDays = info.clientVersionStalenessDays ?? 0;
    return staleDays >= _staleDaysThreshold;
  }
}
