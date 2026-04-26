import 'package:flutter/material.dart';

/// Última posição conhecida do menu (persiste entre trocas de rota e novos shells).
/// O [ScrollController] é [por instância] em [_ShellMenuState] para evitar
/// conflito com [ListView] destruído e [PageStorage].
double appShellMenuLastScrollOffset = 0.0;

void appShellMenuCaptureOffsetFrom(ScrollController c) {
  if (c.hasClients) {
    appShellMenuLastScrollOffset = c.offset;
  }
}
