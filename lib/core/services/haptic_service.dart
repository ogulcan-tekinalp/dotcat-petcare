import 'package:flutter/services.dart';
import 'dart:io';

/// Haptic Feedback türleri
enum HapticType {
  light,      // Hafif tıklama
  medium,     // Orta şiddette
  heavy,      // Güçlü
  selection,  // Seçim değişimi
  success,    // Başarı
  warning,    // Uyarı
  error,      // Hata
}

/// Haptic Feedback Servisi
/// 
/// iOS ve Android için dokunsal geri bildirim sağlar.
class HapticService {
  static final HapticService instance = HapticService._init();
  
  HapticService._init();
  
  /// Haptic feedback tetikle
  Future<void> feedback(HapticType type) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    
    switch (type) {
      case HapticType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        await HapticFeedback.selectionClick();
        break;
      case HapticType.success:
        // iOS'ta success için özel pattern
        if (Platform.isIOS) {
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.lightImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }
        break;
      case HapticType.warning:
        await HapticFeedback.heavyImpact();
        break;
      case HapticType.error:
        // Error için çift titreşim
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
    }
  }
  
  /// Kısa tıklama
  Future<void> tap() => feedback(HapticType.light);
  
  /// Seçim değişimi
  Future<void> selection() => feedback(HapticType.selection);
  
  /// Başarı
  Future<void> success() => feedback(HapticType.success);
  
  /// Uyarı
  Future<void> warning() => feedback(HapticType.warning);
  
  /// Hata
  Future<void> error() => feedback(HapticType.error);
  
  /// Swipe
  Future<void> swipe() => feedback(HapticType.medium);
}


