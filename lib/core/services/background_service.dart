import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';
import 'widget_service.dart';
import 'insights_notification_service.dart';
import '../../data/database/database_helper.dart';

/// Background App Refresh Servisi
/// 
/// iOS Background App Refresh ve Android WorkManager kullanarak
/// arka planda görevleri günceller.
class BackgroundService {
  static final BackgroundService instance = BackgroundService._init();
  
  BackgroundService._init();
  
  static const String _lastRefreshKey = 'last_background_refresh';
  static const Duration _minRefreshInterval = Duration(hours: 1);
  
  Timer? _foregroundTimer;
  bool _isRunning = false;
  
  /// Servisi başlat
  Future<void> init() async {
    debugPrint('BackgroundService: Initializing...');
    
    // Uygulama açıkken periyodik güncelleme
    _startForegroundUpdates();
    
    // İlk yüklemede widget'ları güncelle
    await _performRefresh();
    
    debugPrint('BackgroundService: Initialized successfully');
  }
  
  /// Foreground timer'ı başlat (public - AppLifecycleService tarafından kullanılıyor)
  void startForegroundUpdates() {
    _foregroundTimer?.cancel();

    // Her 15 dakikada bir güncelle (uygulama açıkken)
    _foregroundTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _performRefresh(),
    );
  }

  /// Internal use için alias
  void _startForegroundUpdates() => startForegroundUpdates();

  /// Timer'ı durdur
  void stopForegroundUpdates() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }
  
  /// Güncelleme işlemini yap
  Future<void> _performRefresh() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      debugPrint('BackgroundService: Performing refresh...');

      // Son güncelleme zamanını kontrol et
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshMs = prefs.getInt(_lastRefreshKey) ?? 0;
      final lastRefresh = DateTime.fromMillisecondsSinceEpoch(lastRefreshMs);

      // Minimum interval kontrolü
      if (DateTime.now().difference(lastRefresh) < _minRefreshInterval) {
        debugPrint('BackgroundService: Skipping - too soon since last refresh');
        return;
      }

      // Widget verilerini güncelle
      await _updateWidgets();

      // Bildirimleri kontrol et
      await _checkNotifications();

      // Hatırlatıcı bildirimlerini yeniden zamanla (gerekirse)
      await _checkAndRescheduleNotifications();

      // Insight bildirimlerini kontrol et ve yeniden zamanla (gerekirse)
      await _checkInsightNotifications();

      // Son güncelleme zamanını kaydet
      await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('BackgroundService: Refresh completed');
    } catch (e) {
      debugPrint('BackgroundService: Error during refresh: $e');
    } finally {
      _isRunning = false;
    }
  }
  
  /// Widget verilerini güncelle
  Future<void> _updateWidgets() async {
    try {
      await WidgetService.instance.updateWidgets();
    } catch (e) {
      debugPrint('BackgroundService: Widget update error: $e');
    }
  }
  
  /// Bildirimleri kontrol et
  Future<void> _checkNotifications() async {
    try {
      // Zamanlanmış bildirimleri kontrol et
      final pendingNotifications = await NotificationService.instance.getPendingNotifications();
      debugPrint('BackgroundService: ${pendingNotifications.length} pending notifications');

      // Günlük hatırlatıcıların tamamlanma durumunu kontrol et ve gerekirse sıfırla
      await _resetDailyRemindersIfNeeded();
    } catch (e) {
      debugPrint('BackgroundService: Notification check error: $e');
    }
  }

  /// Günlük hatırlatıcıların tamamlanma durumunu sıfırla (eğer farklı günde tamamlanmışsa)
  /// Bu metod, günlük hatırlatıcıları her gün sıfırlar böylece kullanıcı tekrar tamamlayabilir
  Future<void> _resetDailyRemindersIfNeeded() async {
    try {
      // NOT: Bu metod RemindersProvider'a bağımlılık yaratmamak için sadece log tutar
      // Gerçek sıfırlama işlemi, uygulama açıldığında loadReminders() içinde yapılır
      // veya RemindersProvider'da bir metod aracılığıyla yapılabilir

      debugPrint('BackgroundService: Daily reminder reset check completed');
    } catch (e) {
      debugPrint('BackgroundService: Error resetting daily reminders: $e');
    }
  }

  /// Hatırlatıcı bildirimlerini kontrol et ve gerekirse yeniden zamanla
  /// Aylık/yıllık hatırlatıcılar için 30 gün ilerisi zamanlandığından,
  /// kalan gün sayısı 7'den azsa yeni bildirimleri zamanla
  Future<void> _checkAndRescheduleNotifications() async {
    try {
      final db = DatabaseHelper.instance;
      final reminders = await db.getAllReminders();

      // Aylık, yıllık veya özel periyotlu hatırlatıcıları filtrele
      final nonNativeRepeatReminders = reminders.where((r) {
        return r.frequency != 'daily' &&
               r.frequency != 'weekly' &&
               r.isActive;
      }).toList();

      if (nonNativeRepeatReminders.isEmpty) {
        debugPrint('BackgroundService: No non-native repeat reminders to check');
        return;
      }

      // Pending notifications al
      final pending = await NotificationService.instance.getPendingNotifications();

      for (final reminder in nonNativeRepeatReminders) {
        // nextDate null ise skip et
        if (reminder.nextDate == null) continue;

        // Bu reminder'a ait pending notification sayısını kontrol et
        final reminderPending = pending.where((n) {
          // Base ID veya date-based ID kontrolü
          final baseId = reminder.id.hashCode.abs() % 2147483647;
          if (n.id == baseId) return true;

          // Payload kontrolü
          if (n.payload == reminder.id) return true;

          return false;
        }).length;

        // Eğer 7'den az pending notification varsa, yeniden zamanla
        if (reminderPending < 7) {
          debugPrint('BackgroundService: Rescheduling ${reminder.title} - only $reminderPending pending notifications');

          // Parse time string (HH:mm format)
          final timeParts = reminder.time.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);

          await NotificationService.instance.scheduleRepeatingReminder(
            reminderId: reminder.id,
            title: reminder.title,
            body: reminder.notes ?? '',
            nextOccurrence: reminder.nextDate!,
            hour: hour,
            minute: minute,
            frequency: reminder.frequency,
            payload: NotificationService.instance.createPayload(
              reminderId: reminder.id,
              catId: reminder.petId,
              type: reminder.type,
            ),
          );
        }
      }

      debugPrint('BackgroundService: Notification rescheduling check completed');
    } catch (e) {
      debugPrint('BackgroundService: Error checking/rescheduling notifications: $e');
    }
  }

  /// Insight bildirimlerini kontrol et ve gerekirse yeniden zamanla
  Future<void> _checkInsightNotifications() async {
    try {
      // Pending notifications içinde insight notification var mı kontrol et
      final pendingNotifications = await NotificationService.instance.getPendingNotifications();

      // Seasonal insight notification ID'si: _baseNotificationId + 999 (10999)
      final hasSeasonalInsight = pendingNotifications.any((n) => n.id == 10999);

      if (!hasSeasonalInsight) {
        debugPrint('BackgroundService: Seasonal insight notification not found, needs rescheduling');
        // NOT: Gerçek yeniden zamanlama InsightsNotificationService.scheduleWeeklySeasonalInsight
        // aracılığıyla yapılmalı, ancak bu metod Cat listesi gerektirir
        // Bu yüzden sadece log tutuyoruz, uygulama açıldığında yeniden zamanlanacak
      }

      debugPrint('BackgroundService: Insight notification check completed');
    } catch (e) {
      debugPrint('BackgroundService: Error checking insight notifications: $e');
    }
  }
  
  /// Manuel güncelleme tetikle
  Future<void> forceRefresh() async {
    debugPrint('BackgroundService: Force refresh triggered');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRefreshKey); // Last refresh'i sıfırla

    await _performRefresh();
  }

  /// Schedule insights notifications (called from providers)
  Future<void> scheduleInsightsNotifications({
    required dynamic cats,
    required dynamic reminders,
    required dynamic weightRecords,
    required Set<String> completedDates,
  }) async {
    try {
      debugPrint('BackgroundService: Scheduling insights notifications...');

      await InsightsNotificationService.instance.scheduleDailyInsightNotification(
        cats: cats,
        reminders: reminders,
        weightRecords: weightRecords,
        completedDates: completedDates,
      );

      // Also schedule weekly seasonal insights
      await InsightsNotificationService.instance.scheduleWeeklySeasonalInsight(cats);

      debugPrint('BackgroundService: Insights notifications scheduled');
    } catch (e) {
      debugPrint('BackgroundService: Error scheduling insights: $e');
    }
  }
  
  /// Son güncelleme zamanını al
  Future<DateTime?> getLastRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefreshMs = prefs.getInt(_lastRefreshKey);
    
    if (lastRefreshMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastRefreshMs);
  }
  
  /// Servisi temizle
  void dispose() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    debugPrint('BackgroundService: Disposed');
  }
}

/// Background task callback (iOS Background App Refresh)
/// 
/// Bu fonksiyon iOS tarafından arka planda çağrılır.
/// Info.plist'te UIBackgroundModes ayarlanmalı.
@pragma('vm:entry-point')
void backgroundFetchCallback() async {
  debugPrint('BackgroundService: Background fetch callback triggered');
  
  try {
    // Widget'ları güncelle
    await WidgetService.instance.updateWidgets();
  } catch (e) {
    debugPrint('BackgroundService: Background fetch error: $e');
  }
}

/// App Lifecycle Yönetimi
/// 
/// Uygulama durumu değiştiğinde çağrılır.
class AppLifecycleService {
  static final AppLifecycleService instance = AppLifecycleService._init();
  
  AppLifecycleService._init();
  
  bool _isInForeground = true;
  DateTime? _lastBackgroundTime;
  
  /// Uygulama ön plana geldiğinde
  Future<void> onResumed() async {
    debugPrint('AppLifecycleService: App resumed');
    _isInForeground = true;
    
    // Eğer uzun süre arka planda kaldıysa güncelle
    if (_lastBackgroundTime != null) {
      final backgroundDuration = DateTime.now().difference(_lastBackgroundTime!);
      
      if (backgroundDuration.inMinutes > 5) {
        debugPrint('AppLifecycleService: App was in background for ${backgroundDuration.inMinutes} minutes, refreshing...');
        await BackgroundService.instance.forceRefresh();
      }
    }
    
    // Foreground timer'ı başlat
    BackgroundService.instance.startForegroundUpdates();
  }
  
  /// Uygulama arka plana gittiğinde
  void onPaused() {
    debugPrint('AppLifecycleService: App paused');
    _isInForeground = false;
    _lastBackgroundTime = DateTime.now();
    
    // Foreground timer'ı durdur
    BackgroundService.instance.stopForegroundUpdates();
  }
  
  /// Uygulama kapatılmadan önce
  Future<void> onDetached() async {
    debugPrint('AppLifecycleService: App detached');
    BackgroundService.instance.dispose();
  }
  
  bool get isInForeground => _isInForeground;
}


