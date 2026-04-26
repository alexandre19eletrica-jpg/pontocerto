import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pontocerto/core/navigation/app_root_navigator_key.dart';

/// Tipo de aviso (cor e ícone do banner no topo).
enum AppUserMessageKind { info, success, warning, error }

@immutable
class AppUserMessage {
  const AppUserMessage({
    required this.text,
    required this.kind,
  });

  final String text;
  final AppUserMessageKind kind;
}

/// Estado global: desenhado pelo host do app para ficar acima do conteudo.
final ValueNotifier<AppUserMessage?> appUserMessageNotifier =
    ValueNotifier<AppUserMessage?>(null);

OverlayEntry? _messageOverlayEntry;
bool _messageOverlayInserted = false;

void _clearAppUserMessage() {
  appUserMessageNotifier.value = null;
  final entry = _messageOverlayEntry;
  if (entry != null && _messageOverlayInserted) {
    entry.remove();
  }
  _messageOverlayEntry = null;
  _messageOverlayInserted = false;
}

Color _messageColor(AppUserMessageKind kind) => switch (kind) {
  AppUserMessageKind.info => const Color(0xFF0D47A1),
  AppUserMessageKind.success => const Color(0xFF1B5E20),
  AppUserMessageKind.warning => const Color(0xFFE65100),
  AppUserMessageKind.error => const Color(0xFFB71C1C),
};

void _showAppUserMessage(
  String message, {
  AppUserMessageKind kind = AppUserMessageKind.info,
  BuildContext? context,
}) {
  final t = message.trim();
  if (t.isEmpty) {
    return;
  }
  final appMessage = AppUserMessage(text: t, kind: kind);
  appUserMessageNotifier.value = appMessage;
  _showMessageOverlay(appMessage, context);
}

void _showMessageOverlay(AppUserMessage message, BuildContext? context) {
  final targetOverlay =
      appRootNavigatorKey.currentState?.overlay ??
      switch (context) {
        final BuildContext ctx when ctx.mounted =>
          Overlay.maybeOf(ctx, rootOverlay: true),
        _ => null,
      };
  if (targetOverlay == null) {
    return;
  }

  _clearAppUserMessage();
  appUserMessageNotifier.value = message;

  final entry = OverlayEntry(
    opaque: false,
    maintainState: true,
    builder: (_) => _AppUserMessageOverlay(message: message),
  );
  _messageOverlayEntry = entry;

  void insertEntry() {
    if (_messageOverlayEntry != entry || !targetOverlay.mounted) {
      return;
    }
    targetOverlay.insert(entry);
    _messageOverlayInserted = true;
  }

  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => insertEntry());
  } else {
    insertEntry();
  }
}

extension AppUserMessageContextX on BuildContext {
  void showUserMessage(
    String message, {
    AppUserMessageKind kind = AppUserMessageKind.info,
  }) {
    if (!mounted) return;
    _showAppUserMessage(message, kind: kind, context: this);
  }

  void showUserError(String message) =>
      showUserMessage(message, kind: AppUserMessageKind.error);

  void showUserSuccess(String message) =>
      showUserMessage(message, kind: AppUserMessageKind.success);
}

class _AppUserMessageOverlay extends StatelessWidget {
  const _AppUserMessageOverlay({required this.message});

  final AppUserMessage message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: _AppUserMessageCard(
          message: message,
          onOk: _clearAppUserMessage,
        ),
      ),
    );
  }
}

class _AppUserMessageCard extends StatelessWidget {
  const _AppUserMessageCard({
    required this.message,
    required this.onOk,
  });

  final AppUserMessage message;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final color = _messageColor(message.kind);
    return Material(
      color: color,
      elevation: 24,
      shadowColor: const Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 46,
          maxWidth: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  message.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onOk,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(48, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
