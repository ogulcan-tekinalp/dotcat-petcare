import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';
import '../../data/models/reminder.dart';

/// Reminder Migration Service
///
/// Mevcut reminder'lara yeni alanlar eklemek için migration servisi.
/// Özellikle lastCompletionDate alanını eklemek için kullanılır.
class ReminderMigrationService {
  static final ReminderMigrationService instance = ReminderMigrationService._init();

  ReminderMigrationService._init();

  static const String _migrationKey = 'reminder_migration_v1_completed';
  final _firestore = FirestoreService();

  /// Migration'ı çalıştır (sadece bir kez)
  Future<void> runMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool(_migrationKey) ?? false;

      if (migrationCompleted) {
        debugPrint('ReminderMigrationService: Migration already completed');
        return;
      }

      debugPrint('ReminderMigrationService: Starting migration...');

      // Tüm reminder'ları al
      final reminders = await _firestore.getReminders();

      if (reminders.isEmpty) {
        debugPrint('ReminderMigrationService: No reminders to migrate');
        await prefs.setBool(_migrationKey, true);
        return;
      }

      int migratedCount = 0;

      // Her reminder için lastCompletionDate kontrolü yap
      for (final reminder in reminders) {
        // Eğer tamamlanmış ve lastCompletionDate null ise, bugünü ata
        if (reminder.isCompleted && reminder.lastCompletionDate == null) {
          final updated = reminder.copyWith(
            lastCompletionDate: DateTime.now(),
          );

          await _firestore.saveReminder(updated);
          migratedCount++;

          debugPrint('ReminderMigrationService: Migrated reminder ${reminder.id} (${reminder.title})');
        }
      }

      // Migration tamamlandı işaretini koy
      await prefs.setBool(_migrationKey, true);

      debugPrint('ReminderMigrationService: Migration completed. Migrated $migratedCount reminders out of ${reminders.length}');
    } catch (e) {
      debugPrint('ReminderMigrationService: Migration error: $e');
      // Hata durumunda migration'ı tekrar deneyebilmek için işareti koyma
    }
  }

  /// Migration'ı sıfırla (sadece test için)
  Future<void> resetMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationKey);
      debugPrint('ReminderMigrationService: Migration reset');
    } catch (e) {
      debugPrint('ReminderMigrationService: Error resetting migration: $e');
    }
  }
}
