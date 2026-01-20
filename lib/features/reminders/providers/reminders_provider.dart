import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/reminder.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/services/firestore_service.dart';
import '../../cats/providers/cats_provider.dart';

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) {
  return RemindersNotifier(ref);
});

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier(this._ref) : super([]) {
    loadReminders();
  }

  final Ref _ref;
  final _firestore = FirestoreService();
  final _uuid = const Uuid();

  Future<void> loadReminders() async {
    // Sadece cloud'dan yükle (kullanıcı giriş yapmışsa)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        final cloudReminders = await _firestore.getReminders();

        // GÜNLÜK HATIRLATICIları sıfırla (eğer farklı günde tamamlanmışsa)
        final updatedReminders = await _resetDailyRemindersIfNeeded(cloudReminders);
        state = updatedReminders;

        // Reschedule reminders on app start
        // Daily reminders: her zaman planla (tamamlanmış olsa bile yarın çalacak)
        // Diğer tekrarlayan reminders: aktif ve tamamlanmamışsa planla
        // Once reminders: sadece aktif ve tamamlanmamışsa planla
        for (final reminder in updatedReminders) {
          if (reminder.frequency == 'daily' && reminder.isActive) {
            // Daily reminder - tamamlanmış olsa bile her gün çalacak
            await _scheduleNotificationForReminder(reminder);
          } else if (reminder.isActive && !reminder.isCompleted) {
            // Diğer aktif ve tamamlanmamış reminders
            await _scheduleNotificationForReminder(reminder);
          }
        }

        debugPrint('RemindersProvider: Loaded ${updatedReminders.length} reminders, scheduled notifications');
      } else {
        // Giriş yapılmamışsa boş liste
        state = [];
      }
    } catch (e) {
      debugPrint('RemindersProvider: Load error: $e');
      state = [];
    }
  }

  /// Günlük hatırlatıcıları sıfırla (eğer tamamlanma tarihi bugünden farklıysa)
  Future<List<Reminder>> _resetDailyRemindersIfNeeded(List<Reminder> reminders) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final updatedReminders = <Reminder>[];
    bool hasUpdates = false;

    for (final reminder in reminders) {
      if (reminder.frequency == 'daily' &&
          reminder.isCompleted &&
          reminder.lastCompletionDate != null) {
        // Tamamlanma tarihi bugünden farklıysa sıfırla
        final completionDate = DateTime(
          reminder.lastCompletionDate!.year,
          reminder.lastCompletionDate!.month,
          reminder.lastCompletionDate!.day,
        );

        if (completionDate.isBefore(todayDate)) {
          // Günlük hatırlatıcıyı sıfırla
          final resetReminder = reminder.copyWith(
            isCompleted: false,
            isActive: true,
          );
          updatedReminders.add(resetReminder);

          // Firebase'e kaydet
          await _firestore.saveReminder(resetReminder);
          hasUpdates = true;

          debugPrint('RemindersProvider: Reset daily reminder ${reminder.title} (completed on $completionDate, today is $todayDate)');
        } else {
          updatedReminders.add(reminder);
        }
      } else {
        updatedReminders.add(reminder);
      }
    }

    if (hasUpdates) {
      debugPrint('RemindersProvider: Daily reminders reset completed');
    }

    return updatedReminders;
  }

  /// Cat'e ait reminder'ları yükle (state'i değiştirmez, sadece notification schedule yapar)
  /// Tüm reminder'lar zaten loadReminders() ile yüklü, bu method sadece
  /// belirli bir cat için notification scheduling yapmak için kullanılabilir
  Future<void> loadRemindersForCat(String catId) async {
    // Cat detail screen için: ref.watch(remindersProvider) ile tüm reminders alınıp
    // .where((r) => r.catId == catId) ile filtreleniyor.
    // Bu yaklaşım daha performanslı çünkü state değişimi gerektirmiyor.
    //
    // Eğer sadece bu cat'in notification'larını reschedule etmek istersek:
    final catReminders = state.where((r) => r.catId == catId).toList();
    for (final reminder in catReminders) {
      if (reminder.isActive && !reminder.isCompleted) {
        await _scheduleNotificationForReminder(reminder);
      }
    }
  }

  Future<void> _scheduleNotificationForReminder(Reminder reminder, {String? catName}) async {
    final timeParts = reminder.time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Get cat name from catsProvider if not provided
    String name = catName ?? 'Kediniz';
    if (catName == null) {
      final cats = _ref.read(catsProvider);
      final cat = cats.where((c) => c.id == reminder.catId).firstOrNull;
      if (cat != null) {
        name = cat.name;
      }
    }
    
    // Calculate next occurrence
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? nextDate = _getNextOccurrence(reminder, today);
    
    if (nextDate == null) {
      debugPrint('RemindersProvider: No next date for reminder ${reminder.id}');
      return;
    }
    
    final scheduledDateTime = DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
    
    debugPrint('RemindersProvider: Scheduling notification for ${reminder.title} at $scheduledDateTime (frequency: ${reminder.frequency})');
    
    // Only schedule if in the future
    if (scheduledDateTime.isAfter(now)) {
      final notificationTitle = '🐱 ${reminder.title}';
      final notificationBody = '$name için ${reminder.title.toLowerCase()} zamanı!';
      
      if (reminder.frequency == 'daily') {
        // For daily reminders, use repeating daily notification
        final notificationId = NotificationService.instance.generateNotificationId(reminder.id);
        await NotificationService.instance.scheduleDailyReminder(
          id: notificationId,
          title: notificationTitle,
          body: notificationBody,
          hour: hour,
          minute: minute,
        );
        debugPrint('RemindersProvider: Daily reminder scheduled with id: $notificationId');
      } else if (reminder.frequency == 'once') {
        // For one-time reminders
        final notificationId = NotificationService.instance.generateNotificationId(reminder.id);
        await NotificationService.instance.scheduleOneTimeReminder(
          id: notificationId,
          title: notificationTitle,
          body: notificationBody,
          dateTime: scheduledDateTime,
          payload: reminder.id,
        );
        debugPrint('RemindersProvider: One-time reminder scheduled with id: $notificationId');
      } else {
        // For other frequencies (weekly, monthly, etc.), use repeating reminder
        await NotificationService.instance.scheduleRepeatingReminder(
          reminderId: reminder.id,
          title: notificationTitle,
          body: notificationBody,
          nextOccurrence: nextDate,
          hour: hour,
          minute: minute,
          frequency: reminder.frequency,
          payload: reminder.id,
        );
        debugPrint('RemindersProvider: Repeating reminder (${reminder.frequency}) scheduled');
      }
    } else {
      debugPrint('RemindersProvider: Scheduled time is in the past: $scheduledDateTime');
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
    // DateHelper'ı kullan - gün taşması sorunlarını çözer
    return DateHelper.calculateNextDate(date, frequency);
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
      petId: catId,
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
      // Daily reminders: her zaman planla (yarın çalacak)
      // Diğerleri: notificationEnabled ve tamamlanmamışsa planla
      if (frequency == 'daily' && !isCompleted) {
        await _scheduleNotificationForReminder(reminder, catName: catName);
      } else if (notificationEnabled && !isCompleted) {
        await _scheduleNotificationForReminder(reminder, catName: catName);
      }

      state = [...state, reminder];
      return reminder;
    } catch (e) {
      debugPrint('RemindersProvider: Error saving reminder to Firestore: $e');
      rethrow;
    }
  }

  /// Toggle reminder completion status
  /// [actualCompletionDate] - Gerçek tamamlanma tarihi (sağlık kayıtları için)
  /// Bu tarih, sonraki occurrence hesaplamasında baz alınır
  Future<void> toggleReminder(Reminder reminder, {DateTime? actualCompletionDate}) async {
    final newIsCompleted = !reminder.isCompleted;
    final completionDate = newIsCompleted ? (actualCompletionDate ?? DateTime.now()) : null;

    // Calculate next occurrence for repeating reminders
    DateTime? newNextDate = reminder.nextDate;
    if (newIsCompleted && reminder.frequency != 'once') {
      // When marking as completed, calculate next occurrence
      // Eğer actualCompletionDate verilmişse onu kullan (sağlık kayıtları için)
      final baseDate = actualCompletionDate ?? reminder.nextDate ?? reminder.createdAt;
      newNextDate = _calculateNextFromDate(baseDate, reminder.frequency);
    }

    Reminder updated = reminder.copyWith(
      isCompleted: newIsCompleted,
      isActive: !newIsCompleted,
      nextDate: newNextDate,
      lastCompletionDate: completionDate,
    );

    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveReminder(updated);

      if (newIsCompleted) {
        // Tamamlandı olarak işaretlendi
        if (reminder.frequency == 'once') {
          // Tek seferlik reminder - bildirimi iptal et
          await NotificationService.instance.cancelReminderNotifications(reminder.id);
        } else if (reminder.frequency == 'daily' || reminder.frequency == 'weekly') {
          // GÜNLÜK/HAFTALIK REMINDER: Native repeat kullanıyor, bildirimi iptal ETME
          // matchDateTimeComponents sayesinde otomatik tekrar ediyor
          // Kullanıcı tamamlayabilir ama bildirim tekrar gelmeye devam eder
          debugPrint('RemindersProvider: ${reminder.frequency} reminder completed, native repeat notification will continue');
        } else {
          // AYLIK/YILLIK/ÖZEL PERIYOT REMINDER: Gelecek oluşumlar zaten zamanlanmış
          // Tamamlandığında bir şey yapmaya gerek yok, çünkü gelecek 365 günlük
          // bildirimler zaten schedule edilmiş durumda
          debugPrint('RemindersProvider: ${reminder.frequency} reminder completed, future occurrences already scheduled');
        }
      } else {
        // Geri alındı - bildirimi tekrar planla (eğer iptal edilmişse)
        await NotificationService.instance.cancelReminderNotifications(reminder.id);
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
      // Tüm ilgili bildirimleri iptal et
      await NotificationService.instance.cancelReminderNotifications(id);
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

  /// Tamamlama tarihine göre sonraki tarihi güncelle
  /// Sağlık kayıtları (aşı, ilaç, vet) için kullanılır
  Future<void> updateNextDateFromCompletion(String reminderId, DateTime actualCompletionDate) async {
    try {
      final reminder = state.firstWhere((r) => r.id == reminderId);
      
      // Sonraki tarihi gerçek tamamlanma tarihine göre hesapla
      final nextDate = _calculateNextFromDate(actualCompletionDate, reminder.frequency);
      
      if (nextDate != null) {
        final updated = reminder.copyWith(
          nextDate: nextDate,
          isCompleted: false, // Sonraki için bekliyor
          isActive: true,
        );
        
        // Firebase'e kaydet
        await _firestore.saveReminder(updated);
        
        // Yeni tarih için bildirim planla
        await _scheduleNotificationForReminder(updated);
        
        // State'i güncelle
        state = state.map((r) => r.id == reminderId ? updated : r).toList();
        
        debugPrint('RemindersProvider: Updated next date for $reminderId to $nextDate (based on completion: $actualCompletionDate)');
      }
    } catch (e) {
      debugPrint('RemindersProvider: Error updating next date from completion: $e');
    }
  }
}
