import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/premium_service.dart';
import '../../../main.dart';
import '../../auth/presentation/login_screen.dart';
import '../../premium/presentation/premium_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _reminderHoursBefore = 24;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _reminderHoursBefore = prefs.getInt('reminder_hours_before') ?? 24;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('reminder_hours_before', _reminderHoursBefore);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.get('settings'))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Premium section
          _buildSectionTitle(AppLocalizations.get('premium')),
          _buildPremiumTile(context, isDark),

          const SizedBox(height: 20),

          // Account section
          _buildSectionTitle(AppLocalizations.get('account')),
          _buildAccountTile(context, ref, user, isDark),

          const SizedBox(height: 20),

          // Appearance section
          _buildSectionTitle(AppLocalizations.get('appearance')),
          _buildSettingsTile(
            context,
            icon: Icons.language,
            title: AppLocalizations.get('language'),
            subtitle: _getLanguageName(language),
            onTap: () => _showLanguageDialog(context, ref),
            isDark: isDark,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.palette_outlined,
            title: AppLocalizations.get('theme'),
            subtitle: _getThemeText(themeMode),
            onTap: () => _showThemeDialog(context, ref),
            isDark: isDark,
          ),
          
          const SizedBox(height: 20),
          
          // Notifications section
          _buildSectionTitle(AppLocalizations.get('notifications')),
          _buildNotificationTile(isDark),
          
          const SizedBox(height: 20),
          
          // About section
          _buildSectionTitle(AppLocalizations.get('about')),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: AppLocalizations.get('about_app'),
            subtitle: 'v1.0.0',
            onTap: () => _showAboutDialog(context, isDark),
            isDark: isDark,
          ),
        ],
      ),
    );
  }


  Widget _buildPremiumTile(BuildContext context, bool isDark) {
    final premiumStatus = ref.watch(premiumStatusProvider);
    final isPremium = premiumStatus == PremiumStatus.premium;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isPremium
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.amber.shade100,
                    Colors.orange.shade100,
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPremium ? AppColors.primary.withOpacity(0.3) : Colors.amber.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPremium ? AppColors.primary.withOpacity(0.1) : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPremium ? Icons.verified : Icons.workspace_premium,
                color: isPremium ? AppColors.primary : Colors.amber.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium
                        ? AppLocalizations.get('premium_active')
                        : AppLocalizations.get('premium_title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPremium ? AppColors.primary : Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? AppLocalizations.get('manage_subscription')
                        : AppLocalizations.get('premium_subtitle'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isPremium ? context.textSecondary : Colors.amber.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPremium ? AppColors.primary : Colors.amber.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, WidgetRef ref, User? user, bool isDark) {
    if (user != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, color: AppColors.primary) : null,
            ),
            title: Text(user.displayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user.email ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_done, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Text(AppLocalizations.get('synced'), style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.logout, color: AppColors.error, size: 20),
            ),
            title: Text(AppLocalizations.get('sign_out'), style: const TextStyle(color: AppColors.error)),
            onTap: () => _signOut(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_forever, color: AppColors.error, size: 20),
            ),
            title: Text(AppLocalizations.get('delete_account'), style: const TextStyle(color: AppColors.error)),
            onTap: () => _showDeleteAccountDialog(context, ref, isDark),
          ),
        ]),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
          ),
          title: Text(AppLocalizations.get('not_signed_in')),
          subtitle: Text(AppLocalizations.get('sign_in_to_sync'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
          trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text(AppLocalizations.get('sign_in')),
          ),
        ),
      );
    }
  }

  Widget _buildNotificationTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.notifications_active, color: AppColors.warning, size: 20),
        ),
        title: Text(AppLocalizations.get('enable_notifications')),
        subtitle: Text(AppLocalizations.get('notification_desc'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
        value: _notificationsEnabled,
        activeColor: AppColors.primary,
        onChanged: (value) {
          setState(() => _notificationsEnabled = value);
          _saveNotificationSettings();
        },
      ),
    );
  }




  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSkippedLogin', false);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(AppLocalizations.get('delete_account'), style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          AppLocalizations.get('delete_account_warning'),
          style: TextStyle(color: context.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.get('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount(context, ref);
            },
            child: Text(
              AppLocalizations.get('delete'),
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ref.read(authServiceProvider).deleteAccount();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        
        if (success) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasSkippedLogin', false);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.get('account_deleted')),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.get('delete_account_error')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.get('delete_account_reauth')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getLanguageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.en: return 'English';
      case AppLanguage.tr: return 'Türkçe';
      case AppLanguage.de: return 'Deutsch';
      case AppLanguage.es: return 'Español';
      case AppLanguage.ar: return 'العربية';
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(AppLocalizations.get('language'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...AppLanguage.values.map((lang) => ListTile(
            title: Text(_getLanguageName(lang)),
            trailing: AppLocalizations.currentLanguage == lang ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              ref.read(languageProvider.notifier).setLanguage(lang);
              Navigator.pop(ctx);
            },
          )),
        ]),
      ),
    );
  }

  String _getThemeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return AppLocalizations.get('theme_light');
      case ThemeMode.dark: return AppLocalizations.get('theme_dark');
      case ThemeMode.system: return AppLocalizations.get('theme_system');
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(AppLocalizations.get('theme'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.brightness_5),
            title: Text(AppLocalizations.get('theme_light')),
            trailing: currentMode == ThemeMode.light ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { ref.read(themeModeProvider.notifier).state = ThemeMode.light; Navigator.pop(ctx); },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_2),
            title: Text(AppLocalizations.get('theme_dark')),
            trailing: currentMode == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { ref.read(themeModeProvider.notifier).state = ThemeMode.dark; Navigator.pop(ctx); },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: Text(AppLocalizations.get('theme_system')),
            trailing: currentMode == ThemeMode.system ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { ref.read(themeModeProvider.notifier).state = ThemeMode.system; Navigator.pop(ctx); },
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)) : null,
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Image.asset('assets/images/logo.png', height: 50),
          const SizedBox(height: 16),
          const Text('PetCare', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('v1.0.0', style: TextStyle(fontSize: 14, color: context.textSecondary)),
          const SizedBox(height: 16),
          Text(AppLocalizations.get('app_description'), style: TextStyle(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
