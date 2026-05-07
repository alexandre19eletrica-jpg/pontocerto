import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/core/privacy/presentation_money_mask_provider.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/ui/shell_selection_guard.dart';

/// Botões de privacidade (máscara de valores) e saída — padrão em todo o app.
List<Widget> buildShellUserTrailingActions(
  BuildContext context,
  WidgetRef ref, {
  List<Widget> beforeLogout = const [],
}) {
  final hideMoney = ref.watch(presentationMoneyMaskProvider);
  final firebaseOn = ref.watch(firebaseAvailableProvider);
  IconButton shellIcon({
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
  }) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: onPressed,
      icon: icon,
    );
  }

  return <Widget>[
    shellTapFriendly(
      shellIcon(
        tooltip:
            hideMoney ? 'Exibir valores' : 'Ocultar valores (privacidade)',
        onPressed: () =>
            ref.read(presentationMoneyMaskProvider.notifier).toggle(),
        icon: Icon(
          hideMoney
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppBrandColors.ink,
        ),
      ),
    ),
    ...beforeLogout.map(shellTapFriendly),
    shellTapFriendly(
      shellIcon(
        tooltip: 'Sair',
        onPressed: () async {
          try {
            if (firebaseOn) {
              await FirebaseAuth.instance.signOut();
            }
          } catch (e) {
            if (!context.mounted) {
              return;
            }
            context.showUserError(
              AppErrorMapper.messageFrom(
                e,
                fallback: 'Falha ao encerrar sessao no servidor.',
              ),
            );
          }
          ref.read(sessionProvider.notifier).logout();
          if (!context.mounted) {
            return;
          }
          context.go('/login');
        },
        icon: const Icon(Icons.logout_rounded, color: AppBrandColors.ink),
      ),
    ),
  ];
}
