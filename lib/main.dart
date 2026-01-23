import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/localization.dart';
import 'core/providers/language_provider.dart';
import 'core/services/sync_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/reminder_migration_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/premium_service.dart';
import 'core/services/insights_notification_service.dart';
import 'features/onboarding/presentation/splash_screen.dart';

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Sync state provider
final syncStateProvider = StreamProvider<SyncState>((ref) {
  return SyncService.instance.syncStateStream;
});

// Firebase initialization state
final firebaseInitProvider = FutureProvider<bool>((ref) async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('Firebase init error: $e');
    return false;
  }
});

// App initialization state
class AppInitState {
  final bool firebaseReady;
  final String? error;
  
  AppInitState({required this.firebaseReady, this.error});
}

final appInitProvider = FutureProvider<AppInitState>((ref) async {
  String? error;
  bool firebaseReady = false;

  // 0. Initialize language FIRST (before Firebase)
  try {
    await AppLocalizations.initLanguage();
    debugPrint('✅ Language initialized: ${AppLocalizations.currentLanguage}');
  } catch (e) {
    debugPrint('⚠️ Language init error: $e');
  }

  // 1. Firebase init
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    error = 'Firebase init failed: $e';
    debugPrint('❌ $error');
  }
  
  // 2. Other services (only if Firebase is ready)
  if (firebaseReady) {
    try {
      await NotificationService.instance.init();
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('⚠️ NotificationService init error: $e');
    }
    
    try {
      await SyncService.instance.init();
      debugPrint('✅ SyncService initialized');
    } catch (e) {
      debugPrint('⚠️ SyncService init error: $e');
    }
    
    try {
      await FCMService.instance.init();
      debugPrint('✅ FCMService initialized');
    } catch (e) {
      debugPrint('⚠️ FCMService init error: $e');
    }
    
    try {
      await WidgetService.instance.init();
      debugPrint('✅ WidgetService initialized');
    } catch (e) {
      debugPrint('⚠️ WidgetService init error: $e');
    }

    try {
      await ReminderMigrationService.instance.runMigrationIfNeeded();
      debugPrint('✅ ReminderMigrationService completed');
    } catch (e) {
      debugPrint('⚠️ ReminderMigrationService error: $e');
    }

    // Initialize Ad Service
    try {
      await AdService.instance.init();
      debugPrint('✅ AdService initialized');
    } catch (e) {
      debugPrint('⚠️ AdService init error: $e');
    }

    // Initialize Premium Service
    try {
      await PremiumService.instance.init();
      debugPrint('✅ PremiumService initialized');
    } catch (e) {
      debugPrint('⚠️ PremiumService init error: $e');
    }

    // Reset insights state (one-time migration to new delivery-based system)
    try {
      final prefs = await SharedPreferences.getInstance();
      final insightsMigrated = prefs.getBool('insights_v2_migration_done') ?? false;
      if (!insightsMigrated) {
        await InsightsNotificationService.instance.resetAllInsightsState();
        await prefs.setBool('insights_v2_migration_done', true);
        debugPrint('✅ Insights system reset for v2 delivery-based system');
      }
    } catch (e) {
      debugPrint('⚠️ Insights migration error: $e');
    }
  }

  return AppInitState(firebaseReady: firebaseReady, error: error);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set language based on system locale
  final systemLocale = ui.PlatformDispatcher.instance.locale.languageCode;
  switch (systemLocale) {
    case 'tr': AppLocalizations.setLanguage(AppLanguage.tr); break;
    case 'de': AppLocalizations.setLanguage(AppLanguage.de); break;
    case 'es': AppLocalizations.setLanguage(AppLanguage.es); break;
    case 'ar': AppLocalizations.setLanguage(AppLanguage.ar); break;
    default: AppLocalizations.setLanguage(AppLanguage.en);
  }
  
  runApp(const ProviderScope(child: DotcatApp()));
}

class DotcatApp extends ConsumerWidget {
  const DotcatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appInit = ref.watch(appInitProvider);
    
    Locale locale;
    switch (AppLocalizations.currentLanguage) {
      case AppLanguage.tr: locale = const Locale('tr', 'TR'); break;
      case AppLanguage.de: locale = const Locale('de', 'DE'); break;
      case AppLanguage.es: locale = const Locale('es', 'ES'); break;
      case AppLanguage.ar: locale = const Locale('ar', 'SA'); break;
      default: locale = const Locale('en', 'US');
    }
    
    return MaterialApp(
      title: 'PetCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('es', 'ES'),
        Locale('ar', 'SA'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: appInit.when(
        loading: () => const _LoadingScreen(),
        error: (error, stack) => _ErrorScreen(error: error.toString()),
        data: (state) {
          if (!state.firebaseReady) {
            return _ErrorScreen(error: state.error ?? 'Firebase başlatılamadı');
          }
          return const SplashScreen();
        },
      ),
    );
  }
}

/// Loading screen while app initializes
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 80),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Yükleniyor...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen when Firebase fails
class _ErrorScreen extends StatelessWidget {
  final String error;
  
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Uygulama Başlatılamadı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Lütfen internet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
