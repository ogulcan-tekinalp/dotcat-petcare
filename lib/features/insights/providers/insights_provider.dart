import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/insights_notification_service.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/dog.dart';
import '../../../data/models/reminder.dart';
import '../../../data/models/weight_record.dart';
import '../../cats/providers/cats_provider.dart';
import '../../dogs/providers/dogs_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../weight/providers/weight_provider.dart';

/// All insights provider (unfiltered)
final allInsightsProvider = FutureProvider<List<Insight>>((ref) async {
  final cats = ref.watch(catsProvider);
  final dogs = ref.watch(dogsProvider);
  final reminders = ref.watch(remindersProvider);
  final completionsState = ref.watch(completionsProvider);
  final weights = ref.watch(weightProvider);

  return InsightsService.instance.generateInsights(
    cats: cats,
    dogs: dogs,
    reminders: reminders,
    weightRecords: weights,
    completedDates: completionsState.completedDates,
  );
});

/// Filtered insights provider (dismissed ones removed, insights shown every 2 days)
final insightsProvider = FutureProvider<List<Insight>>((ref) async {
  final allInsights = await ref.watch(allInsightsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final today = now.toIso8601String().split('T')[0];

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
    await prefs.setStringList('insights_reactivated', insightsToReactivate);
  }

  // Filter out dismissed insights (but include reactivated ones)
  final currentDismissed = dismissedMap.keys.toSet();
  final activeInsights = allInsights
      .where((i) => !currentDismissed.contains(i.id) || insightsToReactivate.contains(i.id))
      .toList();

  // === 2 GÜNDE BİR ÖNERİ GÖSTERİM SİSTEMİ ===
  // Son gösterim tarihini kontrol et
  final lastShownDateStr = prefs.getString('insights_last_shown_date');
  final shownInsights = prefs.getStringList('insights_shown_history') ?? [];
  final lastInsightIndex = prefs.getInt('insights_last_index') ?? 0;

  // High priority insights always shown (gecikmiş hatırlatıcılar gibi)
  final highPriorityInsights = activeInsights.where((i) => i.priority == InsightPriority.high).toList();

  // Normal priority insights - 2 günde bir göster
  final normalInsights = activeInsights.where((i) => i.priority != InsightPriority.high).toList();

  // Son gösterimden bu yana kaç gün geçmiş?
  int daysSinceLastShown = 999; // İlk çalışmada her zaman göster
  if (lastShownDateStr != null) {
    try {
      final lastShownDate = DateTime.parse(lastShownDateStr);
      daysSinceLastShown = now.difference(lastShownDate).inDays;
    } catch (_) {}
  }

  // Sonuç listesi
  final resultInsights = <Insight>[];

  // High priority önerileri her zaman ekle
  resultInsights.addAll(highPriorityInsights);

  // Normal önerileri 2 günde bir sırayla ekle
  if (daysSinceLastShown >= 2 && normalInsights.isNotEmpty) {
    // Sıradaki insight'ı al (round-robin)
    final nextIndex = lastInsightIndex % normalInsights.length;
    final nextInsight = normalInsights[nextIndex];

    // Daha önce gösterilmediyse veya 7 günden fazla olduysa ekle
    final wasShownRecently = shownInsights.any((entry) {
      final parts = entry.split(':');
      if (parts.length == 2 && parts[0] == nextInsight.id) {
        try {
          final shownDate = DateTime.parse(parts[1]);
          return now.difference(shownDate).inDays < 7;
        } catch (_) {}
      }
      return false;
    });

    if (!wasShownRecently) {
      resultInsights.add(nextInsight);

      // Geçmişe ekle
      final newHistory = List<String>.from(shownInsights);
      newHistory.add('${nextInsight.id}:$today');
      // Son 30 girişi tut
      if (newHistory.length > 30) {
        newHistory.removeRange(0, newHistory.length - 30);
      }

      await prefs.setStringList('insights_shown_history', newHistory);
      await prefs.setInt('insights_last_index', nextIndex + 1);
      await prefs.setString('insights_last_shown_date', today);

      // Yeni öneri için bildirim flag'i set et
      await prefs.setBool('insights_has_new', true);
    }
  }

  return resultInsights;
});

/// High priority insights count (for badge) - yeni öneri olduğunda da badge göster
final highPriorityInsightsCountProvider = FutureProvider<int>((ref) async {
  final allInsights = await ref.watch(allInsightsProvider.future);
  final prefs = await SharedPreferences.getInstance();

  // Get dismissed insights
  final dismissedList = prefs.getStringList('insights_dismissed') ?? [];

  // Yeni öneri var mı?
  final hasNewInsight = prefs.getBool('insights_has_new') ?? false;

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

  // Yeni öneri varsa en az 1 göster
  if (hasNewInsight && count == 0) {
    count = 1;
  }

  return count;
});

/// Yeni öneri görüldü olarak işaretle (insights ekranına girildiğinde çağrılır)
Future<void> markInsightsAsSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('insights_has_new', false);
}

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
