import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'file_item.dart';

enum HistoryType { upload, analysis, edit }

class HistoryItem {
  final String title;
  final String subtitle;
  final String time;
  final HistoryType type;
  final Color dotColor;
  final FileItem? fileItem;

  const HistoryItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.dotColor,
    this.fileItem,
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

  factory HistoryItem.fromFileItem(FileItem file) {
    final issues = file.issueCount;
    final subtitleParts = <String>[];
    if (file.metaLabel.isNotEmpty) subtitleParts.add(file.metaLabel);
    if (issues > 0) {
      subtitleParts.add('$issues issues');
    } else {
      subtitleParts.add('Clean data');
    }

    return HistoryItem(
      title: file.name,
      subtitle: subtitleParts.join(' • '),
      time: file.timeLabel.isNotEmpty ? file.timeLabel : 'Uploaded',
      type: issues > 0 ? HistoryType.analysis : HistoryType.upload,
      dotColor: issues > 0 ? AppColors.warning : AppColors.success,
      fileItem: file,
    );
  }
}

class HistoryGroup {
  final String label; // "Today", "Yesterday", ...
  final List<HistoryItem> items;
  const HistoryGroup({required this.label, required this.items});

  static List<HistoryGroup> fromFileItems(List<FileItem> files) {
    if (files.isEmpty) return [];

    final todayItems = <HistoryItem>[];
    final yesterdayItems = <HistoryItem>[];
    final earlierItems = <HistoryItem>[];

    for (final file in files) {
      final item = HistoryItem.fromFileItem(file);
      final timeLower = file.timeLabel.toLowerCase();

      if (timeLower.contains('just now') || timeLower.contains('m ago') || timeLower.contains('h ago')) {
        todayItems.add(item);
      } else if (timeLower.contains('1d ago')) {
        yesterdayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    final groups = <HistoryGroup>[];
    if (todayItems.isNotEmpty) {
      groups.add(HistoryGroup(label: 'Today', items: todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      groups.add(HistoryGroup(label: 'Yesterday', items: yesterdayItems));
    }
    if (earlierItems.isNotEmpty) {
      groups.add(HistoryGroup(label: 'Earlier', items: earlierItems));
    }

    if (groups.isEmpty && files.isNotEmpty) {
      groups.add(HistoryGroup(
        label: 'Uploaded Files',
        items: files.map((f) => HistoryItem.fromFileItem(f)).toList(),
      ));
    }

    return groups;
  }

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
          ],
        ),
      ];
}
