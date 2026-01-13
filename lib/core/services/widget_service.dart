import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';

/// Widget türleri
enum WidgetType {
  todayTasks,     // Bugünkü görevler
  upcomingVaccine, // Yaklaşan aşılar
  catStatus,      // Kedi durumu
  quickActions,   // Hızlı aksiyonlar
}

/// Home Screen Widget Servisi
/// 
/// iOS WidgetKit ve Android Home Screen Widget desteği
class WidgetService {
  static final WidgetService instance = WidgetService._init();
  
  // iOS App Group ID (Info.plist ve widget'ta tanımlanmalı)
  static const String _appGroupId = 'group.com.petcare.dotcat';
  
  // iOS Widget names
  static const String _iOSWidgetName = 'DotCatWidget';
  
  WidgetService._init();
  
  /// Initialize widget service
  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      debugPrint('WidgetService: Initialized with app group: $_appGroupId');
    } catch (e) {
      debugPrint('WidgetService: Init error: $e');
    }
  }
  
  /// Bugünkü görevleri widget'a gönder
  Future<void> updateTodayTasks({
    required List<Reminder> reminders,
    required Set<String> completedKeys,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateStr = today.toIso8601String().split('T')[0];
      
      // Bugün için aktif görevleri filtrele
      final todayTasks = reminders.where((r) {
        if (!r.isActive) return false;
        if (r.nextDate == null) return false;
        
        final reminderDate = DateTime(
          r.nextDate!.year,
          r.nextDate!.month,
          r.nextDate!.day,
        );
        return reminderDate.isAtSameMomentAs(today) || reminderDate.isBefore(today);
      }).map((r) {
        final key = '${r.id}_$dateStr';
        return {
          'id': r.id,
          'title': r.title,
          'type': r.type,
          'catId': r.catId,
          'time': r.time,
          'isCompleted': completedKeys.contains(key),
        };
      }).toList();
      
      // Widget'a veri gönder (Swift kodundaki key'lerle uyumlu)
      await HomeWidget.saveWidgetData<String>('widget_tasks', jsonEncode(todayTasks));
      await HomeWidget.saveWidgetData<int>('widget_pending_count', todayTasks.where((t) => t['isCompleted'] != true).length);
      await HomeWidget.saveWidgetData<int>('widget_completed_count', todayTasks.where((t) => t['isCompleted'] == true).length);
      await HomeWidget.saveWidgetData<String>('widget_last_update', now.toIso8601String());
      
      // Widget'ı güncelle
      await _updateWidgets();
      
      debugPrint('WidgetService: Updated today tasks - ${todayTasks.length} tasks');
    } catch (e) {
      debugPrint('WidgetService: Error updating today tasks: $e');
    }
  }
  
  /// Yaklaşan aşıları widget'a gönder
  Future<void> updateUpcomingVaccines({
    required List<Reminder> reminders,
    required List<Cat> cats,
  }) async {
    try {
      final now = DateTime.now();
      
      // Gelecek 30 gündeki aşıları filtrele
      final vaccines = reminders.where((r) {
        if (!r.isActive || r.type != 'vaccine') return false;
        if (r.nextDate == null) return false;
        
        final daysUntil = r.nextDate!.difference(now).inDays;
        return daysUntil >= 0 && daysUntil <= 30;
      }).map((r) {
        final cat = cats.firstWhere((c) => c.id == r.catId, orElse: () => cats.first);
        final daysUntil = r.nextDate!.difference(now).inDays;
        return {
          'id': r.id,
          'title': r.title,
          'catName': cat.name,
          'catId': r.catId,
          'daysUntil': daysUntil,
          'dateStr': '${r.nextDate!.day}/${r.nextDate!.month}',
        };
      }).toList();
      
      vaccines.sort((a, b) => (a['daysUntil'] as int).compareTo(b['daysUntil'] as int));
      
      await HomeWidget.saveWidgetData<String>('upcomingVaccines', jsonEncode(vaccines.take(5).toList()));
      await _updateWidgets();
      
      debugPrint('WidgetService: Updated upcoming vaccines - ${vaccines.length} vaccines');
    } catch (e) {
      debugPrint('WidgetService: Error updating vaccines: $e');
    }
  }
  
  /// Kedi durumunu widget'a gönder
  Future<void> updateCatStatus({
    required Cat cat,
    required List<Reminder> catReminders,
    required Set<String> completedKeys,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = now.toIso8601String().split('T')[0];
      
      // Bugünkü tamamlanmamış görev sayısı
      final pendingToday = catReminders.where((r) {
        if (!r.isActive) return false;
        final key = '${r.id}_$dateStr';
        return !completedKeys.contains(key);
      }).length;
      
      // En yakın görev
      Reminder? nextReminder;
      for (final r in catReminders.where((r) => r.isActive && r.nextDate != null)) {
        if (nextReminder == null || r.nextDate!.isBefore(nextReminder.nextDate!)) {
          nextReminder = r;
        }
      }
      
      await HomeWidget.saveWidgetData<String>('catName', cat.name);
      await HomeWidget.saveWidgetData<String>('catId', cat.id);
      await HomeWidget.saveWidgetData<int>('catPendingTasks', pendingToday);
      await HomeWidget.saveWidgetData<String>('catAge', cat.ageText);
      
      if (nextReminder != null) {
        await HomeWidget.saveWidgetData<String>('nextTask', nextReminder.title);
        await HomeWidget.saveWidgetData<String>('nextTaskTime', nextReminder.time);
      }
      
      await _updateWidgets();
      
      debugPrint('WidgetService: Updated cat status for ${cat.name}');
    } catch (e) {
      debugPrint('WidgetService: Error updating cat status: $e');
    }
  }
  
  /// Tüm widget'ları güncelle (public method - BackgroundService tarafından kullanılıyor)
  Future<void> updateWidgets() async {
    try {
      // iOS
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: 'DotCatWidgetProvider',
      );
    } catch (e) {
      debugPrint('WidgetService: Error updating widgets: $e');
    }
  }

  /// Internal use için alias
  Future<void> _updateWidgets() => updateWidgets();
  
  /// Widget'tan gelen URL'yi işle (deep link)
  Future<Uri?> getInitialUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('WidgetService: Error getting initial URI: $e');
      return null;
    }
  }
  
  /// Widget tıklamalarını dinle
  void listenToWidgetClicks(Function(Uri?) callback) {
    HomeWidget.widgetClicked.listen(callback);
  }
  
  /// Widget'ı silme durumunda temizlik
  Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>('todayTasks', '[]');
      await HomeWidget.saveWidgetData<String>('upcomingVaccines', '[]');
      await HomeWidget.saveWidgetData<int>('pendingCount', 0);
      await HomeWidget.saveWidgetData<int>('completedCount', 0);
      await _updateWidgets();
    } catch (e) {
      debugPrint('WidgetService: Error clearing data: $e');
    }
  }
}

