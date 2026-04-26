// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'dart:html' as html;

import 'public_sales_config_service.dart';

bool _injected = false;

const _kPixelMark = 'data-pc-meta-pixel-injected';

/// Busca a config publica e injeta no [document.head] o codigo de base (script/noscript)
/// colocado no painel, equivalente a colar o trecho do Meta no head da pagina.
Future<void> schedulePublicMetaPixelFromConfig() async {
  if (_injected) return;
  _injected = true;
  try {
    final config = await PublicSalesConfigService().fetch();
    final raw = config.metaPixelHeadSnippet.trim();
    final head = html.document.head;
    if (head == null) return;
    _removePreviousPublicMetaPixelInjection();
    if (raw.isEmpty) {
      return;
    }
    _injectHeadSnippetFromHtml(
      raw,
      head: head,
      body: html.document.body,
    );
    final marker = html.MetaElement()
      ..name = 'pc-public-meta-pixel'
      ..content = '1'
      ..setAttribute(_kPixelMark, '1');
    head.append(marker);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('schedulePublicMetaPixelFromConfig: $e');
      debugPrint('$st');
    }
  }
}

void _removePreviousPublicMetaPixelInjection() {
  for (final el
      in html.document.querySelectorAll('[$_kPixelMark]')) {
    el.remove();
  }
  for (final el
      in html.document.querySelectorAll('meta[name="pc-public-meta-pixel"]')) {
    el.remove();
  }
}

void _injectHeadSnippetFromHtml(
  String raw, {
  required html.Element head,
  html.Element? body,
}) {
  var htmlStr = raw.replaceAll(
    RegExp(r'<!--[\s\S]*?-->'),
    '',
  );
  if (RegExp(
    r'<!DOCTYPE|</(html|body|head|title)\s*>',
    caseSensitive: false,
  ).hasMatch(htmlStr)) {
    // Evita insercao de documento completo; painel so deve receber o trecho do Meta.
    return;
  }

  const scriptRe = r'<script\s*([^>]*)\s*>([\s\S]*?)</script>';
  var scriptsAdded = 0;
  for (final m in RegExp(scriptRe, caseSensitive: false).allMatches(htmlStr)) {
    final attrs = m.group(1) ?? '';
    final content = m.group(2) ?? '';
    final el = html.ScriptElement();
    final srcM = RegExp(
      r'''src\s*=\s*["']([^"']+)["']''',
    ).firstMatch(attrs);
    if (srcM != null) {
      el.src = srcM.group(1)!.trim();
      if (RegExp(r'\basync\b').hasMatch(attrs)) {
        el.async = true;
      }
      if (RegExp(r'\bdefer\b').hasMatch(attrs)) {
        el.defer = true;
      }
    } else {
      if (content.trim().isEmpty) {
        continue;
      }
      el.text = content;
    }
    el.setAttribute(_kPixelMark, '1');
    head.append(el);
    scriptsAdded++;
  }
  if (scriptsAdded == 0) {
    _injectFirstScriptBlockFallback(htmlStr, head);
  }
  for (final m in RegExp(
    r'<noscript[^>]*>([\s\S]*?)</noscript>',
    caseSensitive: false,
  ).allMatches(htmlStr)) {
    final inner = m.group(1) ?? '';
    final n = html.Element.tag('noscript');
    n.setAttribute(_kPixelMark, '1');
    n.setInnerHtml(
      inner,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    if (body != null) {
      body.append(n);
    } else {
      head.append(n);
    }
  }
}

/// Se a regex nao corresponder (por exemplo variacao de espacos/linhas do Meta),
/// extrai o primeiro bloco script…/script e injeta de forma fiel.
void _injectFirstScriptBlockFallback(String htmlStr, html.Element head) {
  final lower = htmlStr.toLowerCase();
  var start = lower.indexOf('<script');
  if (start < 0) return;
  final afterOpen = htmlStr.indexOf('>', start);
  if (afterOpen < 0) return;
  var end = lower.indexOf('</script>', afterOpen);
  if (end < 0) return;
  var content = htmlStr.substring(afterOpen + 1, end).trim();
  if (content.isEmpty) return;
  final el = html.ScriptElement()..text = content;
  el.setAttribute(_kPixelMark, '1');
  head.append(el);
}
