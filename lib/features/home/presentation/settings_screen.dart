import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../main.dart';
import '../../auth/presentation/login_screen.dart';
import '../../cats/providers/cats_provider.dart';
import '../../reminders/providers/reminders_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _reminderHoursBefore = 24;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _notificationSound = 'default'; // 'default', 'cat_meow'

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
      _soundEnabled = prefs.getBool('notification_sound') ?? true;
      _vibrationEnabled = prefs.getBool('notification_vibration') ?? true;
      _notificationSound = prefs.getString('notification_sound_type') ?? 'default';
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('reminder_hours_before', _reminderHoursBefore);
    await prefs.setBool('notification_sound', _soundEnabled);
    await prefs.setBool('notification_vibration', _vibrationEnabled);
    await prefs.setString('notification_sound_type', _notificationSound);
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
        padding: const EdgeInsets.all(16),
        children: [
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
      child: Column(children: [
        // Ana toggle
        SwitchListTile(
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
        
        if (_notificationsEnabled) ...[
          const Divider(height: 1),
          // Ses
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off, color: AppColors.primary, size: 20),
            ),
            title: Text(AppLocalizations.get('notification_sound')),
            value: _soundEnabled,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _saveNotificationSettings();
            },
          ),
          const Divider(height: 1),
          // Titreşim
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_vibrationEnabled ? Icons.vibration : Icons.phone_android, color: AppColors.primary, size: 20),
            ),
            title: Text(AppLocalizations.get('notification_vibration')),
            value: _vibrationEnabled,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _vibrationEnabled = value);
              _saveNotificationSettings();
            },
          ),
          const Divider(height: 1),
          // Bildirim sesi seçimi
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_notificationSound == 'cat_meow' ? Icons.pets : Icons.music_note, color: AppColors.primary, size: 20),
            ),
            title: Text(AppLocalizations.get('notification_sound_type')),
            subtitle: Text(_notificationSound == 'cat_meow' ? AppLocalizations.get('cat_meow_sound') : AppLocalizations.get('default_sound'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSoundSelector(),
          ),
          const Divider(height: 1),
          // Test bildirimi
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.send, color: AppColors.success, size: 20),
            ),
            title: Text(AppLocalizations.get('test_notification')),
            onTap: () => _sendTestNotification(),
          ),
        ],
      ]),
    );
  }

  String _getReminderTimeText() {
    switch (_reminderHoursBefore) {
      case 1: return AppLocalizations.get('1_hour_before');
      case 2: return AppLocalizations.get('2_hours_before');
      case 6: return AppLocalizations.get('6_hours_before');
      case 12: return AppLocalizations.get('12_hours_before');
      case 24: return AppLocalizations.get('1_day_before');
      case 48: return AppLocalizations.get('2_days_before');
      case 168: return AppLocalizations.get('1_week_before');
      default: return '$_reminderHoursBefore ${AppLocalizations.get('hours_before')}';
    }
  }

  void _showReminderTimeSelector() {
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
          Text(AppLocalizations.get('remind_before'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...[1, 2, 6, 12, 24, 48, 168].map((hours) => ListTile(
            title: Text(_getReminderTimeTextForHours(hours)),
            trailing: _reminderHoursBefore == hours ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _reminderHoursBefore = hours);
              _saveNotificationSettings();
              Navigator.pop(ctx);
            },
          )),
        ]),
      ),
    );
  }

  String _getReminderTimeTextForHours(int hours) {
    switch (hours) {
      case 1: return AppLocalizations.get('1_hour_before');
      case 2: return AppLocalizations.get('2_hours_before');
      case 6: return AppLocalizations.get('6_hours_before');
      case 12: return AppLocalizations.get('12_hours_before');
      case 24: return AppLocalizations.get('1_day_before');
      case 48: return AppLocalizations.get('2_days_before');
      case 168: return AppLocalizations.get('1_week_before');
      default: return '$hours ${AppLocalizations.get('hours_before')}';
    }
  }

  void _showSoundSelector() {
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
          Text(AppLocalizations.get('notification_sound_type'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.music_note, color: AppColors.primary),
            title: Text(AppLocalizations.get('default_sound')),
            trailing: _notificationSound == 'default' ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _notificationSound = 'default');
              _saveNotificationSettings();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.pets, color: AppColors.primary),
            title: Text(AppLocalizations.get('cat_meow_sound')),
            trailing: _notificationSound == 'cat_meow' ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _notificationSound = 'cat_meow');
              _saveNotificationSettings();
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    // İzin kontrolü
    final hasPermission = await NotificationService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.get('notification_permission_required')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
      return;
    }
    
    // Bildirim sesi ayarını al
    final soundType = _notificationSound;
    
    // Test bildirimi gönder (hemen göster)
    await NotificationService.instance.showNotification(
      id: 999,
      title: AppLocalizations.get('test_notification'),
      body: AppLocalizations.get('test_notification_body'),
      soundType: soundType,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('test_notification_sent')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
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
