// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Abre `href` na mesma aba para evitar bloqueios silenciosos de nova aba no Web.
void vendasWebOpenWaMeNewTabHref(String href) {
  final a = html.AnchorElement(href: href)
    ..target = '_self'
    ..rel = 'noopener noreferrer';
  final host = html.document.body ?? html.document.documentElement;
  host?.append(a);
  a.click();
  a.remove();
}
