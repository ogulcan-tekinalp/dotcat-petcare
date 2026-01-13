import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/insights_notification_service.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/reminder.dart';
import '../../../data/models/weight_record.dart';
import '../../cats/providers/cats_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../weight/providers/weight_provider.dart';

/// All insights provider (unfiltered)
final allInsightsProvider = FutureProvider<List<Insight>>((ref) async {
  final cats = ref.watch(catsProvider);
  final reminders = ref.watch(remindersProvider);
  final completionsState = ref.watch(completionsProvider);
  final weights = ref.watch(weightProvider);

  return InsightsService.instance.generateInsights(
    cats: cats,
    reminders: reminders,
    weightRecords: weights,
    completedDates: completionsState.completedDates,
  );
});

/// Filtered insights provider (dismisssed ones removed, daily limit applied)
final insightsProvider = FutureProvider<List<Insight>>((ref) async {
  final allInsights = await ref.watch(allInsightsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();

  // Get dismissed insights with timestamps (format: "insightId:timestamp")
  final dismissedList = prefs.getStringList('insights_dismissed_v2') ?? [];
  final dismissedMap = <String, DateTime>{};

  for (final entry in dismissedList) {
    final parts = entry.split(':');
    if (parts.length == 2) {
      dismissedMap[parts[0]] = DateTime.parse(parts[1]);
    }
  }

  // Check for dismissed insights that should be re-shown after 1 month
  final reminders = ref.watch(remindersProvider);
  final insightsToReactivate = <String>[];

  dismissedMap.forEach((insightId, dismissedDate) {
    final daysSinceDismissal = now.difference(dismissedDate).inDays;

    // If dismissed more than 30 days ago
    if (daysSinceDismissal >= 30) {
      // Check if the insight was suggesting a reminder
      final matchingInsight = allInsights.firstWhere(
        (i) => i.id == insightId,
        orElse: () => allInsights.first, // Dummy fallback
      );

      // Check if reminder was created based on insight's actionData
      bool reminderCreated = false;
      if (matchingInsight.actionRoute == '/reminder/add' &&
          matchingInsight.actionData != null) {
        final suggestedType = matchingInsight.actionData!['type'];
        final suggestedCatId = matchingInsight.actionData!['catId'];

        // Check if reminder exists for this cat and type
        reminderCreated = reminders.any((r) =>
          r.type == suggestedType &&
          (suggestedCatId == null || r.catId == suggestedCatId)
        );
      }

      // If reminder not created, re-show the insight
      if (!reminderCreated) {
        insightsToReactivate.add(insightId);
      }
    }
  });

  // Remove reactivated insights from dismissed list
  if (insightsToReactivate.isNotEmpty) {
    final updatedDismissedList = dismissedList
        .where((entry) => !insightsToReactivate.contains(entry.split(':')[0]))
        .toList();
    await prefs.setStringList('insights_dismissed_v2', updatedDismissedList);

    // Send notification for reactivated insights
    // Note: Notification sending will be handled by a background service
    await prefs.setStringList('insights_reactivated', insightsToReactivate);
  }

  // Get insights shown today
  final today = now.toIso8601String().split('T')[0];
  final lastShownDate = prefs.getString('insights_last_shown_date');
  final shownToday = lastShownDate == today
      ? (prefs.getStringList('insights_shown_today') ?? [])
      : <String>[];

  // Filter out dismissed insights (but include reactivated ones)
  final currentDismissed = dismissedMap.keys.toSet();
  final activeInsights = allInsights
      .where((i) => !currentDismissed.contains(i.id) || insightsToReactivate.contains(i.id))
      .toList();

  // If it's a new day, reset shown list and show max 2 insights
  if (lastShownDate != today) {
    final dailyInsights = activeInsights.take(2).toList();
    await prefs.setString('insights_last_shown_date', today);
    await prefs.setStringList('insights_shown_today', dailyInsights.map((i) => i.id).toList());
    return dailyInsights;
  }

  // Return insights shown today
  return activeInsights.where((i) => shownToday.contains(i.id)).toList();
});

/// High priority insights count (for badge) - counts ALL high priority insights, not just filtered ones
final highPriorityInsightsCountProvider = FutureProvider<int>((ref) async {
  final allInsights = await ref.watch(allInsightsProvider.future);
  final prefs = await SharedPreferences.getInstance();

  // Get dismissed insights
  final dismissedList = prefs.getStringList('insights_dismissed') ?? [];

  // Count high priority insights that are not dismissed
  int count = 0;
  for (final insight in allInsights) {
    if (insight.priority == InsightPriority.high && !dismissedList.contains(insight.id)) {
      // Also check if snoozed
      final snoozeUntilStr = prefs.getString('insight_snoozed_${insight.id}');
      if (snoozeUntilStr == null) {
        count++;
      } else {
        final snoozeUntil = DateTime.parse(snoozeUntilStr);
        if (DateTime.now().isAfter(snoozeUntil)) {
          count++;
        }
      }
    }
  }

  return count;
});

/// Insights actions provider
final insightsActionsProvider = Provider((ref) => InsightsActions(ref));

class InsightsActions {
  final Ref ref;
  InsightsActions(this.ref);

  /// Dismiss an insight (will be re-shown after 1 month if reminder not created)
  Future<void> dismissInsight(String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('insights_dismissed_v2') ?? [];
    final now = DateTime.now().toIso8601String();
    final entry = '$insightId:$now';

    // Remove any existing entry for this insight
    dismissed.removeWhere((e) => e.startsWith('$insightId:'));

    // Add new entry with current timestamp
    dismissed.add(entry);
    await prefs.setStringList('insights_dismissed_v2', dismissed);

    // Also add to simple dismissed list for badge counting
    final simpleDismissed = prefs.getStringList('insights_dismissed') ?? [];
    if (!simpleDismissed.contains(insightId)) {
      simpleDismissed.add(insightId);
      await prefs.setStringList('insights_dismissed', simpleDismissed);
    }

    // Refresh insights and badge count
    ref.invalidate(insightsProvider);
    ref.invalidate(highPriorityInsightsCountProvider);
  }

  /// Snooze an insight (hide for today)
  Future<void> snoozeInsight(String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final shownToday = prefs.getStringList('insights_shown_today') ?? [];
    shownToday.remove(insightId);
    await prefs.setStringList('insights_shown_today', shownToday);
    // Refresh insights
    ref.invalidate(insightsProvider);
  }

  /// Check for reactivated insights and send notifications
  Future<void> checkAndNotifyReactivatedInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reactivatedIds = prefs.getStringList('insights_reactivated') ?? [];

      if (reactivatedIds.isEmpty) return;

      // Get all insights to find the reactivated ones
      final allInsights = await ref.read(allInsightsProvider.future);

      for (final insightId in reactivatedIds) {
        // Find the insight
        final insight = allInsights.firstWhere(
          (i) => i.id == insightId,
          orElse: () => allInsights.first, // Dummy fallback
        );

        if (insight.id == insightId) {
          // Send notification
          await InsightsNotificationService.instance.sendReactivatedInsightNotification(insight);
        }
      }

      // Clear the reactivated list after notifications are sent
      await prefs.remove('insights_reactivated');
    } catch (e) {
      // Silently fail
    }
  }
}
