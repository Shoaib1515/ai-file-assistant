import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';

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

      // Save file cross-platform (Chrome browser download / Mobile device storage)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = widget.file.name.contains('.')
          ? widget.file.name.split('.').first
          : widget.file.name;
      final fileName = 'updated_${baseName}_$timestamp.xlsx';
      final savedMessage = await FileSaver.saveFile(fileName, bytes);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = savedMessage;
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

  final List<Map<String, String>> _quickActions = const [
    {
      'label': 'Fill Missing Data',
      'icon': '🧹',
      'prompt': 'Fill all missing and empty cells with appropriate default values or 0',
    },
    {
      'label': 'Capitalize Names',
      'icon': '🔤',
      'prompt': 'Capitalize all text and name columns in Title Case (e.g. John Doe)',
    },
    {
      'label': 'Clean Emails',
      'icon': '✉️',
      'prompt': 'Convert all email addresses to lowercase and remove spaces',
    },
    {
      'label': 'Format Dates',
      'icon': '📅',
      'prompt': 'Standardize all dates to YYYY-MM-DD format',
    },
    {
      'label': 'Round Numbers',
      'icon': '💵',
      'prompt': 'Round all decimal numeric values to 2 decimal places',
    },
    {
      'label': 'Trim Spaces',
      'icon': '✂️',
      'prompt': 'Remove extra leading and trailing whitespace from all columns',
    },
  ];

  String? _selectedActionLabel;

  void _applyQuickAction(String label, String prompt) {
    setState(() {
      _selectedActionLabel = label;
      _instructionController.text = prompt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasNoPath = !widget.file.canBeReanalyzed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Edit · ${widget.file.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headlineLgMobile,
              ),
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
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Friendly Hint
                      Row(
                        children: [
                          Text('What should be changed?', style: AppTextStyles.labelMd),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.language_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'English / Roman Urdu',
                                  style: AppTextStyles.bodySm.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Instruction Input Box
                      TextField(
                        controller: _instructionController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "e.g. Update Ali's email to ali@new.com ya missing values fill kardo",
                          hintStyle: AppTextStyles.bodySm.copyWith(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : AppColors.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // 1-Tap Quick Action Suggestions Header
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '1-Tap Quick Suggestions (Click to auto-fill):',
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Quick Action Chips Wrap
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickActions.map((action) {
                          final isSelected = _selectedActionLabel == action['label'];
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _applyQuickAction(action['label']!, action['prompt']!),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(action['icon']!, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    action['label']!,
                                    style: AppTextStyles.bodySm.copyWith(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white : const Color(0xFF334155)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Suggest Changes Button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getSuggestions,
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('✨ Suggest Changes with AI'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 10),
                              Text(
                                'AI is generating cell modifications...',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.onErrorContainer),
                          ),
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
                                child: Text(
                                  _successMessage!,
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_proposedChanges != null) _buildChangesList(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildChangesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_proposedChanges!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            "AI couldn't confidently find a matching change. Try selecting one of the quick suggestion chips above.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_proposedChanges!.length} change(s) proposed:',
          style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _proposedChanges!.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final change = _proposedChanges![index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                  Text(
                    'Row ${change['row_number']} · ${change['column']}',
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.onSurfaceVariant,
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
