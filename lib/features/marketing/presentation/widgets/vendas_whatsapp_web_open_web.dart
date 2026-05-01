// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Abre wa.me na mesma “virada” do evento do utilizador — evita bloqueio de pop-up causado por `await` antes de `window.open`.
void openWhatsappUrlOnWebImmediately(String url) {
  html.window.open(url, '_blank', 'noopener,noreferrer');
}
