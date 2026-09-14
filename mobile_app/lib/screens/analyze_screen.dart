import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  String? _errorMessage;
  Map<String, dynamic>? _report;

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

  Future<void> _runAnalysis() async {
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
        );
      } else if (file.fileId != null) {
        // Restored from history — use the backend's stored copy.
        report = await ApiService.analyzeStoredFile(file.fileId!);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This file has no local path — try re-uploading it.';
        });
        return;
      }
      setState(() {
        _report = report;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(widget.file?.name ?? 'Analyze',
                  overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineLgMobile),
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

  Widget _buildBody() {
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
        Text('Quality report generated just now.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.surface,
                AppColors.secondaryContainer.withOpacity(0.2),
              ],
            ),
          ),
          child: Column(
            children: [
              Text('DATA QUALITY SCORE',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.2)),
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
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                          healthPercent >= 90
                              ? AppColors.primary
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
                                    ? AppColors.primary
                                    : healthPercent >= 70
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.error,
                                fontSize: 36,
                              )),
                          TextSpan(
                              text: '%',
                              style: AppTextStyles.headlineLg.copyWith(
                                color: healthPercent >= 90
                                    ? AppColors.primary
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
                        ? AppColors.primary
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
                AppColors.surfaceContainerLow, AppColors.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('ISSUES FOUND (${issues.length})',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.0)),
        const SizedBox(height: AppSpacing.sm),
        if (issues.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text('No issues found — this file looks clean.', style: AppTextStyles.bodyMd),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.surfaceVariant.withOpacity(0.6)),
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
                Text(issue.title, style: AppTextStyles.labelMd),
                Text(issue.subtitle, style: AppTextStyles.bodySm),
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
