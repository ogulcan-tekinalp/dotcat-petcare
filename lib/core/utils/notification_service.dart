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
  /// This ensures each reminder instance gets a unique notification ID
  int generateNotificationId(String reminderId, {DateTime? date}) {
    if (date != null) {
      // For recurring notifications, include date in the hash
      final dateStr = '${date.year}${date.month}${date.day}';
      return '$reminderId-$dateStr'.hashCode.abs() % 2147483647;
    }
    return reminderId.hashCode.abs() % 2147483647;
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
      final scheduled = tz.TZDateTime.from(dateTime, tz.local);
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
  /// This handles weekly, monthly, yearly etc. by scheduling the next occurrence
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
      // Calculate the exact notification time
      final scheduledDateTime = DateTime(
        nextOccurrence.year,
        nextOccurrence.month,
        nextOccurrence.day,
        hour,
        minute,
      );
      
      final now = DateTime.now();
      
      if (scheduledDateTime.isBefore(now)) {
        debugPrint('NotificationService: Next occurrence is in the past, skipping - scheduled: $scheduledDateTime');
        return;
      }

      final notificationId = generateNotificationId(reminderId, date: nextOccurrence);
      
      // For weekly reminders, we can use the built-in weekly repeat
      if (frequency == 'weekly') {
        final scheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'dotcat_reminders',
              'Hatirlaticilar',
              channelDescription: 'DOTCAT hatirlaticilari',
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
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
        debugPrint('NotificationService: Weekly reminder scheduled - id: $notificationId, dateTime: $scheduled');
      } else {
        // For other frequencies (monthly, yearly, custom), schedule a one-time notification
        // The app will reschedule the next one when this fires or when opened
        await scheduleOneTimeReminder(
          id: notificationId,
          title: title,
          body: body,
          dateTime: scheduledDateTime,
          payload: payload,
        );
        debugPrint('NotificationService: Repeating reminder ($frequency) scheduled as one-time - id: $notificationId');
      }
    } catch (e) {
      debugPrint('NotificationService: Error scheduling repeating reminder: $e');
    }
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
      
      // Ayrıca gelecek 30 gün için tarihli ID'leri de ekle (daha verimli)
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
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
