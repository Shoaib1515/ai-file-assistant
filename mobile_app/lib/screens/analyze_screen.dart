import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat_assistant_fab.dart';
import 'edit_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class IssueEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color color;
  const IssueEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
  });
}

class AnalyzeScreen extends StatefulWidget {
  /// The file to analyze. If null, this screen was opened from the
  /// bottom nav bar with no file context — it shows a prompt to pick
  /// one from Home instead of trying to analyze nothing.
  final FileItem? file;

  const AnalyzeScreen({super.key, this.file});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  int _navIndex = 1;
  bool _isLoading = true;
  bool _isAutoStructuring = false;
  String? _errorMessage;
  Map<String, dynamic>? _report;
  List<String> _sheetNames = [];
  String? _activeSheet;

  @override
  void initState() {
    super.initState();
    if (widget.file != null) {
      // Let the floating chat assistant answer questions grounded in
      // this specific file while this screen is active.
      ChatAssistantState.instance.setCurrentFile(widget.file);
      _runAnalysis();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _runAnalysis({String? sheetName}) async {
    final file = widget.file!;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> report;
      if (file.filePath != null) {
        // Freshly picked this session — send the file itself.
        report = await ApiService.analyzeFile(
          filePath: file.filePath,
          fileName: file.name,
          sheetName: sheetName ?? _activeSheet,
        );
      } else if (file.fileId != null) {
        // Restored from history — use the backend's stored copy.
        report = await ApiService.analyzeStoredFile(
          file.fileId!,
          sheetName: sheetName ?? _activeSheet,
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This file has no local path — try re-uploading it.';
        });
        return;
      }

      final sheets = (report['sheet_names'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];
      final active = report['active_sheet']?.toString() ?? (sheets.isNotEmpty ? sheets.first : null);

      setState(() {
        _report = report;
        _sheetNames = sheets;
        _activeSheet = active;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        final message = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = message.contains('not found') || message.contains('404')
            ? 'This file is no longer available. It may have been removed.'
            : message;
      });
    }
  }

  Future<void> _runAutoStructure() async {
    final file = widget.file;
    if (file == null) return;

    setState(() => _isAutoStructuring = true);

    try {
      final result = await ApiService.autoStructureFile(
        filePath: file.filePath,
        fileName: file.name,
        fileId: file.fileId,
      );

      if (!mounted) return;
      setState(() => _isAutoStructuring = false);
      _showStructuredResultSheet(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAutoStructuring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-structuring failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showStructuredResultSheet(Map<String, dynamic> result) {
    final isDark = context.isDarkMode;
    final initialScore = (result['initial_health_score'] as num?)?.toDouble() ?? 0.0;
    final structuredScore = (result['structured_health_score'] as num?)?.toDouble() ?? 100.0;
    final placeholdersCount = result['placeholders_cleaned'] ?? 0;
    final typesCount = result['types_fixed'] ?? 0;
    final whitespaceCount = result['whitespace_trimmed'] ?? 0;
    final duplicatesCount = result['duplicates_removed'] ?? 0;
    final columnsRenamed = (result['columns_renamed'] as List<dynamic>?) ?? [];
    final samplePreview = (result['sample_preview'] as List<dynamic>?) ?? [];
    final columns = (result['columns'] as List<dynamic>?) ?? [];
    final csvContent = result['csv_content'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1F24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? const Color(0xFF2E3038) : Colors.white),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF383844) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Structured & Cleaned Dataset',
                          style: AppTextStyles.labelMd.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '${result['total_rows']} rows · ${result['total_columns']} standard columns',
                          style: AppTextStyles.bodySm.copyWith(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Score Jump Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFF86EFAC),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Before',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFA5A4B5) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${initialScore.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 26),
                        Column(
                          children: [
                            Text(
                              'After (Structured)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFA5A4B5) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${structuredScore.toStringAsFixed(0)}% ✨',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metrics Wrap
                  Text(
                    'TRANSFORMATIONS PERFORMED',
                    style: AppTextStyles.labelSm.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF8183F5) : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricBadge('🧹 $placeholdersCount Placeholders Cleaned', const Color(0xFF10B981), isDark),
                      _metricBadge('🏷️ ${columnsRenamed.length} Headers Renamed', const Color(0xFF3B82F6), isDark),
                      _metricBadge('⚡ $typesCount Types Coerced', const Color(0xFFF59E0B), isDark),
                      _metricBadge('✂️ $whitespaceCount Spaces Trimmed', const Color(0xFF8B5CF6), isDark),
                      if (duplicatesCount > 0)
                        _metricBadge('🗑️ $duplicatesCount Duplicates Removed', const Color(0xFFEC4899), isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Renamed Headers Chips
                  if (columnsRenamed.isNotEmpty) ...[
                    Text(
                      'STANDARDIZED HEADERS',
                      style: AppTextStyles.labelSm.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF8183F5) : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: columnsRenamed.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282930) : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF383844) : const Color(0xFFC7D2FE),
                            ),
                          ),
                          child: Text(
                            '${c['old']} ➔ ${c['new']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Data Preview Table
                  Text(
                    'CLEAN STRUCTURED DATA PREVIEW',
                    style: AppTextStyles.labelSm.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF8183F5) : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (samplePreview.isNotEmpty && columns.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18191E) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3038) : Colors.grey.shade200,
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: 40,
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                          ),
                          columns: columns
                              .map((c) => DataColumn(label: Text(c.toString())))
                              .toList(),
                          rows: samplePreview.map((row) {
                            final rowMap = row as Map<String, dynamic>;
                            return DataRow(
                              cells: columns.map((col) {
                                final val = rowMap[col]?.toString() ?? '';
                                return DataCell(
                                  Text(
                                    val,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFA5A4B5) : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F24) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2E3038) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _runAnalysis();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Re-Analyze'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (csvContent.isNotEmpty) {
                          final bytes = Uint8List.fromList(utf8.encode(csvContent));
                          final baseName = widget.file?.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') ?? 'dataset';
                          await FileSaver.saveFile(
                            '${baseName}_structured.csv',
                            bytes,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved ${baseName}_structured.csv successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? color.withOpacity(0.9) : color,
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        break;
      case 1:
        setState(() => _navIndex = 1);
        break;
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HistoryScreen()));
        break;
      case 3:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                widget.file?.name ?? 'Analyze',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(child: _buildBody()),
          if (widget.file != null)
            const ChatAssistantFab(hintBubbleText: 'Need help fixing these issues?'),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
    );
  }

  Widget _buildSheetSelectorBar(bool isDark) {
    if (_sheetNames.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tab_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Excel Sheets (${_sheetNames.length}):',
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sheetNames.map((sheet) {
                final isSelected = sheet == _activeSheet;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (isSelected) return;
                      _runAnalysis(sheetName: sheet);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sheet,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppColors.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isDark = context.isDarkMode;
    if (widget.file == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_chart_outlined,
                  size: 40, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Select a file from Home to see its analysis.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen())),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

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
              ElevatedButton(onPressed: _runAnalysis, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    final totalRows = (report['total_rows'] ?? 0) as int;
    final missingByColumn = (report['missing_by_column'] as Map<String, dynamic>?) ?? {};
    final typeMismatches = (report['type_mismatches_by_column'] as Map<String, dynamic>?) ?? {};
    final duplicates = (report['duplicates'] as Map<String, dynamic>?) ?? {};
    final totalDuplicates = (duplicates['total_duplicates'] ?? 0) as int;

    final totalMissing = missingByColumn.values.fold<int>(
      0,
      (sum, col) => sum + (((col as Map<String, dynamic>?)?['total_missing'] ?? 0) as int),
    );

    final totalMismatches = typeMismatches.values.fold<int>(
      0,
      (sum, col) => sum + (((col as Map<String, dynamic>?)?['total_mismatches'] ?? 0) as int),
    );

    final double healthPercent;
    if (report['health_score'] != null) {
      healthPercent = (report['health_score'] as num).toDouble();
    } else {
      final clean = (totalRows - totalMissing - totalDuplicates - totalMismatches).clamp(0, totalRows);
      healthPercent = totalRows == 0 ? 100.0 : (clean / totalRows * 100);
    }

    final cleanRows = (totalRows - totalMissing - totalDuplicates - totalMismatches).clamp(0, totalRows);

    final issues = <IssueEntry>[
      ...missingByColumn.entries.map((entry) {
        final count = (entry.value as Map<String, dynamic>)['total_missing'] as int;
        return IssueEntry(
          icon: Icons.warning_amber_rounded,
          title: '${entry.key} Column',
          subtitle: 'Missing / blank cells',
          count: count,
          color: AppColors.error,
        );
      }),
      ...typeMismatches.entries.map((entry) {
        final count = (entry.value as Map<String, dynamic>)['total_mismatches'] as int;
        final expected = (entry.value as Map<String, dynamic>)['expected_type'] ?? 'valid format';
        return IssueEntry(
          icon: Icons.error_outline_rounded,
          title: '${entry.key} Column',
          subtitle: 'Type mismatch ($expected expected)',
          count: count,
          color: const Color(0xFFF59E0B),
        );
      }),
      if (totalDuplicates > 0)
        IssueEntry(
          icon: Icons.layers_outlined,
          title: 'Duplicate Rows',
          subtitle: 'Exact matching rows',
          count: totalDuplicates,
          color: AppColors.tertiaryContainer,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding),
      children: [
        if (_sheetNames.length > 1) _buildSheetSelectorBar(isDark),
        Text('Quality report generated just now.',
            style: AppTextStyles.bodySm.copyWith(
              color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
            )),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF2E3038) : Colors.white.withOpacity(0.6)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                isDark ? const Color(0xFF1E1F24) : AppColors.surface,
                isDark ? const Color(0xFF282930) : AppColors.secondaryContainer.withOpacity(0.2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('DATA QUALITY SCORE',
                  style: AppTextStyles.labelMd.copyWith(
                    color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: healthPercent / 100,
                        strokeWidth: 8,
                        backgroundColor: isDark ? const Color(0xFF2E3038) : AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                          healthPercent >= 90
                              ? (isDark ? const Color(0xFF8183F5) : AppColors.primary)
                              : healthPercent >= 70
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.error,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: healthPercent.toStringAsFixed(0),
                              style: AppTextStyles.headlineXl.copyWith(
                                color: healthPercent >= 90
                                    ? (isDark ? const Color(0xFF8183F5) : AppColors.primary)
                                    : healthPercent >= 70
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.error,
                                fontSize: 36,
                              )),
                          TextSpan(
                              text: '%',
                              style: AppTextStyles.headlineLg.copyWith(
                                color: healthPercent >= 90
                                    ? (isDark ? const Color(0xFF8183F5) : AppColors.primary)
                                    : healthPercent >= 70
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.error,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: (healthPercent >= 90
                          ? AppColors.primary
                          : healthPercent >= 70
                              ? const Color(0xFFF59E0B)
                              : AppColors.error)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  healthPercent >= 90
                      ? '✨ Excellent condition'
                      : healthPercent >= 70
                          ? '⚠️ Needs some cleanup'
                          : '🚨 Needs urgent attention',
                  style: AppTextStyles.labelMd.copyWith(
                    color: healthPercent >= 90
                        ? (isDark ? const Color(0xFF8183F5) : AppColors.primary)
                        : healthPercent >= 70
                            ? const Color(0xFFF59E0B)
                            : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF312E81), const Color(0xFF4338CA)]
                  : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.4 : 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1-Tap AI Auto-Structure',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clean headers, placeholders & corrupted rows in 1 tap.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isAutoStructuring ? null : _runAutoStructure,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  elevation: 0,
                ),
                child: _isAutoStructuring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                      )
                    : const Text(
                        'Auto Clean',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            _totalRowsCard(totalRows),
            _statCard(Icons.warning_amber_rounded, 'Missing', '$totalMissing',
                AppColors.errorContainer, AppColors.onErrorContainer),
            _statCard(Icons.error_outline_rounded, 'Corrupted', '$totalMismatches',
                const Color(0xFFFEF3C7), const Color(0xFF92400E)),
            _statCard(Icons.fingerprint, 'Clean rows', '$cleanRows',
                isDark ? const Color(0xFF1E1F24) : AppColors.surfaceContainerLow,
                isDark ? const Color(0xFFE2E2E6) : AppColors.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('ISSUES FOUND (${issues.length})',
            style: AppTextStyles.labelMd.copyWith(
              color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
              letterSpacing: 1.0,
            )),
        const SizedBox(height: AppSpacing.sm),
        if (issues.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F24) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: isDark ? const Color(0xFF2E3038) : Colors.white),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text('No issues found — this file looks clean.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                    )),
              ],
            ),
          )
        else
          ...issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _issueCard(issue),
              )),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditScreen(file: widget.file!)),
              );
            },
            icon: const Icon(Icons.auto_fix_high, size: 20),
            label: const Text('Edit with AI'),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _totalRowsCard(int totalRows) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.view_list, size: 18, color: AppColors.onPrimaryFixedVariant),
              const SizedBox(width: 6),
              Text('Total Rows',
                  style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimaryFixedVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$totalRows',
              style: AppTextStyles.headlineXl.copyWith(color: AppColors.onPrimaryFixed, fontSize: 24)),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelMd.copyWith(color: fg)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineXl.copyWith(color: fg, fontSize: 24)),
        ],
      ),
    );
  }

  Widget _issueCard(IssueEntry issue) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F24) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: isDark ? const Color(0xFF2E3038) : AppColors.surfaceVariant.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: issue.color.withOpacity(0.8)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: issue.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(issue.icon, color: issue.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: AppTextStyles.labelMd.copyWith(
                    color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                  ),
                ),
                Text(
                  issue.subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: issue.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${issue.count}',
                  style: AppTextStyles.headlineLgMobile.copyWith(fontSize: 15, color: issue.color)),
            ),
          ),
        ],
      ),
    );
  }
}
