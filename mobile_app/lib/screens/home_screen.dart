import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat_assistant_fab.dart';
import '../widgets/file_card.dart';
import 'analyze_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, this.userName = 'User'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  int _filterIndex = 0;
  final _filters = const ['All', 'Recent', 'Favorites', 'Excel', 'CSV', 'PDF'];
  final List<FileItem> _files = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _displayName = 'User';
  bool _isUploading = false;
  bool _isLoadingHistory = true;
  String? _historyError;

  List<FileItem> get _filteredFiles {
    Iterable<FileItem> result;
    switch (_filterIndex) {
      case 1: // Recent
        result = _files.where((f) => f.isRecent || f.timeLabel.toLowerCase().contains('just now') || f.timeLabel.toLowerCase().contains('m ago') || f.timeLabel.toLowerCase().contains('h ago') || f.timeLabel.toLowerCase().contains('1d ago'));
        break;
      case 2: // Favorites
        result = _files.where((f) => f.isFavorite);
        break;
      case 3: // Excel
        result = _files.where((f) => f.kind == FileKind.excel && (f.name.endsWith('.xlsx') || f.name.endsWith('.xls')));
        break;
      case 4: // CSV
        result = _files.where((f) => f.name.toLowerCase().endsWith('.csv'));
        break;
      case 5: // PDF
        result = _files.where((f) => f.kind == FileKind.pdf);
        break;
      default: // All
        result = _files;
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((f) => f.name.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _loadUserProfile();
    // No file is "open" while browsing the list — the chat assistant
    // should not try to answer questions grounded in a specific file here.
    ChatAssistantState.instance.setCurrentFile(null);
    _loadHistory();
  }

  Future<void> _loadUserProfile() async {
    final cached = await ApiService.getUserProfile();
    if (mounted && cached['name'] != null && cached['name']!.isNotEmpty) {
      setState(() => _displayName = cached['name']!);
    } else if (mounted && cached['email'] != null && cached['email']!.isNotEmpty) {
      setState(() => _displayName = cached['email']!.split('@').first);
    }
  }

  /// Restores the file list from the database so previously uploaded
  /// files are still visible after the app is closed and reopened.
  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final records = await ApiService.getAllFiles();
      final favIds = await ApiService.getFavoriteIds();
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(records.map((r) {
            final file = FileItem.fromHistoryRecord(r);
            return file.copyWith(isFavorite: favIds.contains(file.id));
          }));
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyzeScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  Future<void> _toggleFavorite(FileItem file) async {
    final newStatus = !file.isFavorite;
    await ApiService.setFavoriteId(file.id, newStatus);
    if (!mounted) return;
    setState(() {
      final index = _files.indexWhere((f) => f.id == file.id);
      if (index != -1) {
        _files[index] = _files[index].copyWith(isFavorite: newStatus);
      }
    });
  }

  Future<void> _downloadFile(FileItem file) async {
    if (file.fileId == null) return;
    try {
      final bytes = await ApiService.downloadFile(file.fileId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${file.name} (${bytes.length} bytes)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    if (file.fileId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete ${file.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteFile(file.fileId!);
      _loadHistory(); // Refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    }
  }
  /// Opens the native file picker, then uploads the chosen file to the
  /// real backend (POST /upload) and adds it to the list using the
  /// actual summary returned — no more fake "Just uploaded" placeholder.
  Future<void> _pickAndUploadFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );
    if (files == null || files.isEmpty) return;
    final picked = files.first;
    final String? path = picked.path;
    final Uint8List bytes = await picked.readAsBytes();
    final int sizeInBytes = await picked.length();

    setState(() => _isUploading = true);

    try {
      final summary = await ApiService.uploadFile(
        filePath: path,
        fileBytes: bytes,
        fileName: picked.name,
      );
      final newFile = FileItem.fromUploadResponse(
        filePath: path,
        fileName: picked.name,
        sizeLabel: _formatBytes(sizeInBytes),
        summary: summary,
      );

      setState(() {
        _files.insert(0, newFile);
        _isUploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newFile.name} uploaded successfully')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Files', style: AppTextStyles.labelMd.copyWith(fontSize: 18)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.containerPadding),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding),
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Hello, $_displayName! ',
                              style: AppTextStyles.headlineXl.copyWith(fontSize: 26)),
                          const Text('👋', style: TextStyle(fontSize: 26)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('What are we looking for today?',
                          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search files, contents, or formats...',
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
                    fillColor: Colors.white.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final selected = i == _filterIndex;
                      final isFavorites = _filters[i] == 'Favorites';
                      return ChoiceChip(
                        label: Text(_filters[i]),
                        selected: selected,
                        onSelected: (_) => setState(() => _filterIndex = i),
                        avatar: isFavorites ? const Icon(Icons.star_rounded, size: 16) : null,
                        labelStyle: AppTextStyles.labelSm.copyWith(
                          color: selected
                              ? AppColors.onPrimary
                              : (isFavorites ? AppColors.onTertiaryFixedVariant : AppColors.onSurfaceVariant),
                        ),
                        backgroundColor:
                            isFavorites ? AppColors.tertiaryFixed : Colors.white.withOpacity(0.6),
                        selectedColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          side: BorderSide(color: Colors.white.withOpacity(0.8)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Files', style: AppTextStyles.headlineLgMobile),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      child: Text('View All',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_isLoadingHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_historyError != null && !_isLoadingHistory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          'Could not load your files: $_historyError',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(onPressed: _loadHistory, child: const Text('Retry')),
                      ],
                    ),
                  ),
                if (_filteredFiles.isEmpty && !_isUploading && !_isLoadingHistory && _historyError == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_off_outlined,
                              size: 36, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _files.isEmpty
                                ? 'No files yet — tap + to upload one'
                                : (_searchQuery.trim().isNotEmpty
                                    ? 'No files match "$_searchQuery"'
                                    : 'No ${_filters[_filterIndex].toLowerCase()} files yet'),
                            style: AppTextStyles.bodySm,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    _filteredFiles.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: FileCard(
                        file: _filteredFiles[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AnalyzeScreen(file: _filteredFiles[i])),
                        ),
                        onFavoriteToggle: () => _toggleFavorite(_filteredFiles[i]),
                        onDownload: () => _downloadFile(_filteredFiles[i]),
                        onDelete: () => _deleteFile(_filteredFiles[i]),
                      ),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.containerPadding,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: _isUploading ? null : _pickAndUploadFile,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 28),
            ),
          ),
          const ChatAssistantFab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
    );
  }
}
