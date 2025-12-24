import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // Kullanıcının sistem timezone'unu kullan
    try {
      final localLocation = tz.local;
      tz.setLocalLocation(localLocation);
    } catch (e) {
      // Fallback: Istanbul timezone
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
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
        debugPrint('NotificationService: Scheduled time is in the past, skipping');
        return;
      }

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dotcat_events',
            'Etkinlikler',
            channelDescription: 'DOTCAT onemli etkinlikler',
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
      );
      debugPrint('NotificationService: One-time reminder scheduled successfully - id: $id');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling one-time reminder: $e');
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
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }
}
