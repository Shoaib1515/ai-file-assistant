import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum HistoryType { upload, analysis, edit }

class HistoryItem {
  final String title;
  final String subtitle;
  final String time;
  final HistoryType type;
  final Color dotColor;

  const HistoryItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.dotColor,
  });

  IconData get icon {
    switch (type) {
      case HistoryType.upload:
        return Icons.upload_file_outlined;
      case HistoryType.analysis:
        return Icons.analytics_outlined;
      case HistoryType.edit:
        return Icons.edit_document;
    }
  }

  Color get iconBackground {
    switch (type) {
      case HistoryType.upload:
        return AppColors.secondaryFixed;
      case HistoryType.analysis:
        return AppColors.primaryFixed;
      case HistoryType.edit:
        return AppColors.tertiaryFixed;
    }
  }

  Color get iconColor {
    switch (type) {
      case HistoryType.upload:
        return AppColors.onSecondaryFixed;
      case HistoryType.analysis:
        return AppColors.onPrimaryFixed;
      case HistoryType.edit:
        return AppColors.onTertiaryFixed;
    }
  }
}

class HistoryGroup {
  final String label; // "Today", "Yesterday", ...
  final List<HistoryItem> items;
  const HistoryGroup({required this.label, required this.items});

  static List<HistoryGroup> demo() => [
        HistoryGroup(
          label: 'Today',
          items: [
            HistoryItem(
              title: 'Analysis Completed',
              subtitle: 'Financial_Q3.xlsx • 3 issues found',
              time: '2:30 PM',
              type: HistoryType.analysis,
              dotColor: AppColors.error,
            ),
            HistoryItem(
              title: 'File Uploaded',
              subtitle: 'Financial_Q3.xlsx',
              time: '2:25 PM',
              type: HistoryType.upload,
              dotColor: AppColors.primary,
            ),
            HistoryItem(
              title: 'AI Edit Applied',
              subtitle: 'Project_Brief_Draft.docx • 12 rows updated',
              time: '11:15 AM',
              type: HistoryType.edit,
              dotColor: AppColors.success,
            ),
          ],
        ),
        HistoryGroup(
          label: 'Yesterday',
          items: [
            HistoryItem(
              title: 'File Uploaded',
              subtitle: 'Project_Brief_Draft.docx',
              time: '4:45 PM',
              type: HistoryType.upload,
              dotColor: AppColors.success,
            ),
            HistoryItem(
              title: 'Analysis In Progress',
              subtitle: 'inventory_v2.xlsx',
              time: '1:10 PM',
              type: HistoryType.analysis,
              dotColor: AppColors.warning,
            ),
          ],
        ),
      ];
}
