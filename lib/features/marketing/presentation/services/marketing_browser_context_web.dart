import 'dart:html' as html;

import 'marketing_browser_context_stub.dart';

MarketingBrowserContext readMarketingBrowserContext() {
  final screen = html.window.screen;
  return MarketingBrowserContext(
    referrer: html.document.referrer ?? '',
    userAgent: html.window.navigator.userAgent,
    language: html.window.navigator.language ?? '',
    screenWidth: screen?.width?.toDouble() ?? 0,
    screenHeight: screen?.height?.toDouble() ?? 0,
  );
}
