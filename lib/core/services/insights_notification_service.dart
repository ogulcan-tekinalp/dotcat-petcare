import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/notification_service.dart';
import '../utils/localization.dart';
import 'insights_service.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';

/// Service for scheduling and managing insight notifications
/// Sends smart recommendations as notifications at user's preferred time
///
/// INSIGHT DELIVERY SYSTEM:
/// - Insights are generated but NOT shown until delivered via notification
/// - User sees only delivered insights in the Insights screen
/// - Snooze: hide for X days, then re-notify
/// - Dismiss: permanently hide (re-shows after 30 days if action not taken)
class InsightsNotificationService {
  static final InsightsNotificationService instance = InsightsNotificationService._init();

  InsightsNotificationService._init();

  // Notification channel for insights
  static const String _insightChannelId = 'insights_channel';
  static String get _insightChannelName => AppLocalizations.get('notification_channel_health_insights');
  static String get _insightChannelDescription => AppLocalizations.get('notification_channel_health_insights_desc');

  // Base notification ID for insights (to avoid conflicts with reminders)
  static const int _baseNotificationId = 10000;

  // Preference keys
  static const String _prefKeyLastNotificationDate = 'insights_last_notification_date';
  static const String _prefKeyDismissedInsights = 'insights_dismissed';
  static const String _prefKeyDeliveredInsights = 'insights_delivered'; // NEW: Track delivered insights

  /// Schedule insight notification (every 2 days) based on user preference
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

      // Check if we already sent a notification within 2 days
      final lastNotificationDateStr = prefs.getString(_prefKeyLastNotificationDate);
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];

      if (lastNotificationDateStr != null) {
        try {
          final lastNotificationDate = DateTime.parse(lastNotificationDateStr);
          final daysSinceLastNotification = now.difference(lastNotificationDate).inDays;

          // 2 günde bir bildirim gönder
          if (daysSinceLastNotification < 2) {
            debugPrint('InsightsNotificationService: Last notification was $daysSinceLastNotification days ago, waiting for 2 days');
            return;
          }
        } catch (_) {
          // Parse hatası, devam et
        }
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
      final tzNow = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(tzNow)) {
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

      // Mark insight as delivered (will be shown in Insights screen)
      await markInsightAsDelivered(topInsight.id);

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

  /// Mark an insight as delivered (shown via notification)
  /// Only delivered insights are visible in Insights screen
  Future<void> markInsightAsDelivered(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delivered = prefs.getStringList(_prefKeyDeliveredInsights) ?? [];
      final now = DateTime.now().toIso8601String();
      final entry = '$insightId:$now';

      // Remove old entry if exists
      delivered.removeWhere((e) => e.startsWith('$insightId:'));
      delivered.add(entry);

      await prefs.setStringList(_prefKeyDeliveredInsights, delivered);
      debugPrint('InsightsNotificationService: Marked insight as delivered: $insightId');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error marking delivered: $e');
    }
  }

  /// Check if an insight has been delivered via notification
  Future<bool> isInsightDelivered(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delivered = prefs.getStringList(_prefKeyDeliveredInsights) ?? [];
      return delivered.any((e) => e.startsWith('$insightId:'));
    } catch (e) {
      debugPrint('InsightsNotificationService: Error checking delivered: $e');
      return false;
    }
  }

  /// Get list of delivered insight IDs
  Future<Set<String>> getDeliveredInsightIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delivered = prefs.getStringList(_prefKeyDeliveredInsights) ?? [];
      return delivered.map((e) => e.split(':')[0]).toSet();
    } catch (e) {
      debugPrint('InsightsNotificationService: Error getting delivered ids: $e');
      return {};
    }
  }

  /// Clear delivered status when insight is dismissed or snoozed
  Future<void> clearDeliveredStatus(String insightId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delivered = prefs.getStringList(_prefKeyDeliveredInsights) ?? [];
      delivered.removeWhere((e) => e.startsWith('$insightId:'));
      await prefs.setStringList(_prefKeyDeliveredInsights, delivered);
      debugPrint('InsightsNotificationService: Cleared delivered status: $insightId');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error clearing delivered status: $e');
    }
  }

  /// Reset all insights state (clears delivered, dismissed, snoozed)
  /// Use this to start fresh
  Future<void> resetAllInsightsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyDeliveredInsights);
      await prefs.remove(_prefKeyDismissedInsights);
      await prefs.remove(_prefKeyLastNotificationDate);
      await prefs.remove('insights_shown_history');
      await prefs.remove('insights_last_index');
      await prefs.remove('insights_last_shown_date');
      await prefs.remove('insights_has_new');
      await prefs.remove('insights_dismissed_v2');

      // Clear all snoozed insights
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('insight_snoozed_')) {
          await prefs.remove(key);
        }
      }

      debugPrint('InsightsNotificationService: Reset all insights state');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error resetting state: $e');
    }
  }

  /// Schedule re-notification for snoozed insight
  Future<void> scheduleSnoozeNotification(Insight insight, {required int days}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationTime = prefs.getString('onboarding_notification_time') ?? '09:00';
      final timeParts = notificationTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + days,
        hour,
        minute,
      );

      await NotificationService.instance.scheduleOneTimeReminder(
        id: _baseNotificationId + 500 + insight.hashCode % 500,
        title: insight.title,
        body: insight.description,
        dateTime: scheduledDate.toLocal(),
        payload: 'insight_snooze:${insight.id}',
      );

      debugPrint('InsightsNotificationService: Scheduled snooze notification for ${insight.id} in $days days');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error scheduling snooze notification: $e');
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
        title: AppLocalizations.get('notification_insight_reminder_title').replaceAll('{title}', insight.title),
        body: AppLocalizations.get('notification_insight_reminder_body').replaceAll('{description}', insight.description),
      );

      debugPrint('InsightsNotificationService: Sent reactivated insight notification for ${insight.id}');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error sending reactivated insight notification: $e');
    }
  }

  /// Schedule weekly seasonal insights
  /// NOTE: This schedules a ONE-TIME notification for next Sunday
  /// The app should reschedule this after it fires (via background service or app open)
  Future<void> scheduleWeeklySeasonalInsight(List<Cat> cats) async {
    try {
      // Get seasonal insights
      final seasonalInsights = InsightsService.instance.generateSeasonalInsights(cats, null);

      if (seasonalInsights.isEmpty) {
        debugPrint('InsightsNotificationService: No seasonal insights available');
        return;
      }

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
      } else if (daysUntilSunday > 0) {
        scheduledDate = scheduledDate.add(Duration(days: daysUntilSunday));
      }

      // Pick a seasonal insight (rotate through them)
      final weekOfYear = _getWeekOfYear(now);
      final insightIndex = weekOfYear % seasonalInsights.length;
      final insight = seasonalInsights[insightIndex];

      // Cancel previous seasonal notification
      await NotificationService.instance.cancelReminder(_baseNotificationId + 999);

      // Schedule new one
      await NotificationService.instance.scheduleOneTimeReminder(
        id: _baseNotificationId + 999, // Special ID for seasonal
        title: '🌿 ${insight.title}',
        body: insight.description,
        dateTime: scheduledDate.toLocal(),
        payload: 'seasonal_insight:${insight.id}',
      );

      debugPrint('InsightsNotificationService: Scheduled weekly seasonal insight "${insight.title}" for $scheduledDate');
    } catch (e) {
      debugPrint('InsightsNotificationService: Error scheduling seasonal insight: $e');
    }
  }

  /// Get week number of the year
  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysSinceStart = date.difference(startOfYear).inDays;
    return (daysSinceStart / 7).floor() + 1;
  }
}
