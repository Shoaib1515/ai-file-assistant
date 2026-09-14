import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';

class FileCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const FileCard({super.key, required this.file, this.onTap, this.onFavoriteToggle, this.onDownload, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Material(
      color: isDark ? const Color(0xFF1E1F24) : Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3038) : Colors.white.withOpacity(0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: file.iconBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(file.icon, color: file.iconColor, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: AppTextStyles.labelMd.copyWith(
                            color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          file.sizeLabel,
                          style: AppTextStyles.bodySm.copyWith(
                            color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onFavoriteToggle,
                    icon: Icon(
                      file.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: file.isFavorite ? AppColors.tertiary : (isDark ? const Color(0xFF8E8D9F) : AppColors.outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    file.metaLabel,
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    file.timeLabel,
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.download_outlined,
                      size: 20,
                      color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                    ),
                    onPressed: onDownload,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: onDelete,
                  ),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (file.status) {
      case FileStatus.clean:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.successContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: const Icon(Icons.check, color: AppColors.success, size: 16),
        );
      case FileStatus.warning:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warningContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.warning.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text('${file.issueCount}', style: AppTextStyles.labelSm.copyWith(color: AppColors.warning)),
            ],
          ),
        );
      case FileStatus.issues:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.error.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Text('${file.issueCount}', style: AppTextStyles.labelSm.copyWith(color: AppColors.error)),
            ],
          ),
        );
    }
  }
}
