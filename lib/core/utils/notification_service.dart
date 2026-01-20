import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  /// Generate a unique notification ID from reminder ID and optional date
  /// Uses a more robust hashing to minimize collision risk
  /// This ensures each reminder instance gets a unique notification ID
  int generateNotificationId(String reminderId, {DateTime? date}) {
    // Use a custom hash function to minimize collisions
    // Based on djb2 hash algorithm which has better distribution than String.hashCode
    int hash = 5381;
    final input = date != null
        ? '$reminderId-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}'
        : reminderId;

    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF; // Keep positive and within 32-bit range
    }

    // Ensure the result is within valid notification ID range (positive int)
    return hash % 2147483647;
  }

  /// Create a rich payload for notification navigation
  /// Contains all info needed to navigate to the correct screen
  String createPayload({
    required String reminderId,
    String? catId,
    String? type,
    DateTime? date,
  }) {
    return jsonEncode({
      'reminderId': reminderId,
      if (catId != null) 'catId': catId,
      if (type != null) 'type': type,
      if (date != null) 'date': date.toIso8601String(),
    });
  }

  /// Parse notification payload
  Map<String, dynamic>? parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      // Try JSON first
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      // Fallback: assume it's just the reminder ID
      return {'reminderId': payload};
    }
  }

  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('NotificationService: Already initialized');
      return;
    }
    
    tz_data.initializeTimeZones();
    // Kullanıcının sistem timezone'unu kullan
    try {
      // Try to detect local timezone
      final now = DateTime.now();
      final localOffset = now.timeZoneOffset;
      
      // Find matching timezone
      bool found = false;
      for (final location in tz.timeZoneDatabase.locations.values) {
        try {
          final tzNow = tz.TZDateTime.now(location);
          if (tzNow.timeZoneOffset == localOffset) {
            tz.setLocalLocation(location);
            found = true;
            debugPrint('NotificationService: Using timezone: ${location.name}');
            break;
          }
        } catch (_) {}
      }
      
      if (!found) {
        // Fallback: Istanbul timezone for Turkey
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        debugPrint('NotificationService: Fallback to Europe/Istanbul');
      }
    } catch (e) {
      // Ultimate fallback
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      debugPrint('NotificationService: Error detecting timezone, using Europe/Istanbul: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        debugPrint('NotificationService: Notification tapped: ${details.payload}');
      },
    );
    
    _isInitialized = initialized ?? false;
    debugPrint('NotificationService: Initialized: $initialized');

    // Android için bildirim kanallarını oluştur
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        'dotcat_reminders',
        'Hatirlaticilar',
        description: 'DOTCAT bildirimleri',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      
      await android.createNotificationChannel(const AndroidNotificationChannel(
        'dotcat_events',
        'Etkinlikler',
        description: 'DOTCAT onemli etkinlikler',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      
      await android.createNotificationChannel(const AndroidNotificationChannel(
        'dotcat_instant',
        'Anlik Bildirimler',
        description: 'DOTCAT anlik bildirimler',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      
      debugPrint('NotificationService: Android notification channels created');
    }

    // Request permissions
    final hasPermission = await requestPermission();
    debugPrint('NotificationService: Permission granted: $hasPermission');
  }

  Future<bool> requestPermission() async {
    final iOS = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null) {
      // İzin iste
      final settings = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings ?? false;
      debugPrint('NotificationService: iOS permission requested - granted: $granted');
      return granted;
    }
    
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Android 13+ için izin kontrolü
      final granted = await android.requestNotificationsPermission();
      debugPrint('NotificationService: Android permission requested - granted: $granted');
      return granted ?? false;
    }
    
    debugPrint('NotificationService: Platform not supported, assuming permission granted');
    return true;
  }

  /// Ses önizlemesi için kısa bildirim göster
  Future<void> previewSound(String soundType) async {
    await showNotification(
      id: 99999, // Önizleme için özel ID
      title: 'Ses Önizlemesi',
      body: soundType == 'cat_meow' ? 'Miyav!' : 'Bildirim sesi',
      soundType: soundType,
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String soundType = 'default',
  }) async {
    // İzin kontrolü
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: Permission not granted for showNotification');
      return;
    }
    
    try {
      // Ses dosyası belirleme
      String? soundName;
      if (soundType == 'cat_meow') {
        // iOS için custom sound (assets'e eklenmeli)
        soundName = 'cat_meow.wav';
      }
      
      // Android için kanal oluştur (eğer yoksa)
      final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(const AndroidNotificationChannel(
          'dotcat_instant',
          'Anlik Bildirimler',
          description: 'DOTCAT anlik bildirimler',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ));
      }
      
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'dotcat_instant',
            'Anlik Bildirimler',
            channelDescription: 'DOTCAT anlik bildirimler',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: soundName, // iOS için sound dosyası
          ),
        ),
      );
      debugPrint('NotificationService: Notification shown successfully - id: $id');
    } catch (e) {
      debugPrint('NotificationService: Error showing notification: $e');
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    // İzin kontrolü
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: Permission not granted for daily reminder');
      return;
    }
    
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dotcat_reminders',
            'Hatirlaticilar',
            channelDescription: 'DOTCAT gunluk hatirlaticilari',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('NotificationService: Daily reminder scheduled successfully - id: $id');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling daily reminder: $e');
    }
  }

  Future<void> scheduleOneTimeReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
  }) async {
    // İzin kontrolü
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: Permission not granted for one-time reminder');
      return;
    }
    
    try {
      // Use consistent timezone pattern
      final scheduled = tz.TZDateTime(
        tz.local,
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      );
      final now = tz.TZDateTime.now(tz.local);

      if (scheduled.isBefore(now)) {
        debugPrint('NotificationService: Scheduled time is in the past, skipping - scheduled: $scheduled, now: $now');
        return;
      }

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'dotcat_events',
            'Etkinlikler',
            channelDescription: 'DOTCAT onemli etkinlikler',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('NotificationService: One-time reminder scheduled successfully - id: $id, dateTime: $scheduled');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling one-time reminder: $e');
    }
  }

  /// Schedule a repeating reminder based on frequency
  /// This handles daily, weekly, monthly, yearly etc.
  /// Daily and weekly use native repeating notifications (no app open needed)
  /// Monthly/yearly/custom intervals schedule multiple future occurrences
  Future<void> scheduleRepeatingReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime nextOccurrence,
    required int hour,
    required int minute,
    required String frequency,
    String? payload,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: Permission not granted for repeating reminder');
      return;
    }

    try {
      final now = DateTime.now();

      // Calculate the exact notification time
      final scheduledDateTime = DateTime(
        nextOccurrence.year,
        nextOccurrence.month,
        nextOccurrence.day,
        hour,
        minute,
      );

      if (scheduledDateTime.isBefore(now)) {
        debugPrint('NotificationService: Next occurrence is in the past, skipping - scheduled: $scheduledDateTime');
        return;
      }

      final scheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

      // GÜNLÜK HATIRLATICILAR: Native daily repeat kullan
      if (frequency == 'daily') {
        final notificationId = generateNotificationId(reminderId);

        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'dotcat_reminders',
              'Hatirlaticilar',
              channelDescription: 'DOTCAT gunluk hatirlaticilari',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              showWhen: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrar eder
          payload: payload,
        );
        debugPrint('NotificationService: Daily reminder scheduled with native repeat - id: $notificationId, time: ${scheduled.hour}:${scheduled.minute}');
      }
      // HAFTALIK HATIRLATICILAR: Native weekly repeat kullan
      else if (frequency == 'weekly') {
        final notificationId = generateNotificationId(reminderId);

        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'dotcat_reminders',
              'Hatirlaticilar',
              channelDescription: 'DOTCAT haftalik hatirlaticilari',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              showWhen: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Her hafta aynı gün ve saatte tekrar eder
          payload: payload,
        );
        debugPrint('NotificationService: Weekly reminder scheduled with native repeat - id: $notificationId, weekday: ${scheduled.weekday}, time: ${scheduled.hour}:${scheduled.minute}');
      }
      // AYLIK/YILLIK/ÖZEL: Gelecek 30 gün için bildirimler zamanla (hybrid approach)
      else {
        // Önce mevcut bildirimleri iptal et
        await cancelReminderNotifications(reminderId);

        // Gelecek oluşumları hesapla ve zamanla (30 gün ileri)
        final occurrences = _calculateFutureOccurrences(
          startDate: nextOccurrence,
          frequency: frequency,
          maxDays: 30, // 30 gün ileri (background service will reschedule)
        );

        debugPrint('NotificationService: Scheduling ${occurrences.length} occurrences for $frequency reminder');

        for (final occurrence in occurrences) {
          final occurrenceDateTime = DateTime(
            occurrence.year,
            occurrence.month,
            occurrence.day,
            hour,
            minute,
          );

          if (occurrenceDateTime.isAfter(now)) {
            final notificationId = generateNotificationId(reminderId, date: occurrence);

            await scheduleOneTimeReminder(
              id: notificationId,
              title: title,
              body: body,
              dateTime: occurrenceDateTime,
              payload: payload, // Pass payload for navigation
            );
          }
        }

        debugPrint('NotificationService: Scheduled ${occurrences.length} future occurrences for $frequency reminder');
      }
    } catch (e) {
      debugPrint('NotificationService: Error scheduling repeating reminder: $e');
    }
  }

  /// Gelecek oluşumları hesapla (aylık, yıllık, özel periyotlar için)
  List<DateTime> _calculateFutureOccurrences({
    required DateTime startDate,
    required String frequency,
    required int maxDays,
  }) {
    final occurrences = <DateTime>[];
    var current = startDate;
    final endDate = DateTime.now().add(Duration(days: maxDays));

    while (current.isBefore(endDate) && occurrences.length < 100) { // Maksimum 100 bildirim
      occurrences.add(current);

      // Sonraki oluşumu hesapla (month-end safe calculations)
      switch (frequency) {
        case 'monthly':
          // Safe date calculation for month-end dates
          int nextMonth = current.month + 1;
          int nextYear = current.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          // Clamp day to valid range for target month
          int maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
          int safeDay = current.day > maxDay ? maxDay : current.day;
          current = DateTime(nextYear, nextMonth, safeDay);
          break;
        case 'quarterly':
          // Safe date calculation for quarterly (3 months)
          int nextMonth = current.month + 3;
          int nextYear = current.year;
          while (nextMonth > 12) {
            nextMonth -= 12;
            nextYear++;
          }
          int maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
          int safeDay = current.day > maxDay ? maxDay : current.day;
          current = DateTime(nextYear, nextMonth, safeDay);
          break;
        case 'biannual':
          // Safe date calculation for biannual (6 months)
          int nextMonth = current.month + 6;
          int nextYear = current.year;
          while (nextMonth > 12) {
            nextMonth -= 12;
            nextYear++;
          }
          int maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
          int safeDay = current.day > maxDay ? maxDay : current.day;
          current = DateTime(nextYear, nextMonth, safeDay);
          break;
        case 'yearly':
          // Safe date calculation for yearly (handles Feb 29)
          int nextYear = current.year + 1;
          int maxDay = DateTime(nextYear, current.month + 1, 0).day;
          int safeDay = current.day > maxDay ? maxDay : current.day;
          current = DateTime(nextYear, current.month, safeDay);
          break;
        case '2days':
          current = current.add(const Duration(days: 2));
          break;
        case '3days':
          current = current.add(const Duration(days: 3));
          break;
        case '14days':
          current = current.add(const Duration(days: 14));
          break;
        default:
          return occurrences; // Bilinmeyen frekans
      }
    }

    return occurrences;
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all notifications for a specific reminder
  Future<void> cancelReminderNotifications(String reminderId) async {
    try {
      // Önce pending bildirimleri al
      final pending = await _notifications.pendingNotificationRequests();
      
      // Base notification ID
      final baseId = reminderId.hashCode.abs() % 2147483647;
      
      // Aynı anda iptal edilecek ID'leri topla
      final idsToCancel = <int>[baseId];
      
      // Pending listesinden bu reminder'a ait olanları bul
      // Reminder ID'si payload'da veya başlıkta olabilir
      for (final notification in pending) {
        if (notification.payload == reminderId) {
          idsToCancel.add(notification.id);
        }
      }
      
      // Ayrıca gelecek 90 gün için tarihli ID'leri de ekle (extended cancellation range)
      final now = DateTime.now();
      for (int i = 0; i < 90; i++) {
        final date = now.add(Duration(days: i));
        idsToCancel.add(generateNotificationId(reminderId, date: date));
      }
      
      // Tümünü paralel olarak iptal et
      await Future.wait(
        idsToCancel.toSet().map((id) => _notifications.cancel(id)),
      );
      
      debugPrint('NotificationService: Cancelled ${idsToCancel.length} notifications for reminder $reminderId');
    } catch (e) {
      debugPrint('NotificationService: Error cancelling notifications: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dotcat_instant',
          'Anlik Bildirimler',
          channelDescription: 'DOTCAT anlik bildirimler',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
    debugPrint('NotificationService: Cancelled notification with id: $id');
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    debugPrint('NotificationService: Cancelled all notifications');
  }

  /// Debug: Print all pending notifications
  Future<void> debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('NotificationService: Pending notifications count: ${pending.length}');
    for (final notification in pending) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
  }
}
