import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/models/reminder.dart';

/// Live Activity türleri
enum LiveActivityType {
  reminder,      // Aktif hatırlatıcı
  countdown,     // Geri sayım (aşı tarihi yaklaşıyor vs)
  dailyProgress, // Günlük ilerleme
}

/// Live Activity verisi
class LiveActivityData {
  final String id;
  final LiveActivityType type;
  final String title;
  final String? subtitle;
  final DateTime? targetTime;
  final int? progress;
  final int? total;
  final Map<String, dynamic>? extra;

  LiveActivityData({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.targetTime,
    this.progress,
    this.total,
    this.extra,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'targetTime': targetTime?.toIso8601String(),
      'progress': progress,
      'total': total,
      'extra': extra,
    };
  }
}

/// iOS Live Activity ve Dynamic Island Servisi
/// 
/// Live Activity'ler şu durumlarda kullanılabilir:
/// - Yaklaşan önemli hatırlatıcı (ilaç saati, aşı randevusu)
/// - Günlük bakım ilerlemesi
/// - Geri sayım (önemli tarihler)
/// 
/// NOT: Bu özellik iOS 16.1+ gerektirir ve
/// Xcode'da Widget Extension oluşturulmalıdır.
class LiveActivityService {
  static final LiveActivityService instance = LiveActivityService._init();
  
  static const _channel = MethodChannel('com.petcare.dotcat/live_activity');
  
  String? _currentActivityId;
  
  LiveActivityService._init();
  
  /// Platformun Live Activity destekleyip desteklemediğini kontrol et
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('LiveActivityService: isSupported error: $e');
      return false;
    }
  }
  
  /// Live Activity başlat
  Future<String?> startActivity(LiveActivityData data) async {
    if (!Platform.isIOS) return null;
    
    try {
      final activityId = await _channel.invokeMethod<String>(
        'startActivity',
        data.toMap(),
      );
      
      _currentActivityId = activityId;
      debugPrint('LiveActivityService: Started activity: $activityId');
      return activityId;
    } catch (e) {
      debugPrint('LiveActivityService: startActivity error: $e');
      return null;
    }
  }
  
  /// Live Activity güncelle
  Future<void> updateActivity(String activityId, LiveActivityData data) async {
    if (!Platform.isIOS) return;
    
    try {
      await _channel.invokeMethod(
        'updateActivity',
        {'activityId': activityId, ...data.toMap()},
      );
      debugPrint('LiveActivityService: Updated activity: $activityId');
    } catch (e) {
      debugPrint('LiveActivityService: updateActivity error: $e');
    }
  }
  
  /// Live Activity sonlandır
  Future<void> endActivity(String activityId) async {
    if (!Platform.isIOS) return;
    
    try {
      await _channel.invokeMethod(
        'endActivity',
        {'activityId': activityId},
      );
      
      if (_currentActivityId == activityId) {
        _currentActivityId = null;
      }
      debugPrint('LiveActivityService: Ended activity: $activityId');
    } catch (e) {
      debugPrint('LiveActivityService: endActivity error: $e');
    }
  }
  
  /// Tüm Live Activity'leri sonlandır
  Future<void> endAllActivities() async {
    if (!Platform.isIOS) return;
    
    try {
      await _channel.invokeMethod('endAllActivities');
      _currentActivityId = null;
      debugPrint('LiveActivityService: Ended all activities');
    } catch (e) {
      debugPrint('LiveActivityService: endAllActivities error: $e');
    }
  }
  
  /// Hatırlatıcı için Live Activity başlat
  Future<String?> startReminderActivity(Reminder reminder) async {
    if (reminder.nextDate == null) return null;
    
    final data = LiveActivityData(
      id: reminder.id,
      type: LiveActivityType.reminder,
      title: reminder.title,
      subtitle: reminder.notes ?? reminder.type, // notes varsa kullan, yoksa type göster
      targetTime: reminder.nextDate,
      extra: {
        'reminderId': reminder.id,
        'catId': reminder.catId,
        'type': reminder.type,
      },
    );
    
    return await startActivity(data);
  }
  
  /// Günlük ilerleme Live Activity
  Future<String?> startDailyProgressActivity({
    required int completed,
    required int total,
  }) async {
    final data = LiveActivityData(
      id: 'daily_progress',
      type: LiveActivityType.dailyProgress,
      title: 'Günlük Bakım',
      subtitle: '$completed / $total görev tamamlandı',
      progress: completed,
      total: total,
    );
    
    return await startActivity(data);
  }
  
  /// Geri sayım Live Activity (önemli tarih için)
  Future<String?> startCountdownActivity({
    required String id,
    required String title,
    required DateTime targetDate,
  }) async {
    final data = LiveActivityData(
      id: id,
      type: LiveActivityType.countdown,
      title: title,
      targetTime: targetDate,
    );
    
    return await startActivity(data);
  }
}

