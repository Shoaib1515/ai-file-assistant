import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat_assistant_fab.dart';
import 'analyze_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _navIndex = 3;
  bool _darkMode = false;
  bool _pushNotifications = true;
  bool _emailReports = false;
  bool _biometric = false;
  String _userName = 'User';
  String _userEmail = 'user@example.com';
  String _avatarInitials = 'U';
  String _cacheSizeLabel = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _darkMode = AppTheme.themeNotifier.value == ThemeMode.dark;
    _loadProfile();
    _calculateCacheSize();
  }

  Future<void> _loadProfile() async {
    final cached = await ApiService.getUserProfile();
    if (mounted && (cached['email']?.isNotEmpty ?? false)) {
      setState(() {
        _userEmail = cached['email']!;
        _userName = (cached['name']?.isNotEmpty ?? false)
            ? cached['name']!
            : _userEmail.split('@').first;
        _avatarInitials = _computeInitials(_userName);
      });
    }

    try {
      final me = await ApiService.fetchMe();
      if (mounted && me['email'] != null) {
        setState(() {
          _userEmail = me['email'];
          _userName = (me['full_name'] != null && (me['full_name'] as String).isNotEmpty)
              ? me['full_name']
              : _userEmail.split('@').first;
          _avatarInitials = _computeInitials(_userName);
        });
      }
    } catch (_) {}
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalBytes += entity.lengthSync();
          }
        });
      }
      if (!mounted) return;
      setState(() {
        if (totalBytes >= 1024 * 1024) {
          _cacheSizeLabel = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else if (totalBytes >= 1024) {
          _cacheSizeLabel = '${(totalBytes / 1024).toStringAsFixed(0)} KB';
        } else {
          _cacheSizeLabel = '$totalBytes B';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _cacheSizeLabel = '0 KB');
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          try {
            if (entity is File) {
              entity.deleteSync();
            }
          } catch (_) {}
        });
      }
      await _calculateCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary cache cleared successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear cache: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  String _computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'U';
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTextStyles.labelMd.copyWith(fontSize: 18)),
        content: SingleChildScrollView(child: Text(content, style: AppTextStyles.bodyMd)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    int rating = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate AI File Assistant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate your experience?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.tertiary,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => rating = i + 1),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your rating! ⭐')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
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
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AnalyzeScreen()));
        break;
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HistoryScreen()));
        break;
      case 3:
        setState(() => _navIndex = 3);
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E3038) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 18),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding, vertical: AppSpacing.md),
              children: [
                // Account card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1F24) : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: isDark ? const Color(0xFF2E3038) : Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(_avatarInitials,
                            style: AppTextStyles.headlineLg.copyWith(color: AppColors.onPrimaryContainer)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_userName,
                                style: AppTextStyles.headlineLgMobile.copyWith(
                                  color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                                )),
                            Text(_userEmail,
                                style: AppTextStyles.bodySm.copyWith(
                                  color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('PREFERENCES'),
                _sectionCard(context, [
                  _switchTile(context, Icons.dark_mode_outlined, 'Dark Mode', _darkMode, (v) {
                    setState(() => _darkMode = v);
                    AppTheme.toggleTheme(v);
                  }),
                  _switchTile(context, Icons.notifications_active_outlined, 'Push Notifications',
                      _pushNotifications, (v) => setState(() => _pushNotifications = v)),
                  _switchTile(context, Icons.mail_outline, 'Email Reports', _emailReports,
                      (v) => setState(() => _emailReports = v)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('SECURITY'),
                _sectionCard(context, [
                  _navTile(context, Icons.lock_outline, 'Security & Authentication',
                      trailing: 'JWT Bearer',
                      onTap: () => _showInfoDialog(
                          'Security Information',
                          'Your session is protected with secure JWT authentication and password hashing (PBKDF2-HMAC-SHA256 with 100,000 rounds).')),
                  _switchTile(context, Icons.fingerprint, 'Biometric Login', _biometric,
                      (v) => setState(() => _biometric = v)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('DATA & PRIVACY'),
                _sectionCard(context, [
                  _navTile(context, Icons.cleaning_services_outlined, 'Clear Cache',
                      trailing: _cacheSizeLabel, onTap: _clearCache),
                  _navTile(context, Icons.policy_outlined, 'Privacy Policy',
                      onTap: () => _showInfoDialog(
                          'Privacy Policy',
                          'AI File Assistant processes your datasets strictly on your configured server. Files are never shared or sold to third parties.')),
                  _navTile(context, Icons.gavel_outlined, 'Terms of Service',
                      onTap: () => _showInfoDialog(
                          'Terms of Service',
                          'Use AI File Assistant responsibly to parse, clean, summarize, and edit your tabular and document datasets.')),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('ABOUT'),
                _sectionCard(context, [
                  _navTile(context, Icons.star_outline, 'Rate App',
                      onTap: _showRateAppDialog, color: AppColors.tertiaryContainer),
                  _navTile(context, Icons.info_outline, 'App Version',
                      trailing: 'v1.0.0',
                      onTap: () => _showInfoDialog(
                          'App Version',
                          'AI File Assistant v1.0.0\nFramework: Flutter 3.12+\nBackend: FastAPI + Groq & Gemini AI')),
                ]),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ApiService.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: isDark ? const Color(0xFF383844) : AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Logout'),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          const ChatAssistantFab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex, onTap: _onNavTap),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
        child: Text(text,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary, letterSpacing: 1.0)),
      );

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F24) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: isDark ? const Color(0xFF2E3038) : Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: isDark ? const Color(0xFF2E3038) : AppColors.outlineVariant.withOpacity(0.4)),
          ],
        ],
      ),
    );
  }

  Widget _switchTile(BuildContext context, IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    final isDark = context.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMd.copyWith(
                color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: isDark ? const Color(0xFF8183F5) : AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String label,
      {String? trailing, VoidCallback? onTap, Color color = AppColors.outline}) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: isDark ? const Color(0xFFE2E2E6) : AppColors.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: AppTextStyles.bodySm.copyWith(
                  color: isDark ? const Color(0xFFA5A4B5) : AppColors.onSurfaceVariant,
                ),
              )
            else if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: isDark ? const Color(0xFF8E8D9F) : AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
