import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'vendas_whatsapp_web_open_stub.dart'
    if (dart.library.html) 'vendas_whatsapp_web_open_web.dart' as wa_web;

/// Suporte comercial Ponto Certo (WhatsApp).
const _whatsappNumeroCompleto = '5562999283493'; // 55 + 62 99928-3493

/// Verde oficial da marca WhatsApp (ícones, bordas e destaques).
const Color kWhatsappBrandGreen = Color(0xFF25D366);

/// Abre conversa no WhatsApp; eventos de conversão disparam após o gesto de abertura
/// (no Web a abertura é síncrona para não perder o contexto de clique e ser bloqueada).
Future<void> abrirWhatsappVendas({String? mensagemInicial}) async {
  final texto = mensagemInicial?.trim();
  final uri = Uri.parse(
    texto == null || texto.isEmpty
        ? 'https://wa.me/$_whatsappNumeroCompleto'
        : 'https://wa.me/$_whatsappNumeroCompleto?text=${Uri.encodeComponent(texto)}',
  );

  if (kIsWeb) {
    wa_web.openWhatsappUrlOnWebImmediately(uri.toString());
  } else {
    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok) {
        debugPrint('abrirWhatsappVendas: launchUrl devolveu false');
      }
    } catch (e, st) {
      debugPrint('abrirWhatsappVendas: $e');
      debugPrint('$st');
    }
  }

  metaFbqTrackContactWhatsapp();
  unawaited(SalesAnalyticsService().trackWhatsappComercial());
}

/// Botão visível para falar com a equipe pelo WhatsApp.
class VendasWhatsappButton extends StatelessWidget {
  const VendasWhatsappButton({
    super.key,
    this.mensagemInicial,
    this.label = 'Falar no WhatsApp',
  });

  final String? mensagemInicial;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => abrirWhatsappVendas(mensagemInicial: mensagemInicial),
      icon: const FaIcon(
        FontAwesomeIcons.whatsapp,
        size: 22,
        color: Colors.white,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: kWhatsappBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
