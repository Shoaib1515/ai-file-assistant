import 'package:flutter/material.dart';
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
                    color: AppColors.surfaceContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text('AK',
                            style: AppTextStyles.headlineLg.copyWith(color: AppColors.onPrimaryContainer)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alex Kim', style: AppTextStyles.headlineLgMobile),
                            Text('alex.kim@example.com', style: AppTextStyles.bodySm),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
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
                  _switchTile(Icons.dark_mode_outlined, 'Dark Mode', _darkMode,
                      (v) => setState(() => _darkMode = v)),
                  _switchTile(Icons.notifications_active_outlined, 'Push Notifications',
                      _pushNotifications, (v) => setState(() => _pushNotifications = v)),
                  _switchTile(Icons.mail_outline, 'Email Reports', _emailReports,
                      (v) => setState(() => _emailReports = v)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('SECURITY'),
                _sectionCard([
                  _navTile(Icons.lock_outline, 'Change Password', onTap: () {}),
                  _switchTile(Icons.fingerprint, 'Biometric Login', _biometric,
                      (v) => setState(() => _biometric = v)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('DATA & PRIVACY'),
                _sectionCard([
                  _navTile(Icons.cleaning_services_outlined, 'Clear Cache', trailing: '124 MB', onTap: () {}),
                  _navTile(Icons.policy_outlined, 'Privacy Policy', onTap: () {}),
                  _navTile(Icons.gavel_outlined, 'Terms of Service', onTap: () {}),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('ABOUT'),
                _sectionCard([
                  _navTile(Icons.star_outline, 'Rate App', onTap: () {}, color: AppColors.tertiaryContainer),
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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
        child: Text(text,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary, letterSpacing: 1.0)),
      );

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
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
            activeColor: AppColors.primary,
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
