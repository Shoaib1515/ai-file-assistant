import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../models/history_item.dart';
import '../services/api_service.dart';
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
  final _filters = const ['All', 'Excel', 'CSV', 'PDF', 'Issues'];
  final List<FileItem> _files = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await ApiService.getAllFiles();
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(records.map((r) => FileItem.fromHistoryRecord(r)));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<HistoryGroup> get _filteredGroups {
    Iterable<FileItem> filtered = _files;

    switch (_filterIndex) {
      case 1: // Excel
        filtered = filtered.where((f) => f.kind == FileKind.excel && (f.name.endsWith('.xlsx') || f.name.endsWith('.xls')));
        break;
      case 2: // CSV
        filtered = filtered.where((f) => f.name.toLowerCase().endsWith('.csv'));
        break;
      case 3: // PDF
        filtered = filtered.where((f) => f.kind == FileKind.pdf);
        break;
      case 4: // Issues
        filtered = filtered.where((f) => f.issueCount > 0);
        break;
      default: // All
        filtered = _files;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((f) => f.name.toLowerCase().contains(q));
    }

    return HistoryGroup.fromFileItems(filtered.toList());
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
    final groups = _filteredGroups;

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
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search history...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        ),
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
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
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
              child: _buildBody(groups),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
    );
  }

  Widget _buildBody(List<HistoryGroup> groups) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!, textAlign: TextAlign.center, style: AppTextStyles.bodyMd),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  size: 48, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.md),
              Text(
                _files.isEmpty
                    ? 'No uploaded files in history yet.\nUpload files from Home to see them here.'
                    : 'No matching files found.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (_files.isEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen())),
                  child: const Text('Go to Home'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerPadding, 0, AppSpacing.containerPadding, 100),
      children: [
        for (final group in groups) ...[
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
      ],
    );
  }

  Widget _historyTile(HistoryItem item) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () {
          if (item.fileItem != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AnalyzeScreen(file: item.fileItem)),
            );
          }
        },
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
