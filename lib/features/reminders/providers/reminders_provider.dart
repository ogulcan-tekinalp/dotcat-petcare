import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/reminder.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/services/firestore_service.dart';

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) {
  return RemindersNotifier();
});

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier() : super([]) {
    loadReminders();
  }

  final _firestore = FirestoreService();
  final _uuid = const Uuid();

  Future<void> loadReminders() async {
    // Sadece cloud'dan yükle (kullanıcı giriş yapmışsa)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        final cloudReminders = await _firestore.getReminders();
        state = cloudReminders;
        
        // Reschedule all active reminders on app start
        for (final reminder in cloudReminders.where((r) => r.isActive && !r.isCompleted)) {
          await _scheduleNotificationForReminder(reminder);
        }
      } else {
        // Giriş yapılmamışsa boş liste
        state = [];
      }
    } catch (e) {
      debugPrint('RemindersProvider: Load error: $e');
      state = [];
    }
  }

  Future<void> loadRemindersForCat(String catId) async {
    // Bu metod artık state'i değiştirmiyor
    // Cat detail screen zaten ref.watch ile tüm reminder'ları alıp filtreliyor
    // State'i değiştirmek diğer ekranlardaki verileri siliyordu - bu bug düzeltildi
  }

  Future<void> _scheduleNotificationForReminder(Reminder reminder, {String? catName}) async {
    final timeParts = reminder.time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final name = catName ?? 'Kediniz';
    
    // Calculate next occurrence
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? nextDate = _getNextOccurrence(reminder, today);
    
    if (nextDate == null) return;
    
    final scheduledDateTime = DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
    
    // Only schedule if in the future
    if (scheduledDateTime.isAfter(now)) {
      if (reminder.frequency == 'daily') {
        // For daily reminders, use repeating notification
        await NotificationService.instance.scheduleDailyReminder(
          id: reminder.id.hashCode,
          title: '🐱 ${reminder.title}',
          body: '$name için ${reminder.title.toLowerCase()} zamanı!',
          hour: hour,
          minute: minute,
        );
      } else {
        // For other frequencies, schedule one-time and reschedule on completion
        await NotificationService.instance.scheduleOneTimeReminder(
          id: reminder.id.hashCode,
          title: '🐱 ${reminder.title}',
          body: '$name için ${reminder.title.toLowerCase()} zamanı!',
          dateTime: scheduledDateTime,
        );
      }
    }
  }
  
  DateTime? _getNextOccurrence(Reminder reminder, DateTime today) {
    final createdAt = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
    if (reminder.frequency == 'once') {
      return !createdAt.isBefore(today) ? createdAt : null;
    }
    DateTime current = createdAt;
    if (!current.isBefore(today)) return current;
    while (current.isBefore(today)) {
      final next = _calculateNextFromDate(current, reminder.frequency);
      if (next == null) return null;
      current = next;
    }
    return current;
  }

  DateTime? _calculateNextFromDate(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily': return date.add(const Duration(days: 1));
      case 'weekly': return date.add(const Duration(days: 7));
      case 'monthly': return DateTime(date.year, date.month + 1, date.day);
      case 'quarterly': return DateTime(date.year, date.month + 3, date.day);
      case 'biannual': return DateTime(date.year, date.month + 6, date.day);
      case 'yearly': return DateTime(date.year + 1, date.month, date.day);
      default:
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7));
          if (days != null) return date.add(Duration(days: days));
        }
        return null;
    }
  }

  Future<Reminder> addReminder({
    required String catId,
    required String catName,
    required String title,
    required String type,
    required String time,
    String frequency = 'daily',
    String? notes,
    String? description,
    bool notificationEnabled = true,
    bool isCompleted = false,
    DateTime? date,
    DateTime? nextDate,
    DateTime? reminderDate,
  }) async {
    final reminderRecordDate = date ?? DateTime.now();
    
    // Calculate next date based on frequency
    DateTime? calculatedNextDate = nextDate;
    if (calculatedNextDate == null && frequency != 'once') {
      calculatedNextDate = _calculateNextFromDate(reminderRecordDate, frequency);
    }
    
    final reminder = Reminder(
      id: _uuid.v4(),
      catId: catId,
      title: title,
      type: type,
      time: time,
      frequency: frequency,
      isActive: !isCompleted,
      isCompleted: isCompleted,
      notes: description ?? notes,
      createdAt: reminderRecordDate,
      nextDate: calculatedNextDate,
    );

    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveReminder(reminder);
      
      // Schedule notification
      if (notificationEnabled && !isCompleted) {
        await _scheduleNotificationForReminder(reminder, catName: catName);
      }

      state = [...state, reminder];
      return reminder;
    } catch (e) {
      debugPrint('RemindersProvider: Error saving reminder to Firestore: $e');
      rethrow;
    }
  }

  Future<void> toggleReminder(Reminder reminder) async {
    final newIsCompleted = !reminder.isCompleted;
    
    Reminder updated = reminder.copyWith(
      isCompleted: newIsCompleted, 
      isActive: !newIsCompleted,
    );
    
    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveReminder(updated);
      
      if (newIsCompleted) {
        // Tamamlandı - bildirimi iptal et
        await NotificationService.instance.cancelReminder(reminder.id.hashCode);
      } else {
        // Geri alındı - bildirimi tekrar planla
        await _scheduleNotificationForReminder(updated);
      }

      state = state.map((r) => r.id == reminder.id ? updated : r).toList();
    } catch (e) {
      debugPrint('RemindersProvider: Error updating reminder in Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      // Sadece Firebase'den sil
      await _firestore.deleteReminder(id);
      await NotificationService.instance.cancelReminder(id.hashCode);
      state = state.where((r) => r.id != id).toList();
    } catch (e) {
      debugPrint('RemindersProvider: Error deleting reminder from Firestore: $e');
      rethrow;
    }
  }

  // Firebase'den sync et (artık sadece state'i güncelle)
  Future<void> syncFromCloud() async {
    await loadReminders();
  }

  List<Reminder> getRemindersForCat(String catId) {
    return state.where((r) => r.catId == catId).toList();
  }
}
