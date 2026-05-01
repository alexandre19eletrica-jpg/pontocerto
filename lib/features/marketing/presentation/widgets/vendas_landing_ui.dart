import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_whatsapp_button.dart'
    show kWhatsappBrandGreen;

/// Paleta pensada para leitura em telas pequenas (Instagram / mobile).
abstract final class VendasLandingTheme {
  static const heroTop = Color(0xFF050810);
  static const heroMid = Color(0xFF0C1424);
  static const heroAccent = Color(0xFF132038);
  static const ink = Color(0xFF0A0F1A);
  static const inkMuted = Color(0xFF4B5568);
  static const surface = Color(0xFFDFE6F0);
  static const surfaceCard = Colors.white;
  static const primary = Color(0xFF1E3A8A);
  static const primaryGlow = Color(0xFF3B82F6);
  static const heroHighlight = Color(0xFF93C5FD);
  static const success = Color(0xFF047857);
  static const border = Color(0xFFC8D0E0);
  static const chipBg = Color(0x331F2937);
  static const brandPart1 = Color(0xFF7DD3FC);
  static const brandPart2 = Color(0xFFF8FAFC);
  static const footerBg = Color(0xFF020617);
}

/// Faixa superior: marca em alto contraste + ação.
class VendasLandingTopBar extends StatelessWidget {
  const VendasLandingTopBar({
    super.key,
    required this.onLogin,
    required this.loginLabel,
  });

  final VoidCallback onLogin;
  final String loginLabel;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 720;
    final pad = w >= 960 ? 40.0 : (w >= 600 ? 24.0 : 16.0);
    final fs = w >= 600 ? 19.0 : 17.0;
    return Container(
      width: double.infinity,
      color: VendasLandingTheme.heroTop,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 14, pad, compact ? 10 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ponto',
                    style: TextStyle(
                      color: VendasLandingTheme.brandPart1,
                      fontWeight: FontWeight.w900,
                      fontSize: fs,
                      letterSpacing: -0.4,
                      height: 1,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  Text(
                    ' Certo',
                    style: TextStyle(
                      color: VendasLandingTheme.brandPart2,
                      fontWeight: FontWeight.w900,
                      fontSize: fs,
                      letterSpacing: -0.4,
                      height: 1,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(
                foregroundColor: VendasLandingTheme.heroHighlight,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                minimumSize: Size(0, compact ? 44 : 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                ),
              ),
              child: Text(
                loginLabel,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 15 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendasLandingHero extends StatelessWidget {
  const VendasLandingHero({
    super.key,
    required this.compact,
    required this.headline,
    required this.accentLine,
    required this.subhead,
    required this.badges,
    required this.onPrimary,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  final bool compact;
  final String headline;
  final String accentLine;
  final String subhead;
  final List<String> badges;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VendasLandingTheme.heroTop,
            VendasLandingTheme.heroMid,
            VendasLandingTheme.heroAccent,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: compact ? -80 : -40,
            top: compact ? 60 : 40,
            child: IgnorePointer(
              child: Container(
                width: compact ? 220 : 320,
                height: compact ? 220 : 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VendasLandingTheme.primaryGlow.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 40,
              compact ? 8 : 16,
              compact ? 18 : 40,
              compact ? 36 : 56,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 26 : 42,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.6,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  Text(
                    accentLine,
                    style: TextStyle(
                      color: VendasLandingTheme.heroHighlight,
                      fontSize: compact ? 19 : 28,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      letterSpacing: -0.35,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 22),
                  Text(
                    subhead,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.93),
                      fontSize: compact ? 17 : 18,
                      height: 1.52,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 26),
                  Wrap(
                    spacing: compact ? 10 : 8,
                    runSpacing: compact ? 10 : 8,
                    children: badges
                        .map(
                          (b) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 14 : 12,
                              vertical: compact ? 10 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: VendasLandingTheme.chipBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                            ),
                            child: Text(
                              b,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.98),
                                fontSize: compact ? 14 : 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: compact ? 26 : 36),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: VendasLandingTheme.heroTop,
                            minimumSize: const Size(double.infinity, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            primaryLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (secondaryLabel != null && onSecondary != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: onSecondary,
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              secondaryLabel!,
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
                              minimumSize: const Size(double.infinity, 52),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: VendasLandingTheme.heroTop,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            primaryLabel,
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
                          ),
                        ),
                        if (secondaryLabel != null && onSecondary != null)
                          FilledButton.icon(
                            onPressed: onSecondary,
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              secondaryLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                                color: Colors.white,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: kWhatsappBrandGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VendasLandingSection extends StatelessWidget {
  const VendasLandingSection({
    super.key,
    required this.compact,
    required this.label,
    required this.title,
    required this.child,
    this.subtitle,
    this.dark = false,
  });

  final bool compact;
  final String label;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0F172A) : VendasLandingTheme.surface;
    final padV = compact ? 22.0 : 48.0;
    return Container(
      width: double.infinity,
      color: bg,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 40, vertical: padV),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: compact ? 13 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? 0.9 : 1.15,
                  color: dark ? VendasLandingTheme.heroHighlight : VendasLandingTheme.primary,
                ),
              ),
              SizedBox(height: compact ? 10 : 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : VendasLandingTheme.ink,
                  height: 1.12,
                  letterSpacing: -0.45,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compact ? 14 : 14),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: compact ? 17 : 17,
                    height: 1.52,
                    color: dark ? Colors.white.withValues(alpha: 0.82) : VendasLandingTheme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: compact ? 20 : 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class VendasFeatureTile extends StatelessWidget {
  const VendasFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 14 : 16),
      decoration: BoxDecoration(
        color: VendasLandingTheme.surfaceCard,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: VendasLandingTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 48 : 52,
            height: compact ? 48 : 52,
            decoration: BoxDecoration(
              color: VendasLandingTheme.primary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1),
              boxShadow: [
                BoxShadow(
                  color: VendasLandingTheme.primary.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: compact ? 26 : 28,
            ),
          ),
          SizedBox(width: compact ? 14 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    color: VendasLandingTheme.ink,
                    height: 1.22,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: compact ? 15 : 15,
                    height: 1.45,
                    color: VendasLandingTheme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de módulos: coluna cheia no celular; 2 colunas em telas largas (sem células vazias de grid).
class VendasFeatureList extends StatelessWidget {
  const VendasFeatureList({super.key, required this.compact, required this.children});

  final bool compact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        final itemW = (maxW - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children.map((c) => SizedBox(width: itemW, child: c)).toList(),
        );
      },
    );
  }
}

class VendasLandingTwoCol extends StatelessWidget {
  const VendasLandingTwoCol({
    super.key,
    required this.compact,
    required this.left,
    required this.right,
  });

  final bool compact;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 20),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: left),
        const SizedBox(width: 32),
        Expanded(flex: 5, child: right),
      ],
    );
  }
}

class VendasPainCard extends StatelessWidget {
  const VendasPainCard({super.key, required this.compact, required this.title, required this.items});

  final bool compact;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF7ED),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w900,
                    color: VendasLandingTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 16),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        height: 1.4,
                        color: VendasLandingTheme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VendasWinCard extends StatelessWidget {
  const VendasWinCard({super.key, required this.compact, required this.title, required this.items});

  final bool compact;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: VendasLandingTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendasLandingTheme.border),
        boxShadow: [
          BoxShadow(
            color: VendasLandingTheme.success.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: VendasLandingTheme.success, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w900,
                    color: VendasLandingTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 16),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: 20, color: VendasLandingTheme.success),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: VendasLandingTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VendasStepsRow extends StatelessWidget {
  const VendasStepsRow({super.key, required this.compact, required this.steps});

  final bool compact;
  final List<VendasStepItem> steps;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _stepTile(steps[i], i + 1),
            if (i < steps.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(child: _stepTile(steps[i], i + 1)),
          if (i < steps.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _stepTile(VendasStepItem s, int n) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: VendasLandingTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VendasLandingTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 40 : 36,
            height: compact ? 40 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VendasLandingTheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: VendasLandingTheme.primary,
                fontSize: compact ? 17 : 16,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 12),
          Text(
            s.title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 17 : 16,
              color: VendasLandingTheme.ink,
              height: 1.2,
            ),
          ),
          SizedBox(height: compact ? 8 : 8),
          Text(
            s.body,
            style: TextStyle(
              fontSize: compact ? 15 : 14,
              height: 1.48,
              color: VendasLandingTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class VendasStepItem {
  const VendasStepItem({required this.title, required this.body});
  final String title;
  final String body;
}

/// Bloco de oferta: destaque visual + lista de inclusões.
class VendasPricingOffer extends StatelessWidget {
  const VendasPricingOffer({
    super.key,
    required this.compact,
    required this.title,
    required this.billingNote,
    required this.priceSuffix,
    required this.bullets,
    required this.primaryChild,
    this.whatsapp,
  });

  final bool compact;
  final String title;
  /// Linha curta sob o título (ex.: base de cobrança: escritório vs empresa).
  final String billingNote;
  /// Texto ao lado do valor (ex.: "/mês · por escritório").
  final String priceSuffix;
  final List<String> bullets;
  final Widget primaryChild;
  final Widget? whatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VendasLandingTheme.heroTop,
            const Color(0xFF1A2744),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: VendasLandingTheme.primary.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: VendasLandingTheme.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'OFERTA REAL · PREÇO CLARO',
              style: TextStyle(
                color: Color(0xFF6EE7B7),
                fontSize: compact ? 12 : 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.85,
              ),
            ),
          ),
          SizedBox(height: compact ? 16 : 20),
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            billingNote,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 20 : 24),
          Text(
            'R\$ 97,90',
            style: TextStyle(
              fontSize: compact ? 40 : 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          Text(
            priceSuffix,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 22 : 26),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF6EE7B7), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: compact ? 15 : 16,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          primaryChild,
          if (whatsapp != null) ...[
            const SizedBox(height: 14),
            whatsapp!,
          ],
        ],
      ),
    );
  }
}

class VendasScreenshotSection extends StatelessWidget {
  const VendasScreenshotSection({
    super.key,
    required this.compact,
    required this.blocks,
    this.title = 'O produto existe. As telas também.',
    this.subtitle = 'Imagens reais do Ponto Certo: fiscal, financeiro, documentos e carteira — o que vocês usam no dia a dia.',
  });

  final bool compact;
  final List<Widget> blocks;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return VendasLandingSection(
      compact: compact,
      label: 'Produto real',
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            blocks[i],
            if (i < blocks.length - 1) SizedBox(height: compact ? 24 : 32),
          ],
        ],
      ),
    );
  }
}

class VendasTrustStrip extends StatelessWidget {
  const VendasTrustStrip({super.key, required this.compact, required this.items});

  final bool compact;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    final edge = compact ? 16.0 : 32.0;
    if (compact) {
      return Container(
        width: double.infinity,
        color: bg,
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: edge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_rounded, size: 22, color: VendasLandingTheme.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.35,
                        color: VendasLandingTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1) Divider(height: 22, thickness: 1, color: VendasLandingTheme.border.withValues(alpha: 0.7)),
            ],
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: bg,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: edge),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 22,
            runSpacing: 14,
            children: items
                .map(
                  (t) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 20, color: VendasLandingTheme.success),
                      const SizedBox(width: 8),
                      Text(
                        t,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: VendasLandingTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// Rodapé comercial completo — prioridade leitura no celular.
class VendasLandingFooter extends StatelessWidget {
  const VendasLandingFooter({
    super.key,
    required this.compact,
    required this.onInicio,
    required this.onWhatsapp,
    required this.pricingLine,
    this.onEntrar,
    this.entrarLabel,
  });

  final bool compact;
  final VoidCallback onInicio;
  final VoidCallback onWhatsapp;
  /// Uma linha com trial + valor + base de cobrança (por escritório vs por empresa).
  final String pricingLine;
  final VoidCallback? onEntrar;
  final String? entrarLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: VendasLandingTheme.footerBg,
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 40,
        compact ? 32 : 40,
        compact ? 20 : 40,
        compact ? 28 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ponto',
                    style: TextStyle(
                      color: VendasLandingTheme.brandPart1,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 23 : 25,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    ' Certo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 23 : 25,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 14),
              Text(
                'Operação, fiscal e financeiro no mesmo lugar. Pensado para abrir no celular.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: compact ? 15 : 15,
                  height: 1.48,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 24 : 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: onInicio,
                    style: TextButton.styleFrom(
                      foregroundColor: VendasLandingTheme.heroHighlight,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Início', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  if (onEntrar != null && entrarLabel != null)
                    TextButton(
                      onPressed: onEntrar,
                      style: TextButton.styleFrom(
                        foregroundColor: VendasLandingTheme.heroHighlight,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(entrarLabel!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  TextButton.icon(
                    onPressed: onWhatsapp,
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
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 22 : 26),
                child: Divider(color: Colors.white.withValues(alpha: 0.14), thickness: 1),
              ),
              Text(
                pricingLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: compact ? 13 : 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 14 : 16),
              Text(
                '© 2026 Ponto Certo. Todos os direitos reservados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: compact ? 12 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum VendasFounderAudience { contador, empresa }

class VendasFounderStory extends StatelessWidget {
  const VendasFounderStory({super.key, required this.compact, required this.audience});

  final bool compact;
  final VendasFounderAudience audience;

  @override
  Widget build(BuildContext context) {
    final tail = switch (audience) {
      VendasFounderAudience.contador =>
        'Por isso o Ponto Certo, do lado do contador, foi montado em volta de carteira, fiscal e documentos com rastreamento — para você impor padrão e recuperar o controle, em vez de virar cobrador de áudio.',
      VendasFounderAudience.empresa =>
        'Por isso a empresa consegue lançar o serviço e avançar a nota pelo celular, esteja onde estiver — com o contador no mesmo fluxo, sem você depender de "quando ele abrir o WhatsApp".',
    };

    return Container(
      width: double.infinity,
      color: const Color(0xFF1E293B),
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 40, vertical: compact ? 28 : 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: EdgeInsets.all(compact ? 20 : 28),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: VendasLandingTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VendasLandingTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: VendasLandingTheme.heroHighlight, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Por trás do produto',
                        style: TextStyle(
                          fontSize: compact ? 14 : 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.85,
                          color: VendasLandingTheme.heroHighlight,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 18),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: compact ? 17 : 17,
                      height: 1.52,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Sou o '),
                      const TextSpan(
                        text: 'Alexandre Sousa',
                        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const TextSpan(
                        text:
                            '. Trabalho com prestação de serviços elétricos em obras de construção civil — '
                            'aquele dia a dia em que nota em atraso, dado incompleto e conversa solta viram '
                            'dinheiro parado e estresse. ',
                      ),
                      TextSpan(
                        text: 'O Ponto Certo não veio de laboratório: veio porque eu precisava colocar ordem na '
                            'emissão, no financeiro e na operação no mesmo lugar.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 1),
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' Hoje é o sistema que uso no dia a dia — aberto a empresas e contadores que querem sair do improviso.',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 14 : 16),
                Text(
                  tail,
                  style: TextStyle(
                    fontSize: compact ? 16 : 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
