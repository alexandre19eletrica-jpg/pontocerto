import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/navigation/shell_user_actions.dart';

/// Shell único do painel: menu lateral [não é recriado] a cada troca de rota.
class AppRouteShell extends ConsumerWidget {
  const AppRouteShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return child;
    }
    final chrome = ref.watch(shellPageChromeProvider);
    final path = GoRouterState.of(context).matchedLocation;
    final title = chrome?.title ?? AppShellScaffold.titleForPath(path);
    final actions = chrome?.actions != null
        ? chrome!.actions!
        : buildShellUserTrailingActions(
            context,
            ref,
            beforeLogout: chrome?.beforeLogout ?? const [],
          );
    return AppShellScaffold(
      title: title,
      session: session,
      header: chrome?.header,
      actions: actions,
      body: child,
    );
  }
}
