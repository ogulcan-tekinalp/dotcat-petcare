import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_service.dart';
import 'widget_service.dart';
import 'insights_notification_service.dart';

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
    } catch (e) {
      debugPrint('BackgroundService: Notification check error: $e');
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


