import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MissingValuesChart extends StatelessWidget {
  final Map<String, dynamic> missingByColumn;

  const MissingValuesChart({
    super.key,
    required this.missingByColumn,
  });

  @override
  Widget build(BuildContext context) {
    final items = missingByColumn.entries
        .map((entry) {
          final value = entry.value as Map<String, dynamic>;
          final count = value['total_missing'] as int? ?? 0;
          return _MissingColumn(
            name: entry.key,
            count: count,
          );
        })
        .where((item) => item.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final totalMissing = items.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppColors.error, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Missing values by column', style: AppTextStyles.labelMd),
                    Text(
                      totalMissing == 0
                          ? 'No missing values detected in this file.'
                          : 'Graphing the columns with the highest missing counts.',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (totalMissing == 0)
            _EmptyChartState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final maxCount = items.first.count;
                final visibleItems = items.take(5).toList();
                final hiddenCount = items.length - visibleItems.length;
                final hiddenTotal = items.skip(5).fold<int>(0, (sum, item) => sum + item.count);

                return Column(
                  children: [
                    for (final item in visibleItems) ...[
                      _ChartRow(
                        name: item.name,
                        count: item.count,
                        maxCount: maxCount,
                        width: constraints.maxWidth,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (hiddenCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+$hiddenCount more columns with $hiddenTotal missing values',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChartRow extends StatelessWidget {
  final String name;
  final int count;
  final int maxCount;
  final double width;

  const _ChartRow({
    required this.name,
    required this.count,
    required this.maxCount,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = maxCount == 0 ? 0.0 : count / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$count', style: AppTextStyles.labelSm.copyWith(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 12,
              width: width,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 12,
              width: width * normalized,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.error, AppColors.tertiaryContainer],
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Everything looks clean. No chart bars to draw yet.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingColumn {
  final String name;
  final int count;

  const _MissingColumn({
    required this.name,
    required this.count,
  });
}
