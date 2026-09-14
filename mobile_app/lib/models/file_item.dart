import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum FileKind { excel, pdf, word, image, other }

enum FileStatus { clean, warning, issues }

class FileItem {
  final String id;
  final String name;
  final String sizeLabel;
  final String metaLabel; // e.g. "1,204 rows" or "12 pages"
  final String timeLabel; // e.g. "2 mins ago"
  final FileKind kind;
  final FileStatus status;
  final int issueCount;
  final bool isRecent;
  final bool isShared;
  final bool isFavorite;

  /// Local device path — only set for files uploaded in THIS app
  /// session. Files restored from history (a previous session) will
  /// not have this, since the picked file on-device is gone once the
  /// app restarts — [fileId] is used instead for those.
  final String? filePath;

  /// Database ID for this file, present for anything that has gone
  /// through /upload. Used to call the backend's file_id-based
  /// endpoints (analyze/suggest-edit/apply-edit) when [filePath] is
  /// unavailable — i.e. for files restored from history.
  final int? fileId;

  /// Raw response from POST /upload — total_rows, columns,
  /// missing_values, etc. Null until the file has actually been
  /// uploaded to the backend (should not normally happen once
  /// uploads go through ApiService.uploadFile).
  final Map<String, dynamic>? summary;

  const FileItem({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.metaLabel,
    required this.timeLabel,
    required this.kind,
    this.status = FileStatus.clean,
    this.issueCount = 0,
    this.isRecent = false,
    this.isShared = false,
    this.isFavorite = false,
    this.filePath,
    this.fileId,
    this.summary,
  });

  /// True once this file can actually be re-analyzed/edited — either
  /// because it was just picked on-device this session, or because
  /// the backend has a stored copy from a previous upload.
  bool get canBeReanalyzed => filePath != null || fileId != null;

  IconData get icon {
    switch (kind) {
      case FileKind.excel:
        return Icons.table_chart_outlined;
      case FileKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case FileKind.word:
        return Icons.description_outlined;
      case FileKind.image:
        return Icons.image_outlined;
      case FileKind.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color get iconColor {
    switch (kind) {
      case FileKind.excel:
        return AppColors.success;
      case FileKind.pdf:
        return AppColors.error;
      case FileKind.word:
        return AppColors.primary;
      case FileKind.image:
        return AppColors.tertiary;
      case FileKind.other:
        return AppColors.onSurfaceVariant;
    }
  }

  Color get iconBackground => iconColor.withOpacity(0.12);

  /// Total missing values across every column, computed from the real
  /// /upload summary. Zero if there's no summary yet.
  int get totalMissingCount {
    final missing = summary?['missing_values'] as Map<String, dynamic>?;
    if (missing == null) return 0;
    return missing.values.fold<int>(0, (sum, v) => sum + (v as int));
  }

  /// Returns a copy of this file with the given fields replaced — used to
  /// toggle things like [isFavorite] since FileItem is otherwise immutable.
  FileItem copyWith({
    bool? isRecent,
    bool? isShared,
    bool? isFavorite,
    String? metaLabel,
    String? timeLabel,
    FileStatus? status,
    int? issueCount,
    String? filePath,
    int? fileId,
    Map<String, dynamic>? summary,
  }) {
    return FileItem(
      id: id,
      name: name,
      sizeLabel: sizeLabel,
      metaLabel: metaLabel ?? this.metaLabel,
      timeLabel: timeLabel ?? this.timeLabel,
      kind: kind,
      status: status ?? this.status,
      issueCount: issueCount ?? this.issueCount,
      isRecent: isRecent ?? this.isRecent,
      isShared: isShared ?? this.isShared,
      isFavorite: isFavorite ?? this.isFavorite,
      filePath: filePath ?? this.filePath,
      fileId: fileId ?? this.fileId,
      summary: summary ?? this.summary,
    );
  }

  static FileKind kindFromExtension(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'xlsx':
      case 'xls':
      case 'csv':
        return FileKind.excel;
      case 'pdf':
        return FileKind.pdf;
      case 'doc':
      case 'docx':
        return FileKind.word;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return FileKind.image;
      default:
        return FileKind.other;
    }
  }

  /// Builds a FileItem from a real POST /upload response. This is the
  /// only place FileItem instances should be created once a file has
  /// actually gone through the backend.
  factory FileItem.fromUploadResponse({
    String? filePath,
    required String fileName,
    required String sizeLabel,
    required Map<String, dynamic> summary,
  }) {
    final missing = summary['missing_values'] as Map<String, dynamic>?;
    final totalMissing = missing == null
        ? 0
        : missing.values.fold<int>(0, (sum, v) => sum + (v as int));
    final totalRows = summary['total_rows'];

    final extension = fileName.contains('.') ? fileName.split('.').last : null;

    return FileItem(
      id: (summary['file_id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
      name: fileName,
      sizeLabel: sizeLabel,
      metaLabel: totalRows != null ? '$totalRows rows' : 'Uploaded',
      timeLabel: 'Just now',
      kind: kindFromExtension(extension),
      status: totalMissing > 0 ? FileStatus.issues : FileStatus.clean,
      issueCount: totalMissing,
      isRecent: true,
      filePath: filePath,
      fileId: summary['file_id'] as int?,
      summary: summary,
    );
  }

  /// Builds a FileItem from one entry of the GET /files history list.
  /// These have no local device path (the picked file is long gone),
  /// so they rely entirely on [fileId] for any future backend calls.
  factory FileItem.fromHistoryRecord(Map<String, dynamic> record) {
    final missing = record['missing_values'] as Map<String, dynamic>?;
    final totalMissing = missing == null
        ? 0
        : missing.values.fold<int>(0, (sum, v) => sum + (v as int));
    final totalRows = record['total_rows'];
    final fileName = record['filename'] as String? ?? 'Unknown file';
    final extension = fileName.contains('.') ? fileName.split('.').last : null;

    return FileItem(
      id: record['file_id'].toString(),
      name: fileName,
      sizeLabel: '',
      metaLabel: totalRows != null ? '$totalRows rows' : '',
      timeLabel: _formatUploadedAt(record['uploaded_at'] as String?),
      kind: kindFromExtension(extension),
      status: totalMissing > 0 ? FileStatus.issues : FileStatus.clean,
      issueCount: totalMissing,
      fileId: record['file_id'] as int?,
      summary: {
        'total_rows': record['total_rows'],
        'total_columns': record['total_columns'],
        'missing_values': record['missing_values'],
        'filename': fileName,
      },
    );
  }

  static String _formatUploadedAt(String? isoString) {
    if (isoString == null) return '';
    final uploaded = DateTime.tryParse(isoString);
    if (uploaded == null) return '';
    final diff = DateTime.now().difference(uploaded);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
