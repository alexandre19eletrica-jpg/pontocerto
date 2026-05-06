import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'marketing_browser_context.dart';

class SalesAnalyticsService {
  SalesAnalyticsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _visitorIdKey = 'sales_marketing_visitor_id';
  static const _sessionIdKey = 'sales_marketing_session_id';
  static const _lastActivityMsKey = 'sales_marketing_last_activity_ms';
  static const _sessionTimeoutMs = 30 * 60 * 1000;

  final FirebaseFunctions _functions;

  Future<void> trackPageView({
    required String pagePath,
    String planCode = '',
  }) async {
    await _trackEvent(
      eventName: pagePath == '/vendas'
          ? 'sales_page_view'
          : 'sales_preregistration_view',
      pagePath: pagePath,
      planCode: planCode,
    );
  }

  Future<void> trackPlanSelect({
    required String planCode,
    String pagePath = '/vendas',
  }) async {
    await _trackEvent(
      eventName: 'sales_plan_select',
      pagePath: pagePath,
      planCode: planCode,
    );
  }

  Future<void> trackPreregistrationSubmitted({
    required String planCode,
    required String implementationMode,
    required String leadId,
  }) async {
    await _trackEvent(
      eventName: 'sales_preregistration_submit',
      pagePath: '/contratar',
      planCode: planCode,
      implementationMode: implementationMode,
      leadId: leadId,
    );
  }

  /// Pré-cadastro empresa leve (rota canónica `/pre-cadastro-empresa`).
  Future<void> trackCompanyLightPreregistrationView({
    String pagePath = '/pre-cadastro-empresa',
  }) async {
    await _trackEvent(
      eventName: 'company_light_preregistration_view',
      pagePath: pagePath,
    );
  }

  Future<void> trackCompanyLightPreregistrationSubmit({
    String leadId = '',
    String pagePath = '/pre-cadastro-empresa',
  }) async {
    await _trackEvent(
      eventName: 'company_light_preregistration_submit',
      pagePath: pagePath,
      leadId: leadId,
    );
  }

  /// Clique que abre o WhatsApp comercial (landing / vendas). Não indica envio da mensagem no app.
  Future<void> trackWhatsappComercial({String pagePath = ''}) async {
    final path = pagePath.trim().isEmpty
        ? (Uri.base.path.isEmpty ? '/' : Uri.base.path)
        : pagePath;
    await _trackEvent(
      eventName: 'sales_whatsapp_comercial',
      pagePath: path,
    );
  }

  Future<Map<String, dynamic>> currentTrackingPayload() async {
    final context = await _ensureContext();
    return context.toPayload();
  }

  Future<void> _trackEvent({
    required String eventName,
    required String pagePath,
    String planCode = '',
    String implementationMode = '',
    String leadId = '',
  }) async {
    try {
      final context = await _ensureContext();
      final callable = _functions.httpsCallable('publicTrackMarketingEvent');
      await callable.call(<String, dynamic>{
        'eventName': eventName,
        'pagePath': pagePath,
        'planCode': planCode,
        'implementationMode': implementationMode,
        'leadId': leadId,
        ...context.toPayload(),
      });
    } catch (error, stackTrace) {
      debugPrint('SalesAnalyticsService error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<_SalesTrackingContext> _ensureContext() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastActivityMs = prefs.getInt(_lastActivityMsKey) ?? 0;
    var visitorId = prefs.getString(_visitorIdKey) ?? '';
    var sessionId = prefs.getString(_sessionIdKey) ?? '';

    if (visitorId.isEmpty) {
      visitorId = _generateId('visitor');
      await prefs.setString(_visitorIdKey, visitorId);
    }
    if (sessionId.isEmpty || now - lastActivityMs > _sessionTimeoutMs) {
      sessionId = _generateId('session');
      await prefs.setString(_sessionIdKey, sessionId);
    }
    await prefs.setInt(_lastActivityMsKey, now);

    final browser = readMarketingBrowserContext();
    final query = Uri.base.queryParameters;
    final referrer = browser.referrer;
    final referrerHost = _extractHost(referrer);

    return _SalesTrackingContext(
      visitorId: visitorId,
      sessionId: sessionId,
      utmSource: _cleanKey(query['utm_source']),
      utmMedium: _cleanKey(query['utm_medium']),
      utmCampaign: _cleanKey(query['utm_campaign']),
      utmContent: _cleanKey(query['utm_content']),
      utmTerm: _cleanKey(query['utm_term']),
      referrer: referrer,
      referrerHost: referrerHost,
      language: browser.language,
      deviceType: _detectDeviceType(browser.userAgent),
      landingPath: Uri.base.path.isEmpty ? '/' : Uri.base.path,
      screenWidth: browser.screenWidth,
      screenHeight: browser.screenHeight,
    );
  }

  String _generateId(String prefix) {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = (stamp.hashCode & 0x7fffffff).toRadixString(36);
    return '${prefix}_$stamp$noise';
  }

  String _extractHost(String value) {
    if (value.trim().isEmpty) return '';
    try {
      return Uri.parse(value).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  String _detectDeviceType(String userAgent) {
    final ua = userAgent.toLowerCase();
    if (ua.contains('ipad') || ua.contains('tablet')) return 'tablet';
    if (ua.contains('mobile') ||
        ua.contains('android') ||
        ua.contains('iphone')) {
      return 'mobile';
    }
    return kIsWeb ? 'desktop' : 'app';
  }

  String _cleanKey(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class _SalesTrackingContext {
  const _SalesTrackingContext({
    required this.visitorId,
    required this.sessionId,
    required this.utmSource,
    required this.utmMedium,
    required this.utmCampaign,
    required this.utmContent,
    required this.utmTerm,
    required this.referrer,
    required this.referrerHost,
    required this.language,
    required this.deviceType,
    required this.landingPath,
    required this.screenWidth,
    required this.screenHeight,
  });

  final String visitorId;
  final String sessionId;
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;
  final String utmContent;
  final String utmTerm;
  final String referrer;
  final String referrerHost;
  final String language;
  final String deviceType;
  final String landingPath;
  final double screenWidth;
  final double screenHeight;

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'visitorId': visitorId,
      'sessionId': sessionId,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'utmContent': utmContent,
      'utmTerm': utmTerm,
      'referrer': referrer,
      'referrerHost': referrerHost,
      'language': language,
      'deviceType': deviceType,
      'landingPath': landingPath,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
    };
  }
}
