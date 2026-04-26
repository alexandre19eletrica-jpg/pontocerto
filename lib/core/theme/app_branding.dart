import 'package:flutter/material.dart';

class AppBrandColors {
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDeep = Color(0xFF0F172A);
  static const Color accent = Color(0xFF0F766E);
  static const Color gold = Color(0xFFD97706);
  static const Color ink = Color(0xFF0F172A);
  static const Color softText = Color(0xFF64748B);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceStrong = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFE2E8F0);
  static const Color sidebar = Color(0xFF0B3A66);
  static const Color sidebarStrong = Color(0xFF082B4D);
  static const Color sidebarMuted = Color(0xFF9FC2E5);
  static const Color sidebarSoft = Color(0xFFDCEBFA);
}

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 110,
    this.radius = 28,
    this.showShadow = true,
  });

  final double size;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x33003EAD),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/icon/app_logo_display.png', fit: BoxFit.cover),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius.clamp(16, 22)),
        color: const Color(0xFFFCFEFF),
        border: Border.all(color: const Color(0xFFCCD9E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.tag,
    this.compact = false,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? tag;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 920;
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
            border: Border.all(color: AppBrandColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tag != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFEFF6FF),
                    border: Border.all(color: const Color(0xFFD7E7FF)),
                  ),
                  child: Text(
                    tag!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppBrandColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: narrow ? double.infinity : 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppBrandColors.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        fontSize: compact ? 21 : 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppBrandColors.softText,
                        height: 1.45,
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: trailing!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class HighlightChip extends StatelessWidget {
  const HighlightChip({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppBrandColors.primaryDeep),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
