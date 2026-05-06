import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pontocerto/core/constants/whatsapp_support.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'vendas_whatsapp_web_anchor_stub.dart'
    if (dart.library.html) 'vendas_whatsapp_web_anchor_web.dart' as wa_anchor;

/// Verde oficial da marca WhatsApp (ícones, bordas e destaques).
const Color kWhatsappBrandGreen = Color(0xFF25D366);

/// Atraso após abrir o `wa.me` para não competir com o gesto do browser nem com corrida Pixel/DOM.
const _kWhatsappAnalyticsDelay = Duration(milliseconds: 400);

Uri buildVendasWhatsappUri({String? mensagemInicial}) {
  final texto = mensagemInicial?.trim();
  return Uri.parse(
    texto == null || texto.isEmpty
        ? 'https://wa.me/$kWhatsappSupportNumberE164'
        : 'https://wa.me/$kWhatsappSupportNumberE164?text=${Uri.encodeComponent(texto)}',
  );
}

/// Meta Pixel + analytics — apenas após pequeno atraso (fora da stack síncrona do clique).
void scheduleWhatsappComercialSignals() {
  Timer(_kWhatsappAnalyticsDelay, () {
    try {
      metaFbqTrackContactWhatsapp();
      unawaited(SalesAnalyticsService().trackWhatsappComercial());
    } catch (e, st) {
      debugPrint('scheduleWhatsappComercialSignals: $e');
      debugPrint('$st');
    }
  });
}

Future<void> abrirWhatsappVendas({String? mensagemInicial}) async {
  final uri = buildVendasWhatsappUri(mensagemInicial: mensagemInicial);

  if (kIsWeb) {
    wa_anchor.vendasWebOpenWaMeNewTabHref(uri.toString());
    scheduleWhatsappComercialSignals();
    return;
  }

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

  scheduleWhatsappComercialSignals();
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
    void onTap() => abrirWhatsappVendas(mensagemInicial: mensagemInicial);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
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
      ),
    );
  }
}
