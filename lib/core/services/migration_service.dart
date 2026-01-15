import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';

/// Service for migrating user data from anonymous accounts to authenticated accounts
/// Used when user creates cat in onboarding (anonymous) then signs in with Google/Apple/Email
class MigrationService {
  static final MigrationService instance = MigrationService._();
  MigrationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main migration method - migrates all user data from old UID to new UID
  ///
  /// Called after linkWithCredential succeeds
  /// Steps:
  /// 1. Get old user's cats and new user's cats
  /// 2. Merge cats (if same name exists, update weight; else copy cat)
  /// 3. Migrate weight records for each cat
  /// 4. Migrate reminders
  /// 5. Migrate reminder completions
  /// 6. Delete old user data
  Future<void> migrateUserData(String oldUserId, String newUserId) async {
    debugPrint('🔄 Starting migration from $oldUserId to $newUserId');

    try {
      // Step 1: Merge cats
      await mergeCats(oldUserId, newUserId);

      // Step 2: Migrate reminders
      await _migrateReminders(oldUserId, newUserId);

      // Step 3: Migrate reminder completions
      await _migrateReminderCompletions(oldUserId, newUserId);

      // Step 4: Clean up old user data
      await cleanupOldUserData(oldUserId);

      debugPrint('✅ Migration completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Migration failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - we want the user to be able to sign in even if migration fails
      // They can always re-add their cat manually
    }
  }

  /// Merge cats from old user to new user
  ///
  /// Logic:
  /// - If cat with same name exists in new user's cats → update weight only
  /// - If cat doesn't exist → copy cat to new user
  Future<void> mergeCats(String oldUserId, String newUserId) async {
    debugPrint('🐱 Merging cats from $oldUserId to $newUserId');

    // Get old user's cats
    final oldCatsSnapshot = await _firestore
        .collection('cats')
        .doc(oldUserId)
        .collection('user_cats')
        .get();

    if (oldCatsSnapshot.docs.isEmpty) {
      debugPrint('No cats to migrate');
      return;
    }

    // Get new user's cats
    final newCatsSnapshot = await _firestore
        .collection('cats')
        .doc(newUserId)
        .collection('user_cats')
        .get();

    final newCats = newCatsSnapshot.docs.map((doc) {
      return Cat.fromMap({...doc.data(), 'id': doc.id});
    }).toList();

    // Create a map of cat names to cat IDs for quick lookup
    final newCatsByName = <String, String>{};
    for (final cat in newCats) {
      newCatsByName[cat.name.toLowerCase()] = cat.id;
    }

    // Process each old cat
    for (final oldCatDoc in oldCatsSnapshot.docs) {
      final oldCat = Cat.fromMap({...oldCatDoc.data(), 'id': oldCatDoc.id});
      final catNameLower = oldCat.name.toLowerCase();

      debugPrint('Processing cat: ${oldCat.name}');

      // Check if cat with same name exists in new user's account
      if (newCatsByName.containsKey(catNameLower)) {
        // Cat exists - merge weight records only
        final newCatId = newCatsByName[catNameLower]!;
        debugPrint('  → Cat exists, merging weights: ${oldCat.id} → $newCatId');
        await _mergeWeightRecords(oldUserId, oldCat.id, newUserId, newCatId);
      } else {
        // Cat doesn't exist - copy cat to new user
        debugPrint('  → Cat doesn\'t exist, copying to new user');
        await _copyCatToNewUser(oldUserId, oldCat, newUserId);
      }
    }
  }

  /// Copy a cat from old user to new user (includes weight records)
  Future<void> _copyCatToNewUser(String oldUserId, Cat cat, String newUserId) async {
    // Create cat document in new user's collection
    final newCatRef = _firestore
        .collection('cats')
        .doc(newUserId)
        .collection('user_cats')
        .doc(cat.id); // Keep same cat ID

    await newCatRef.set(cat.toMap());

    // Copy weight records
    await _mergeWeightRecords(oldUserId, cat.id, newUserId, cat.id);
  }

  /// Merge weight records from old cat to new cat
  Future<void> _mergeWeightRecords(
    String oldUserId,
    String oldCatId,
    String newUserId,
    String newCatId,
  ) async {
    debugPrint('  📊 Merging weight records: $oldCatId → $newCatId');

    // Get old cat's weight records
    final oldWeightsSnapshot = await _firestore
        .collection('weight_records')
        .doc(oldUserId)
        .collection('user_records')
        .where('catId', isEqualTo: oldCatId)
        .get();

    if (oldWeightsSnapshot.docs.isEmpty) {
      debugPrint('    No weight records to merge');
      return;
    }

    // Get existing weight records for new cat (to avoid duplicates)
    final newWeightsSnapshot = await _firestore
        .collection('weight_records')
        .doc(newUserId)
        .collection('user_records')
        .where('catId', isEqualTo: newCatId)
        .get();

    final existingDates = newWeightsSnapshot.docs
        .map((doc) => (doc.data()['date'] as Timestamp).toDate())
        .toSet();

    // Copy weight records that don't exist in new cat
    int copiedCount = 0;
    for (final weightDoc in oldWeightsSnapshot.docs) {
      final weightData = weightDoc.data();
      final weightDate = (weightData['date'] as Timestamp).toDate();

      // Skip if weight record for this date already exists
      if (existingDates.contains(weightDate)) {
        debugPrint('    Skipping duplicate weight for ${weightDate.toString().split(' ')[0]}');
        continue;
      }

      // Update catId to new cat ID
      weightData['catId'] = newCatId;

      // Copy to new user's collection with same ID
      await _firestore
          .collection('weight_records')
          .doc(newUserId)
          .collection('user_records')
          .doc(weightDoc.id)
          .set(weightData);

      copiedCount++;
    }

    debugPrint('    Copied $copiedCount weight records');
  }

  /// Migrate reminders from old user to new user
  Future<void> _migrateReminders(String oldUserId, String newUserId) async {
    debugPrint('⏰ Migrating reminders');

    // Get old user's reminders
    final oldRemindersSnapshot = await _firestore
        .collection('reminders')
        .doc(oldUserId)
        .collection('user_reminders')
        .get();

    if (oldRemindersSnapshot.docs.isEmpty) {
      debugPrint('  No reminders to migrate');
      return;
    }

    // Get cat ID mapping (old cat name → new cat ID)
    final catMapping = await _getCatIdMapping(oldUserId, newUserId);

    // Copy reminders
    int copiedCount = 0;
    for (final reminderDoc in oldRemindersSnapshot.docs) {
      final reminderData = reminderDoc.data();
      final oldCatId = reminderData['catId'] as String?;

      // If reminder has a catId, map it to new cat ID
      if (oldCatId != null && catMapping.containsKey(oldCatId)) {
        reminderData['catId'] = catMapping[oldCatId];
      }

      // Copy to new user's collection with same ID
      await _firestore
          .collection('reminders')
          .doc(newUserId)
          .collection('user_reminders')
          .doc(reminderDoc.id)
          .set(reminderData);

      copiedCount++;
    }

    debugPrint('  Copied $copiedCount reminders');
  }

  /// Migrate reminder completions from old user to new user
  Future<void> _migrateReminderCompletions(String oldUserId, String newUserId) async {
    debugPrint('✅ Migrating reminder completions');

    // Get old user's completions
    final oldCompletionsSnapshot = await _firestore
        .collection('reminder_completions')
        .doc(oldUserId)
        .collection('completions')
        .get();

    if (oldCompletionsSnapshot.docs.isEmpty) {
      debugPrint('  No completions to migrate');
      return;
    }

    // Get reminder ID mapping (we keep same IDs, so no mapping needed)
    // Copy completions
    int copiedCount = 0;
    for (final completionDoc in oldCompletionsSnapshot.docs) {
      // Copy to new user's collection with same ID
      await _firestore
          .collection('reminder_completions')
          .doc(newUserId)
          .collection('completions')
          .doc(completionDoc.id)
          .set(completionDoc.data());

      copiedCount++;
    }

    debugPrint('  Copied $copiedCount completions');
  }

  /// Get mapping of old cat IDs to new cat IDs
  ///
  /// Used for updating reminder catIds during migration
  /// Returns map: oldCatId → newCatId
  Future<Map<String, String>> _getCatIdMapping(String oldUserId, String newUserId) async {
    final oldCatsSnapshot = await _firestore
        .collection('cats')
        .doc(oldUserId)
        .collection('user_cats')
        .get();

    final newCatsSnapshot = await _firestore
        .collection('cats')
        .doc(newUserId)
        .collection('user_cats')
        .get();

    final newCatsByName = <String, String>{};
    for (final doc in newCatsSnapshot.docs) {
      final cat = Cat.fromMap({...doc.data(), 'id': doc.id});
      newCatsByName[cat.name.toLowerCase()] = cat.id;
    }

    final mapping = <String, String>{};
    for (final doc in oldCatsSnapshot.docs) {
      final cat = Cat.fromMap({...doc.data(), 'id': doc.id});
      final newCatId = newCatsByName[cat.name.toLowerCase()];

      if (newCatId != null) {
        mapping[cat.id] = newCatId;
      } else {
        // Cat was copied with same ID
        mapping[cat.id] = cat.id;
      }
    }

    return mapping;
  }

  /// Clean up old user data after successful migration
  ///
  /// Deletes:
  /// - Cats
  /// - Weight records
  /// - Reminders
  /// - Reminder completions
  Future<void> cleanupOldUserData(String oldUserId) async {
    debugPrint('🧹 Cleaning up old user data: $oldUserId');

    try {
      // Delete cats
      final catsSnapshot = await _firestore
          .collection('cats')
          .doc(oldUserId)
          .collection('user_cats')
          .get();

      for (final doc in catsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete weight records
      final weightsSnapshot = await _firestore
          .collection('weight_records')
          .doc(oldUserId)
          .collection('user_records')
          .get();

      for (final doc in weightsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete reminders
      final remindersSnapshot = await _firestore
          .collection('reminders')
          .doc(oldUserId)
          .collection('user_reminders')
          .get();

      for (final doc in remindersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete reminder completions
      final completionsSnapshot = await _firestore
          .collection('reminder_completions')
          .doc(oldUserId)
          .collection('completions')
          .get();

      for (final doc in completionsSnapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('✅ Cleanup completed');
    } catch (e) {
      debugPrint('⚠️ Cleanup failed (non-critical): $e');
      // Don't rethrow - cleanup failure is not critical
    }
  }
}
