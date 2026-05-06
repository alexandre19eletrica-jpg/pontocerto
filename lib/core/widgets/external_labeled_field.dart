import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_branding.dart';

/// Rótulo fixo acima do campo — melhora legibilidade em mobile e formulários densos.
class ExternalLabeledField extends StatelessWidget {
  const ExternalLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.bottomSpacing = 12,
    this.spacingAfterLabel = 8,
  });

  final String label;
  final Widget child;
  final double bottomSpacing;
  final double spacingAfterLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppBrandColors.ink,
              height: 1.25,
            ),
          ),
          SizedBox(height: spacingAfterLabel),
          child,
        ],
      ),
    );
  }
}
