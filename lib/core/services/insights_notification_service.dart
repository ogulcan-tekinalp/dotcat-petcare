import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/notification_service.dart';
import 'insights_service.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';

/// Service for scheduling and managing insight notifications
/// Sends smart recommendations as notifications at user's preferred time
class InsightsNotificationService {
  static final InsightsNotificationService instance = InsightsNotificationService._init();

  InsightsNotificationService._init();

  // Notification channel for insights
  static const String _insightChannelId = 'insights_channel';
  static const String _insightChannelName = 'Sağlık Önerileri';
  static const String _insightChannelDescription = 'Kedileriniz için akıllı sağlık önerileri';

  // Base notification ID for insights (to avoid conflicts with reminders)
  static const int _baseNotificationId = 10000;

  // Preference keys
  static const String _prefKeyLastNotificationDate = 'insights_last_notification_date';
  static const String _prefKeyDismissedInsights = 'insights_dismissed';

  /// Schedule daily insight notification based on user preference
  Future<void> scheduleDailyInsightNotification({
    required List<Cat> cats,
    required List<Reminder> reminders,
    required List<WeightRecord> weightRecords,
    required Set<String> completedDates,
  }) async {
    try {
      // Get user's preferred notification time
      final prefs = await SharedPreferences.getInstance();
      final notificationTime = prefs.getString('onboarding_notification_time') ?? '09:00';

      // Parse time (format: "HH:mm")
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Check if we already sent a notification today
      final lastNotificationDate = prefs.getString(_prefKeyLastNotificationDate);
      final today = DateTime.now().toIso8601String().split('T')[0];

      if (lastNotificationDate == today) {
        debugPrint('InsightsNotificationService: Already sent notification today');
        return;
      }

      // Generate insights
      final insights = await InsightsService.instance.generateInsights(
        cats: cats,
        reminders: reminders,
        weightRecords: weightRecords,
        completedDates: completedDates,
      );

      if (insights.isEmpty) {
        debugPrint('InsightsNotificationService: No insights to notify');
        return;
      }

      // Get dismissed insights
      final dismissedInsights = prefs.getStringList(_prefKeyDismissedInsights) ?? [];

      // Filter out dismissed insights and get high priority ones
      final notifiableInsights = insights
          .where((insight) => !dismissedInsights.contains(insight.id))
          .where((insight) => insight.priority == InsightPriority.high || insight.priority == InsightPriority.medium)
          .toList();

      if (notifiableInsights.isEmpty) {
        debugPrint('InsightsNotificationService: No non-dismissed insights');
        return;
      }

      // Pick the top priority insight
      final topInsight = notifiableInsights.first;

      // Schedule notification for the next occurrence of the preferred time
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Schedule the notification
      await NotificationService.instance.scheduleOneTimeReminder(
        id: _baseNotificationId + notifiableInsights.indexOf(topInsight),
        title: topInsight.title,
        body: topInsight.description,
        dateTime: scheduledDate.toLocal(),
        payload: 'insight:${topInsight.id}',
      );

      // Update last notification date
      await prefs.setString(_prefKeyLastNotificationDate, today);

      debugPrint('InsightsNotificationService: Scheduled notification for ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error scheduling notification: $e');
    }
  }

  /// Send an immediate insight notification (for urgent insights)
  Future<void> sendImmediateInsightNotification(Insight insight) async {
    try {
      await NotificationService.instance.showInstantNotification(
        id: _baseNotificationId + insight.hashCode,
        title: insight.title,
        body: insight.description,
      );

      debugPrint('InsightsNotificationService: Sent immediate notification for ${insight.id}');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error sending immediate notification: $e');
    }
  }

  /// Dismiss an insight (user doesn't want to see it again)
  Future<void> dismissInsight(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_prefKeyDismissedInsights) ?? [];

      if (!dismissed.contains(insightId)) {
        dismissed.add(insightId);
        await prefs.setStringList(_prefKeyDismissedInsights, dismissed);
        debugPrint('InsightsNotificationService: Dismissed insight: $insightId');
      }
    } catch (e) {
      debugPrint('InsightsNotificationService: Error dismissing insight: $e');
    }
  }

  /// Snooze an insight (remind again in X days)
  Future<void> snoozeInsight(String insightId, {int days = 3}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozeUntil = DateTime.now().add(Duration(days: days));
      await prefs.setString('insight_snoozed_$insightId', snoozeUntil.toIso8601String());

      debugPrint('InsightsNotificationService: Snoozed insight $insightId until $snoozeUntil');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error snoozing insight: $e');
    }
  }

  /// Check if an insight is dismissed
  Future<bool> isInsightDismissed(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_prefKeyDismissedInsights) ?? [];
      return dismissed.contains(insightId);
    } catch (e) {
      debugPrint('InsightsNotificationService: Error checking dismissed: $e');
      return false;
    }
  }

  /// Check if an insight is snoozed
  Future<bool> isInsightSnoozed(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozeUntilStr = prefs.getString('insight_snoozed_$insightId');

      if (snoozeUntilStr == null) return false;

      final snoozeUntil = DateTime.parse(snoozeUntilStr);
      final now = DateTime.now();

      if (now.isAfter(snoozeUntil)) {
        // Snooze period expired, clean up
        await prefs.remove('insight_snoozed_$insightId');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('InsightsNotificationService: Error checking snooze: $e');
      return false;
    }
  }

  /// Clear all dismissed insights (useful for testing or settings)
  Future<void> clearDismissedInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyDismissedInsights);
      debugPrint('InsightsNotificationService: Cleared all dismissed insights');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error clearing dismissed insights: $e');
    }
  }

  /// Reset notification scheduling (force re-schedule)
  Future<void> resetNotificationSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyLastNotificationDate);
      debugPrint('InsightsNotificationService: Reset notification schedule');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error resetting schedule: $e');
    }
  }

  /// Send notification for reactivated insights (after 1 month)
  Future<void> sendReactivatedInsightNotification(Insight insight) async {
    try {
      await NotificationService.instance.showInstantNotification(
        id: _baseNotificationId + insight.hashCode,
        title: '💡 Hatırlatma: ${insight.title}',
        body: '${insight.description}\n\nBu öneriyi 1 ay önce ertelemiştiniz. Hala ilgili hatırlatıcıyı oluşturmadınız.',
      );

      debugPrint('InsightsNotificationService: Sent reactivated insight notification for ${insight.id}');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error sending reactivated insight notification: $e');
    }
  }

  /// Schedule weekly seasonal insights
  Future<void> scheduleWeeklySeasonalInsight(List<Cat> cats) async {
    try {
      // Get seasonal insights
      final seasonalInsights = InsightsService.instance.generateSeasonalInsights(cats);

      if (seasonalInsights.isEmpty) return;

      // Schedule for Sunday at 10 AM
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        10, // 10 AM
        0,
      );

      // Find next Sunday
      final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
      if (daysUntilSunday == 0 && now.hour >= 10) {
        // If it's Sunday and past 10 AM, schedule for next Sunday
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      } else {
        scheduledDate = scheduledDate.add(Duration(days: daysUntilSunday));
      }

      // Pick a seasonal insight
      final insight = seasonalInsights.first;

      await NotificationService.instance.scheduleOneTimeReminder(
        id: _baseNotificationId + 999, // Special ID for seasonal
        title: '🌿 ${insight.title}',
        body: insight.description,
        dateTime: scheduledDate.toLocal(),
        payload: 'seasonal_insight:${insight.id}',
      );

      debugPrint('InsightsNotificationService: Scheduled weekly seasonal insight for $scheduledDate');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error scheduling seasonal insight: $e');
    }
  }
}
