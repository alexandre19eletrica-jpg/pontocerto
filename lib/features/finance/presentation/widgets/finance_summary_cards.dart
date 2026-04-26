import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_branding.dart';

class FinanceSummaryItem {
  const FinanceSummaryItem({
    required this.title,
    required this.value,
    this.color,
  });

  final String title;
  final String value;
  final Color? color;
}

class FinanceSummaryCards extends StatelessWidget {
  const FinanceSummaryCards({
    super.key,
    required this.items,
  });

  final List<FinanceSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount = width >= 1100
            ? 4
            : width >= 860
                ? 3
                : width >= 380
                    ? 2
                    : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            childAspectRatio: 1.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFCFEFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFCCD9E5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppBrandColors.softText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: item.color ?? AppBrandColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
