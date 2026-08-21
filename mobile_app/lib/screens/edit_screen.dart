import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Lets the user describe a change in plain English, review exactly what
/// the AI proposes (old value -> new value, per row/column), and only
/// writes anything to the file after they explicitly tap Approve.
class EditScreen extends StatefulWidget {
  final FileItem file;
  const EditScreen({super.key, required this.file});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _instructionController = TextEditingController();
  bool _isLoading = false;
  List<dynamic>? _proposedChanges;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _getSuggestions() async {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty || !widget.file.canBeReanalyzed) return;

    setState(() {
      _isLoading = true;
      _proposedChanges = null;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final List<dynamic> changes;
      if (widget.file.filePath != null) {
        changes = await ApiService.suggestEdit(
          widget.file.filePath!,
          widget.file.name,
          instruction,
        );
      } else {
        changes = await ApiService.suggestEditStored(widget.file.fileId!, instruction);
      }
      setState(() {
        _proposedChanges = changes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _approveChanges() async {
    if (!widget.file.canBeReanalyzed || _proposedChanges == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final Uint8List bytes;
      if (widget.file.filePath != null) {
        bytes = await ApiService.applyEdit(
          widget.file.filePath!,
          widget.file.name,
          _proposedChanges!,
        );
      } else {
        bytes = await ApiService.applyEditStored(widget.file.fileId!, _proposedChanges!);
      }

      // Save the file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'updated_${widget.file.name.split('.').first}_$timestamp.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = 'File saved to: ${file.path}';
        _proposedChanges = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated file saved: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to apply changes: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _cancelChanges() {
    setState(() => _proposedChanges = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasNoPath = !widget.file.canBeReanalyzed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text('Edit · ${widget.file.name}',
                  overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineLgMobile),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerPadding),
          child: hasNoPath
              ? Center(
                  child: Text(
                    'This file has no local path — try re-uploading it.',
                    style: AppTextStyles.bodyMd,
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('What should be changed?', style: AppTextStyles.labelMd),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _instructionController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "e.g. Update Ali's email to ali@new.com",
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getSuggestions,
                      icon: const Icon(Icons.auto_awesome, size: 20),
                      label: const Text('Suggest Changes'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_isLoading) const Center(child: CircularProgressIndicator()),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(_errorMessage!,
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.onErrorContainer)),
                      ),
                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.successContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_successMessage!,
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.success)),
                            ),
                          ],
                        ),
                      ),
                    if (_proposedChanges != null) Expanded(child: _buildChangesList()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChangesList() {
    if (_proposedChanges!.isEmpty) {
      return Center(
        child: Text(
          "AI couldn't confidently find a matching change. Try being more specific.",
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${_proposedChanges!.length} change(s) proposed', style: AppTextStyles.labelMd),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: _proposedChanges!.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final change = _proposedChanges![index];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: AppColors.surfaceVariant.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row ${change['row_number']} · ${change['column']}',
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${change['old_value']}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySm.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.onSurfaceVariant),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '${change['new_value']}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.success),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _cancelChanges,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _approveChanges,
                child: const Text('Approve'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
