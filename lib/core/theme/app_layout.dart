import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_branding.dart';

enum AppViewportKind { phone, tablet, desktop }

class AppViewportInfo {
  const AppViewportInfo._({
    required this.width,
    required this.height,
    required this.kind,
  });

  final double width;
  final double height;
  final AppViewportKind kind;

  bool get isPhone => kind == AppViewportKind.phone;
  bool get isTablet => kind == AppViewportKind.tablet;
  bool get isDesktop => kind == AppViewportKind.desktop;

  bool get usesCompactSpacing => isPhone;
  bool get usesDrawerNavigation => width < 1120;

  EdgeInsets get pagePadding {
    if (width < 640) {
      return const EdgeInsets.fromLTRB(10, 10, 10, 18);
    }
    if (width < 1024) {
      return const EdgeInsets.fromLTRB(12, 12, 12, 20);
    }
    return const EdgeInsets.all(16);
  }

  double get pageMaxWidth => width >= 1120 ? 1480 : 1360;

  static AppViewportInfo of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final kind = width < 720
        ? AppViewportKind.phone
        : width < 1120
            ? AppViewportKind.tablet
            : AppViewportKind.desktop;
    return AppViewportInfo._(
      width: width,
      height: size.height,
      kind: kind,
    );
  }
}

class AppPageLayout extends StatelessWidget {
  const AppPageLayout({
    super.key,
    required this.child,
    this.maxWidth = 1360,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final viewport = AppViewportInfo.of(context);
    final resolvedPadding =
        padding == const EdgeInsets.all(16) ? viewport.pagePadding : padding;
    final constrained = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: viewport.width >= 1120 ? 1480 : maxWidth,
        ),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );

    if (!scrollable) {
      return constrained;
    }

    return SingleChildScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: constrained,
    );
  }
}

class AppWorkspaceCard extends StatelessWidget {
  const AppWorkspaceCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return GlassCard(
          padding: compact ? const EdgeInsets.all(16) : padding,
          borderRadius: compact ? 20 : 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || subtitle != null || trailing != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: compact ? 14 : 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppBrandColors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          softWrap: true,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppBrandColors.ink,
                            height: 1.1,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            subtitle!,
                            softWrap: true,
                            style: const TextStyle(
                              color: AppBrandColors.softText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: trailing!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              child,
            ],
          ),
        );
      },
    );
  }
}

class AppDesktopSplit extends StatelessWidget {
  const AppDesktopSplit({
    super.key,
    required this.sidebar,
    required this.content,
    this.breakpoint = 1100,
    this.sidebarFlex = 4,
    this.contentFlex = 7,
    this.spacing = 20,
  });

  final Widget sidebar;
  final Widget content;
  final double breakpoint;
  final int sidebarFlex;
  final int contentFlex;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) {
      return Column(
        children: [
          sidebar,
          SizedBox(height: spacing * 0.6),
          content,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: sidebarFlex, child: sidebar),
        SizedBox(width: spacing),
        Expanded(flex: contentFlex, child: content),
      ],
    );
  }
}

class AppHorizontalCardGrid extends StatelessWidget {
  const AppHorizontalCardGrid({
    super.key,
    required this.children,
    this.minItemWidth = 320,
    this.maxColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final resolvedMinItemWidth = availableWidth < 720
            ? minItemWidth.clamp(220.0, 280.0)
            : minItemWidth;
        if (availableWidth <= resolvedMinItemWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: runSpacing),
              ],
            ],
          );
        }
        final estimatedColumns =
            (((availableWidth + spacing) /
                        (resolvedMinItemWidth + spacing))
                    .floor())
                .clamp(1, maxColumns);
        final itemWidth =
            (availableWidth - ((estimatedColumns - 1) * spacing)) /
            estimatedColumns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppHeaderChip extends StatelessWidget {
  const AppHeaderChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrandColors.softText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
