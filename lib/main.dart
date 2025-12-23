import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/localization.dart';
import 'core/providers/language_provider.dart';
import 'features/onboarding/presentation/splash_screen.dart';

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase init
  await Firebase.initializeApp();
  
  await NotificationService.instance.init();
  
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
      home: const SplashScreen(),
    );
  }
}
