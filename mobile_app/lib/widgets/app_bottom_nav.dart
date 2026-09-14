import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    (icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Analyze'),
    (icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEE1E1F24) : const Color(0xCCF8F9FA),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E3038) : AppColors.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == currentIndex;
            final color = selected
                ? (isDark ? const Color(0xFF8183F5) : AppColors.primary)
                : (isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant);
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? item.activeIcon : item.icon, color: color, size: 24),
                    const SizedBox(height: 2),
                    Text(item.label, style: AppTextStyles.labelSm.copyWith(color: color)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
