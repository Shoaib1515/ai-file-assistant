import 'package:flutter/material.dart';
import '../models/history_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'analyze_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _navIndex = 2;
  int _filterIndex = 0;
  final _filters = const ['All', 'Uploads', 'Analysis', 'Edits'];
  final _groups = HistoryGroup.demo();

  List<HistoryGroup> get _filteredGroups {
    if (_filterIndex == 0) return _groups;

    final selectedType = switch (_filterIndex) {
      1 => HistoryType.upload,
      2 => HistoryType.analysis,
      3 => HistoryType.edit,
      _ => null,
    };

    if (selectedType == null) return _groups;

    return _groups
        .map((group) => HistoryGroup(
              label: group.label,
              items: group.items.where((item) => item.type == selectedType).toList(),
            ))
        .where((group) => group.items.isNotEmpty)
        .toList();
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        break;
      case 1:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AnalyzeScreen()));
        break;
      case 2:
        setState(() => _navIndex = 2);
        break;
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('History', style: AppTextStyles.headlineLgMobile),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.containerPadding, AppSpacing.sm, AppSpacing.containerPadding, AppSpacing.sm),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search history...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final selected = i == _filterIndex;
                  return ChoiceChip(
                    label: Text(_filters[i]),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterIndex = i),
                    labelStyle: AppTextStyles.labelMd.copyWith(
                      color: selected ? AppColors.surfaceContainerLowest : AppColors.onSurface,
                    ),
                    backgroundColor: AppColors.surfaceContainer,
                    selectedColor: AppColors.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    side: BorderSide.none,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.containerPadding, 0, AppSpacing.containerPadding, 100),
                children: [
                  for (final group in _filteredGroups) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(group.label, style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                    ...group.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.stackGap),
                          child: _historyTile(item),
                        )),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_filteredGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No items in this category yet.',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
    );
  }

  void _openHistoryDetails(HistoryItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Text('${item.subtitle}\n\nUpdated ${item.time}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(HistoryItem item) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => _openHistoryDetails(item),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(item.title,
                              overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: item.dotColor, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Text(item.subtitle, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(item.time, style: AppTextStyles.labelSm),
            ],
          ),
        ),
      ),
    );
  }
}
