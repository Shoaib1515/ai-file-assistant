import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';

/// Interactive Spreadsheet Editor:
/// Users can visually inspect dataset rows and columns, tap any cell to edit
/// directly in a friendly popup dialog, see live highlights on modified cells,
/// and download the updated file without needing to write prompts.
/// Also includes an optional expandable accordion for bulk AI transformations.
class EditScreen extends StatefulWidget {
  final FileItem file;
  const EditScreen({super.key, required this.file});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // Spreadsheet state
  bool _isLoadingPreview = true;
  List<String> _columns = [];
  List<Map<String, dynamic>> _tableRows = [];
  int _totalRows = 0;
  String? _previewError;
  List<String> _sheetNames = [];
  String? _activeSheet;

  // Track manual cell edits: key = "$rowNumber-$column"
  final Map<String, Map<String, dynamic>> _manualEdits = {};

  // Original snapshot to detect differences
  final Map<String, dynamic> _originalValues = {};

  // Search & Quick Filter State
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredRows {
    if (_searchQuery.trim().isEmpty) return _tableRows;
    final q = _searchQuery.trim().toLowerCase();
    return _tableRows.where((row) {
      if (row['row_number'].toString().contains(q)) return true;
      for (final col in _columns) {
        final val = row[col]?.toString().toLowerCase() ?? '';
        if (val.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  // AI assist state
  final _instructionController = TextEditingController();
  bool _isAILoading = false;
  List<dynamic>? _proposedAIChanges;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedActionLabel;

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

  @override
  void initState() {
    super.initState();
    _loadDatasetPreview();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDatasetPreview({String? sheetName}) async {
    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    try {
      final data = await ApiService.getFilePreview(
        fileId: widget.file.fileId,
        filePath: widget.file.filePath,
        fileName: widget.file.name,
        sheetName: sheetName ?? _activeSheet,
      );

      final cols = (data['columns'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
      final rawRows = (data['preview_rows'] as List<dynamic>?) ?? [];
      final rows = rawRows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final total = (data['total_rows'] as num?)?.toInt() ?? rows.length;
      final sheets = (data['sheet_names'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];
      final active = data['active_sheet']?.toString() ?? (sheets.isNotEmpty ? sheets.first : null);

      _originalValues.clear();
      _manualEdits.clear();
      for (final row in rows) {
        final rowNum = row['row_number'];
        for (final col in cols) {
          _originalValues['$rowNum-$col'] = row[col];
        }
      }

      if (!mounted) return;
      setState(() {
        _columns = cols;
        _tableRows = rows;
        _totalRows = total;
        _sheetNames = sheets;
        _activeSheet = active;
        _isLoadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPreview = false;
      });
    }
  }

  void _showEditCellDialog(int rowNumber, String column, dynamic currentValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentValue?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Value',
                      style: AppTextStyles.labelMd.copyWith(
                        fontSize: 16,
                        color: isDark ? Colors.white : AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Row $rowNumber · $column',
                      style: AppTextStyles.bodySm.copyWith(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original: "${_originalValues['$rowNumber-$column'] ?? ''}"',
                style: AppTextStyles.bodySm.copyWith(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : AppColors.onSurface),
                decoration: InputDecoration(
                  labelText: 'New Value',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newValue = controller.text;
                Navigator.of(ctx).pop();
                _applySingleCellEdit(rowNumber, column, newValue);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
              child: const Text('Update Cell'),
            ),
          ],
        );
      },
    );
  }

  void _applySingleCellEdit(int rowNumber, String column, String newValue) {
    setState(() {
      // 1. Update live preview table
      for (final row in _tableRows) {
        if (row['row_number'] == rowNumber) {
          row[column] = newValue;
          break;
        }
      }

      // 2. Track change
      final key = '$rowNumber-$column';
      final originalVal = _originalValues[key]?.toString() ?? '';
      if (newValue == originalVal) {
        _manualEdits.remove(key);
      } else {
        _manualEdits[key] = {
          'row_number': rowNumber,
          'column': column,
          'new_value': newValue,
          'old_value': originalVal,
        };
      }
      _successMessage = null;
    });
  }

  void _discardAllEdits() {
    setState(() {
      for (final row in _tableRows) {
        final rowNum = row['row_number'];
        for (final col in _columns) {
          row[col] = _originalValues['$rowNum-$col'];
        }
      }
      _manualEdits.clear();
      _proposedAIChanges = null;
      _successMessage = null;
      _errorMessage = null;
    });
  }

  void _promptSaveOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.save_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Save Changes',
                          style: AppTextStyles.labelMd.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '${_manualEdits.length} cell(s) modified',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Option 1: Overwrite Original File
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _saveAndOverwriteOriginal();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overwrite Original File (Same File)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Updates the original dataset in your library directly. No duplicate created.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2: Save as New File (Export Copy)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _saveAsNewFile();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Save as New File (Export Copy)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Keeps original untouched and downloads a new timestamped file.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndOverwriteOriginal() async {
    final changes = _manualEdits.values.toList();
    if (changes.isEmpty) return;

    setState(() {
      _isAILoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (widget.file.fileId != null) {
        await ApiService.applyEditStored(widget.file.fileId!, changes);
      } else if (widget.file.filePath != null) {
        final bytes = await ApiService.applyEdit(
          widget.file.filePath!,
          widget.file.name,
          changes,
        );
        await FileSaver.saveFile(widget.file.name, bytes);
      }

      if (!mounted) return;
      setState(() {
        _isAILoading = false;
        _manualEdits.clear();
        _proposedAIChanges = null;
      });

      // Refresh cached original values
      for (final row in _tableRows) {
        final rowNum = row['row_number'];
        for (final col in _columns) {
          _originalValues['$rowNum-$col'] = row[col];
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Original file successfully updated in place!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAILoading = false;
        _errorMessage = 'Failed to overwrite file: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _saveAsNewFile() async {
    final changes = _manualEdits.values.toList();
    if (changes.isEmpty) return;

    setState(() {
      _isAILoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final Uint8List bytes;
      if (widget.file.filePath != null) {
        bytes = await ApiService.applyEdit(
          widget.file.filePath!,
          widget.file.name,
          changes,
        );
      } else {
        bytes = await ApiService.applyEditStored(widget.file.fileId!, changes);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = widget.file.name.contains('.')
          ? widget.file.name.split('.').first
          : widget.file.name;
      final fileName = 'updated_${baseName}_$timestamp.xlsx';
      final savedMessage = await FileSaver.saveFile(fileName, bytes);

      if (!mounted) return;
      setState(() {
        _isAILoading = false;
        _successMessage = savedMessage;
        _manualEdits.clear();
        _proposedAIChanges = null;
      });

      // Refresh cached original values
      for (final row in _tableRows) {
        final rowNum = row['row_number'];
        for (final col in _columns) {
          _originalValues['$rowNum-$col'] = row[col];
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 New file copy saved & downloaded: $fileName'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAILoading = false;
        _errorMessage = 'Failed to save changes: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  // AI Suggestion helpers
  Future<void> _getAISuggestions() async {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty || !widget.file.canBeReanalyzed) return;

    setState(() {
      _isAILoading = true;
      _proposedAIChanges = null;
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
        _proposedAIChanges = changes;
        _isAILoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isAILoading = false;
      });
    }
  }

  void _applyAIProposedChanges() {
    if (_proposedAIChanges == null || _proposedAIChanges!.isEmpty) return;
    for (final change in _proposedAIChanges!) {
      final rowNum = change['row_number'];
      final col = change['column']?.toString() ?? '';
      final newVal = change['new_value']?.toString() ?? '';
      _applySingleCellEdit(rowNum, col, newVal);
    }
    setState(() {
      _proposedAIChanges = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI changes merged into table! Tap "Save & Download File" to finalize.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _applyQuickAction(String label, String prompt) {
    setState(() {
      _selectedActionLabel = label;
      _instructionController.text = prompt;
    });
    _getAISuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEdits = _manualEdits.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 20),
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
        actions: [
          if (hasEdits)
            TextButton.icon(
              onPressed: _discardAllEdits,
              icon: const Icon(Icons.undo_rounded, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status & Action Bar
            _buildStatusBar(isDark),

            // Sheet Selector Bar (if workbook has multiple sheets)
            _buildSheetSelectorBar(isDark),

            // Quick Search & Filter Bar
            _buildSearchBar(isDark),

            // Main Interactive Table or Loading
            Expanded(
              child: _isLoadingPreview
                  ? _buildLoadingState(isDark)
                  : _previewError != null
                      ? _buildErrorState(isDark)
                      : _buildSpreadsheetView(isDark),
            ),

            // Collapsible AI Prompt Accordion (Optional)
            _buildAIAssistantAccordion(isDark),
          ],
        ),
      ),
      bottomNavigationBar: hasEdits ? _buildSaveBottomBar(isDark) : null,
    );
  }

  Widget _buildStatusBar(bool isDark) {
    final hasEdits = _manualEdits.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Tap any cell to edit value',
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (hasEdits)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    '${_manualEdits.length} modified',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            )
          else if (_totalRows > 0)
            Text(
              '$_totalRows total rows',
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheetSelectorBar(bool isDark) {
    if (_sheetNames.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
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
          const SizedBox(height: 6),
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
                      _loadDatasetPreview(sheetName: sheet);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                          const SizedBox(width: 4),
                          Text(
                            sheet,
                            style: TextStyle(
                              fontSize: 11,
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

  Widget _buildSearchBar(bool isDark) {
    if (_isLoadingPreview || _previewError != null || _tableRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final isFiltering = _searchQuery.isNotEmpty;
    final matchCount = _filteredRows.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Row #, name, value, or text...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: isFiltering
                        ? AppColors.primary
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                  suffixIcon: isFiltering
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (isFiltering) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$matchCount found',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 14),
          Text(
            'Loading dataset spreadsheet...',
            style: AppTextStyles.bodySm.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Could not load table preview',
              style: AppTextStyles.labelMd.copyWith(
                fontSize: 18,
                color: isDark ? Colors.white : AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _previewError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: const Color(0xFFEF4444)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDatasetPreview,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpreadsheetView(bool isDark) {
    if (_columns.isEmpty || _tableRows.isEmpty) {
      return Center(
        child: Text(
          'No rows found in this dataset.',
          style: AppTextStyles.bodySm.copyWith(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    final rowsToDisplay = _filteredRows;

    if (rowsToDisplay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'No matching rows found',
                style: AppTextStyles.labelMd.copyWith(
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No records match "$_searchQuery". Try another keyword or clear filter.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear Search Filter'),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
            headingTextStyle: AppTextStyles.labelMd.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered)) {
                return isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
              }
              return null;
            }),
            columnSpacing: 24,
            horizontalMargin: 16,
            dividerThickness: 1,
            columns: [
              // Row Index Column
              const DataColumn(
                label: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
              // Dynamic Columns from dataset
              ..._columns.map(
                (col) => DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(col),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
            rows: rowsToDisplay.map((row) {
              final rowNumber = row['row_number'] as int;

              return DataRow(
                cells: [
                  // Row Number Cell
                  DataCell(
                    Text(
                      '$rowNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  // Column Value Cells (Interactive)
                  ..._columns.map((col) {
                    final cellKey = '$rowNumber-$col';
                    final isModified = _manualEdits.containsKey(cellKey);
                    final value = row[col]?.toString() ?? '';

                    return DataCell(
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _showEditCellDialog(rowNumber, col, row[col]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: isModified
                              ? BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                )
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                value.isEmpty ? '—' : value,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isModified
                                      ? const Color(0xFF10B981)
                                      : (value.isEmpty
                                          ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                          : (isDark ? Colors.white : AppColors.onSurface)),
                                  fontWeight: isModified ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                              if (isModified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isAILoading ? null : () => _promptSaveOptions(),
        icon: _isAILoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          _isAILoading ? 'Saving Edits...' : 'Save Changes (${_manualEdits.length} Edits)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        ),
      ),
    );
  }

  Widget _buildAIAssistantAccordion(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        collapsedIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        iconColor: AppColors.primary,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Bulk AI Edits & Prompts (Optional)',
              style: AppTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.onSurface,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Action Chips
                Text(
                  '1-Tap AI Quick Suggestions:',
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(action['icon']!, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              action['label']!,
                              style: TextStyle(
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
                const SizedBox(height: 10),

                // Prompt Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _instructionController,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.onSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "e.g. Set all status to active",
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : AppColors.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isAILoading ? null : _getAISuggestions,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                      child: _isAILoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Ask AI'),
                    ),
                  ],
                ),

                // AI Proposed Changes Preview
                if (_proposedAIChanges != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_proposedAIChanges!.length} AI change(s) proposed:',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _applyAIProposedChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Merge into Table', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Messages
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_successMessage!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
