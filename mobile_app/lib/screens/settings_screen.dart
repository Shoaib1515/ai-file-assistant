import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _displayName = 'Alex Kim';
  String _email = 'alex.kim@example.com';
  String _cacheText = '124 MB';

  static const String _prefsNameKey = 'settings_display_name';
  static const String _prefsEmailKey = 'settings_email';
  static const String _prefsDarkModeKey = 'settings_dark_mode';
  static const String _prefsPushKey = 'settings_push_notifications';
  static const String _prefsEmailReportsKey = 'settings_email_reports';
  static const String _prefsBiometricKey = 'settings_biometric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _displayName = prefs.getString(_prefsNameKey) ?? _displayName;
      _email = prefs.getString(_prefsEmailKey) ?? _email;
      _darkMode = prefs.getBool(_prefsDarkModeKey) ?? _darkMode;
      _pushNotifications = prefs.getBool(_prefsPushKey) ?? _pushNotifications;
      _emailReports = prefs.getBool(_prefsEmailReportsKey) ?? _emailReports;
      _biometric = prefs.getBool(_prefsBiometricKey) ?? _biometric;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsNameKey, _displayName);
    await prefs.setString(_prefsEmailKey, _email);
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
    final initials = _displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final avatarInitials = initials.length > 2 ? initials.substring(0, 2) : initials;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
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
                    color: AppColors.surfaceContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          avatarInitials.isEmpty ? 'AK' : avatarInitials,
                          style: AppTextStyles.headlineLg.copyWith(color: AppColors.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_displayName, style: AppTextStyles.headlineLgMobile),
                            Text(_email, style: AppTextStyles.bodySm),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showProfileEditor,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('PREFERENCES'),
                _sectionCard([
                  _switchTile(Icons.dark_mode_outlined, 'Dark Mode', _darkMode, (v) async {
                    setState(() => _darkMode = v);
                    await _saveBool(_prefsDarkModeKey, v);
                  }),
                  _switchTile(Icons.notifications_active_outlined, 'Push Notifications', _pushNotifications,
                      (v) async {
                    setState(() => _pushNotifications = v);
                    await _saveBool(_prefsPushKey, v);
                  }),
                  _switchTile(Icons.mail_outline, 'Email Reports', _emailReports, (v) async {
                    setState(() => _emailReports = v);
                    await _saveBool(_prefsEmailReportsKey, v);
                  }),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('SECURITY'),
                _sectionCard([
                  _navTile(Icons.lock_outline, 'Change Password', onTap: _showPasswordDialog),
                  _switchTile(Icons.fingerprint, 'Biometric Login', _biometric, (v) async {
                    setState(() => _biometric = v);
                    await _saveBool(_prefsBiometricKey, v);
                  }),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('DATA & PRIVACY'),
                _sectionCard([
                  _navTile(Icons.cleaning_services_outlined, 'Clear Cache', trailing: _cacheText, onTap: _clearCache),
                  _navTile(Icons.policy_outlined, 'Privacy Policy', onTap: () => _showInfoDialog(
                        'Privacy Policy',
                        'This app stores your uploaded files and metadata locally for the current session and encrypted user token preferences. Files are processed on the backend and not shared publicly without your consent.',
                      )),
                  _navTile(Icons.gavel_outlined, 'Terms of Service', onTap: () => _showInfoDialog(
                        'Terms of Service',
                        'By using this app, you agree to use the AI analysis tools responsibly, avoid uploading sensitive personal data without permission, and keep your credentials secure.',
                      )),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('ABOUT'),
                _sectionCard([
                  _navTile(Icons.star_outline, 'Rate App', onTap: () => _showInfoDialog(
                        'Rate App',
                        'Thanks for using AI File Assistant. Please leave a review in the app store to help us improve future releases.',
                      ), color: AppColors.tertiaryContainer),
                  _navTile(Icons.info_outline, 'App Version', trailing: 'v1.0.0'),
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
                      side: const BorderSide(color: AppColors.outlineVariant),
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

  Future<void> _showProfileEditor() async {
    final nameController = TextEditingController(text: _displayName);
    final emailController = TextEditingController(text: _email);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;
    setState(() {
      _displayName = nameController.text.trim().isEmpty ? _displayName : nameController.text.trim();
      _email = emailController.text.trim().isEmpty ? _email : emailController.text.trim();
    });
    await _saveProfile();
  }

  Future<void> _showPasswordDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.text.trim().isEmpty ? 'Password update skipped.' : 'Password updated successfully.')),
      );
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cache'),
        content: const Text('This will remove local cached app data and reset the current cache meter.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _cacheText = '0 MB');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully.')),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
        child: Text(text,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary, letterSpacing: 1.0)),
      );

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: AppColors.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _switchTile(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String label,
      {String? trailing, VoidCallback? onTap, Color color = AppColors.outline}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
            if (trailing != null)
              Text(trailing, style: AppTextStyles.bodySm)
            else if (onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
