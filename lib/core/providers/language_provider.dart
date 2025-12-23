import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/localization.dart';

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLocalizations.currentLanguage);

  void setLanguage(AppLanguage language) {
    AppLocalizations.setLanguage(language);
    state = language;
  }

  void toggleLanguage() {
    final newLang = state == AppLanguage.en ? AppLanguage.tr : AppLanguage.en;
    setLanguage(newLang);
  }
}
