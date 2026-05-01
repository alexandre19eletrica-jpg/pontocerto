import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

/// Suporte comercial Ponto Certo (WhatsApp).
const _whatsappNumeroCompleto = '5562999283493'; // 55 + 62 99928-3493

/// Verde oficial da marca WhatsApp (ícones, bordas e destaques).
const Color kWhatsappBrandGreen = Color(0xFF25D366);

Uri buildVendasWhatsappUri({String? mensagemInicial}) {
  final texto = mensagemInicial?.trim();
  return Uri.parse(
    texto == null || texto.isEmpty
        ? 'https://wa.me/$_whatsappNumeroCompleto'
        : 'https://wa.me/$_whatsappNumeroCompleto?text=${Uri.encodeComponent(texto)}',
  );
}

/// Meta Pixel / analytics depois da abertura do link para não interferir no gesto no Web.
void scheduleWhatsappComercialSignals() {
  Future<void>.delayed(Duration.zero, () {
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
    try {
      var ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok) {
        debugPrint('abrirWhatsappVendas (web fallback): launchUrl falhou para $uri');
      }
    } catch (e, st) {
      debugPrint('abrirWhatsappVendas (web): $e');
      debugPrint('$st');
    }
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

Widget _filledWhatsappMarketingButton({
  required VoidCallback onPressed,
  required String label,
  required bool stretchFullWidth,
}) {
  return FilledButton.icon(
    onPressed: onPressed,
    icon: const FaIcon(
      FontAwesomeIcons.whatsapp,
      size: 20,
      color: Colors.white,
    ),
    label: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        fontSize: 14,
        color: Colors.white,
      ),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: kWhatsappBrandGreen,
      foregroundColor: Colors.white,
      minimumSize: stretchFullWidth ? const Size(double.infinity, 52) : null,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      padding: stretchFullWidth
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
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
    final uri = buildVendasWhatsappUri(mensagemInicial: mensagemInicial);

    if (kIsWeb) {
      return Link(
        uri: uri,
        target: LinkTarget.blank,
        builder: (context, followLink) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: followLink == null
                  ? null
                  : () {
                      followLink();
                      scheduleWhatsappComercialSignals();
                    },
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
        },
      );
    }

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

/// Hero / blocos: secundário WhatsApp com [Link] no Web (obrigatório para o browser não bloquear).
class VendasWhatsappHeroSecondaryButton extends StatelessWidget {
  const VendasWhatsappHeroSecondaryButton({
    super.key,
    required this.compact,
    required this.label,
    required this.mensagemInicial,
  });

  final bool compact;
  final String label;
  final String mensagemInicial;

  @override
  Widget build(BuildContext context) {
    final uri = buildVendasWhatsappUri(mensagemInicial: mensagemInicial);

    Widget buttonFor(VoidCallback onTap) => _filledWhatsappMarketingButton(
          onPressed: onTap,
          label: label,
          stretchFullWidth: compact,
        );

    if (!kIsWeb) {
      return buttonFor(() => abrirWhatsappVendas(mensagemInicial: mensagemInicial));
    }

    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) => buttonFor(
        followLink == null
            ? () => abrirWhatsappVendas(mensagemInicial: mensagemInicial)
            : () {
                followLink();
                scheduleWhatsappComercialSignals();
              },
      ),
    );
  }
}

/// Rodapé: TextButton WhatsApp com [Link] no Web.
class VendasWhatsappFooterButton extends StatelessWidget {
  const VendasWhatsappFooterButton({
    super.key,
    required this.mensagemInicial,
    required this.onFallback,
  });

  final String mensagemInicial;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    final uri = buildVendasWhatsappUri(mensagemInicial: mensagemInicial);

    if (!kIsWeb) {
      return TextButton.icon(
        onPressed: onFallback,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
        ),
        icon: const FaIcon(
          FontAwesomeIcons.whatsapp,
          size: 20,
          color: kWhatsappBrandGreen,
        ),
        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
    }

    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) => TextButton.icon(
        onPressed: followLink == null
            ? onFallback
            : () {
                followLink();
                scheduleWhatsappComercialSignals();
              },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
        ),
        icon: const FaIcon(
          FontAwesomeIcons.whatsapp,
          size: 20,
          color: kWhatsappBrandGreen,
        ),
        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}
