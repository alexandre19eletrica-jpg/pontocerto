import 'package:flutter/material.dart';

/// Chave do [Navigator] raiz (GoRouter). Usada p.ex. p/ inserir avisos no [Overlay]
/// com ordem e pintura acima de rotas/SelectionArea.
final GlobalKey<NavigatorState> appRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'app_root');
