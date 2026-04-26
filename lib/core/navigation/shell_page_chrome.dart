import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Título / cabeçalho / ações de cada rota, definidos pela página (shell único do router).
@immutable
class ShellPageChrome {
  const ShellPageChrome({
    this.title,
    this.header,
    this.actions,
    this.beforeLogout = const [],
  });

  final String? title;
  final Widget? header;
  final List<Widget>? actions;
  final List<Widget> beforeLogout;
}

/// Atualize no início do [build] de cada página do app (não de login/marketing).
final shellPageChromeProvider = StateProvider<ShellPageChrome?>((ref) => null);
