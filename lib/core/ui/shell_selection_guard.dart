import 'package:flutter/widgets.dart';

/// Desativa o ambito de [SelectionArea] apenas na subarvore (ex.: botoes numa linha).
/// O corpo do shell ja nao usa [SelectionArea] globalmente na Web — evita colar falhar
/// em [TextField] e toques «travados» em icones; use [SelectableText] onde precisar copiar.
Widget shellTapFriendly(Widget child) =>
    SelectionContainer.disabled(child: child);
