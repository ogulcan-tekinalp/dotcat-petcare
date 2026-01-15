import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';
import '../../data/models/reminder_completion.dart';
import '../utils/firestore_extensions.dart';

/// Sync durumları
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Sync sonucu
class SyncResult {
  final bool success;
  final int uploadedCount;
  final int downloadedCount;
  final String? errorMessage;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'SyncResult(success: $success, uploaded: $uploadedCount, downloaded: $downloadedCount)';
}

/// Offline-first Sync Service
/// 
/// SQLite lokal veritabanı ana kaynak (source of truth).
/// Firestore yalnızca sync ve backup için kullanılır.
/// 
/// Sync stratejisi:
/// 1. Her değişiklik önce SQLite'a yazılır
/// 2. Online olunca Firestore'a push edilir
/// 3. Uygulama açılışında Firestore'dan pull yapılır (newer-wins)
class SyncService {
  static final SyncService instance = SyncService._init();
  
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // Sync state
  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  SyncState _currentState = SyncState.idle;
  SyncState get currentState => _currentState;
  
  // Last sync time
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Pending changes count
  int _pendingChanges = 0;
  int get pendingChanges => _pendingChanges;
  
  SyncService._init();
  
  String? get _userId => _auth.currentUser?.uid;
  bool get isLoggedIn => _userId != null;
  
  /// Initialize sync service
  Future<void> init() async {
    // Load last sync time from preferences
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_sync_time');
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }
    
    debugPrint('SyncService: Initialized, last sync: $_lastSyncTime');
  }
  
  /// Set sync state
  void _setState(SyncState state) {
    _currentState = state;
    _syncStateController.add(state);
  }
  
  /// Full bidirectional sync
  /// 1. Push local changes to cloud
  /// 2. Pull cloud changes to local
  Future<SyncResult> fullSync() async {
    if (!isLoggedIn) {
      debugPrint('SyncService: Not logged in, skipping sync');
      return SyncResult(success: false, errorMessage: 'Not logged in');
    }
    
    if (_currentState == SyncState.syncing) {
      debugPrint('SyncService: Already syncing, skipping');
      return SyncResult(success: false, errorMessage: 'Already syncing');
    }
    
    _setState(SyncState.syncing);
    
    try {
      int uploaded = 0;
      int downloaded = 0;
      
      // 1. Push local data to cloud
      uploaded += await _pushCats();
      uploaded += await _pushReminders();
      uploaded += await _pushWeights();
      uploaded += await _pushCompletions();
      
      // 2. Pull cloud data to local (newer-wins)
      downloaded += await _pullCats();
      downloaded += await _pullReminders();
      downloaded += await _pullWeights();
      downloaded += await _pullCompletions();
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      
      _pendingChanges = 0;
      _setState(SyncState.idle);
      
      debugPrint('SyncService: Full sync completed - uploaded: $uploaded, downloaded: $downloaded');
      
      return SyncResult(
        success: true,
        uploadedCount: uploaded,
        downloadedCount: downloaded,
      );
    } catch (e) {
      debugPrint('SyncService: Sync error: $e');
      _setState(SyncState.error);
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }
  
  /// Push only (upload local changes to cloud)
  Future<SyncResult> pushToCloud() async {
    if (!isLoggedIn) {
      return SyncResult(success: false, errorMessage: 'Not logged in');
    }
    
    _setState(SyncState.syncing);
    
    try {
      int uploaded = 0;
      uploaded += await _pushCats();
      uploaded += await _pushReminders();
      uploaded += await _pushWeights();
      uploaded += await _pushCompletions();
      
      _setState(SyncState.idle);
      return SyncResult(success: true, uploadedCount: uploaded);
    } catch (e) {
      _setState(SyncState.error);
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }
  
  /// Pull only (download cloud data to local)
  Future<SyncResult> pullFromCloud() async {
    if (!isLoggedIn) {
      return SyncResult(success: false, errorMessage: 'Not logged in');
    }
    
    _setState(SyncState.syncing);
    
    try {
      int downloaded = 0;
      downloaded += await _pullCats();
      downloaded += await _pullReminders();
      downloaded += await _pullWeights();
      downloaded += await _pullCompletions();
      
      _lastSyncTime = DateTime.now();
      _setState(SyncState.idle);
      
      return SyncResult(success: true, downloadedCount: downloaded);
    } catch (e) {
      _setState(SyncState.error);
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }
  
  // ============ PUSH METHODS ============
  
  Future<int> _pushCats() async {
    if (_userId == null) return 0;
    
    final localCats = await _db.getAllCats();
    int count = 0;
    
    for (final cat in localCats) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('cats')
            .doc(cat.id)
            .set(cat.toMap(), SetOptions(merge: true));
        count++;
      } catch (e) {
        debugPrint('SyncService: Error pushing cat ${cat.id}: $e');
      }
    }
    
    return count;
  }
  
  Future<int> _pushReminders() async {
    if (_userId == null) return 0;
    
    final localReminders = await _db.getAllReminders();
    int count = 0;
    
    for (final reminder in localReminders) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('reminders')
            .doc(reminder.id)
            .set(reminder.toMap(), SetOptions(merge: true));
        count++;
      } catch (e) {
        debugPrint('SyncService: Error pushing reminder ${reminder.id}: $e');
      }
    }
    
    return count;
  }
  
  Future<int> _pushWeights() async {
    if (_userId == null) return 0;
    
    // Get all cats first, then get weights for each
    final cats = await _db.getAllCats();
    int count = 0;
    
    for (final cat in cats) {
      final weights = await _db.getWeightRecordsForCat(cat.id);
      for (final weight in weights) {
        try {
          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('weights')
              .doc(weight.id)
              .set(weight.toMap(), SetOptions(merge: true));
          count++;
        } catch (e) {
          debugPrint('SyncService: Error pushing weight ${weight.id}: $e');
        }
      }
    }
    
    return count;
  }
  
  Future<int> _pushCompletions() async {
    if (_userId == null) return 0;
    
    // Completions tablosundaki tüm kayıtları al
    final db = await _db.database;
    final maps = await db.query('reminder_completions');
    int count = 0;
    
    for (final map in maps) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('reminder_completions')
            .doc(map['id'] as String)
            .set({
              'id': map['id'],
              'reminderId': map['reminderId'],
              'completedDate': map['completedDate'],
              'completedAt': map['completedAt'],
            }, SetOptions(merge: true));
        count++;
      } catch (e) {
        debugPrint('SyncService: Error pushing completion: $e');
      }
    }
    
    return count;
  }
  
  // ============ PULL METHODS ============
  
  Future<int> _pullCats() async {
    if (_userId == null) return 0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('cats')
        .get();
    
    int count = 0;
    
    for (final doc in snapshot.docs) {
      try {
        final cloudCat = Cat.fromMap(doc.data());
        final localCat = await _db.getCatById(cloudCat.id);
        
        if (localCat == null) {
          // Cloud'da var, local'de yok - ekle
          await _db.insertCat(cloudCat);
          count++;
        } else {
          // Her ikisinde de var - newer wins (createdAt karşılaştır)
          // Not: Cat'te updatedAt yok, bu yüzden her zaman cloud'u kabul ediyoruz
          await _db.updateCat(cloudCat);
          count++;
        }
      } catch (e) {
        debugPrint('SyncService: Error pulling cat: $e');
      }
    }
    
    return count;
  }
  
  Future<int> _pullReminders() async {
    if (_userId == null) return 0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('reminders')
        .get();
    
    int count = 0;
    
    for (final doc in snapshot.docs) {
      try {
        final cloudReminder = Reminder.fromMap(doc.data());
        final localReminder = await _db.getReminderById(cloudReminder.id);
        
        if (localReminder == null) {
          await _db.insertReminder(cloudReminder);
          count++;
        } else {
          await _db.updateReminder(cloudReminder);
          count++;
        }
      } catch (e) {
        debugPrint('SyncService: Error pulling reminder: $e');
      }
    }
    
    return count;
  }
  
  Future<int> _pullWeights() async {
    if (_userId == null) return 0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('weights')
        .get();
    
    int count = 0;
    final db = await _db.database;
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final id = data['id'] as String;
        
        // Check if exists locally
        final existing = await db.query('weight_records', where: 'id = ?', whereArgs: [id]);
        
        if (existing.isEmpty) {
          final weight = WeightRecord.fromMap(data);
          await _db.insertWeightRecord(weight);
          count++;
        }
      } catch (e) {
        debugPrint('SyncService: Error pulling weight: $e');
      }
    }
    
    return count;
  }
  
  Future<int> _pullCompletions() async {
    if (_userId == null) return 0;
    
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('reminder_completions')
        .get();
    
    int count = 0;
    final db = await _db.database;
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();

        // Firestore Timestamp'leri güvenli şekilde handle et (extension methods kullanarak)
        final completedDate = FirestoreDataConverter.getDateString(data['completedDate']) ?? '';
        final completedAtDateTime = FirestoreDataConverter.extractDateTime(data['completedAt']);
        final completedAt = completedAtDateTime?.toIso8601String() ?? DateTime.now().toIso8601String();

        final id = data['id'] as String? ?? doc.id;
        final reminderId = data['reminderId'] as String? ?? '';

        // Validate required fields
        if (id.isEmpty || reminderId.isEmpty || completedDate.isEmpty) {
          debugPrint('SyncService: Invalid completion data, skipping: ${doc.id}');
          continue;
        }

        // Check if exists locally
        final existing = await db.query('reminder_completions', where: 'id = ?', whereArgs: [id]);

        if (existing.isEmpty) {
          // ReminderCompletion model kullanarak data integrity sağla
          final completion = ReminderCompletion(
            id: id,
            reminderId: reminderId,
            completedDate: DateTime.parse(completedDate), // String'den DateTime'a çevir
            completedAt: DateTime.parse(completedAt), // String'den DateTime'a çevir
          );

          await db.insert('reminder_completions', completion.toMap());
          count++;
        }
      } catch (e) {
        debugPrint('SyncService: Error pulling completion ${doc.id}: $e');
      }
    }
    
    return count;
  }
  
  // ============ DELETE SYNC ============
  
  /// Delete cat from cloud
  Future<void> deleteCatFromCloud(String catId) async {
    if (!isLoggedIn) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cats')
          .doc(catId)
          .delete();
      
      // Also delete related reminders and weights from cloud
      final remindersQuery = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('reminders')
          .where('catId', isEqualTo: catId)
          .get();
      
      for (final doc in remindersQuery.docs) {
        await doc.reference.delete();
      }
      
      final weightsQuery = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('weights')
          .where('catId', isEqualTo: catId)
          .get();
      
      for (final doc in weightsQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('SyncService: Error deleting cat from cloud: $e');
    }
  }
  
  /// Delete reminder from cloud
  Future<void> deleteReminderFromCloud(String reminderId) async {
    if (!isLoggedIn) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('reminders')
          .doc(reminderId)
          .delete();
    } catch (e) {
      debugPrint('SyncService: Error deleting reminder from cloud: $e');
    }
  }
  
  /// Delete weight from cloud
  Future<void> deleteWeightFromCloud(String weightId) async {
    if (!isLoggedIn) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('weights')
          .doc(weightId)
          .delete();
    } catch (e) {
      debugPrint('SyncService: Error deleting weight from cloud: $e');
    }
  }
  
  /// Delete completion from cloud
  Future<void> deleteCompletionFromCloud(String completionId) async {
    if (!isLoggedIn) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('reminder_completions')
          .doc(completionId)
          .delete();
    } catch (e) {
      debugPrint('SyncService: Error deleting completion from cloud: $e');
    }
  }
  
  /// Clear local data (logout sonrası)
  Future<void> clearLocalData() async {
    final db = await _db.database;
    await db.delete('cats');
    await db.delete('reminders');
    await db.delete('weight_records');
    await db.delete('reminder_completions');
    await db.delete('vaccinations');
    await db.delete('health_notes');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');
    _lastSyncTime = null;
    
    debugPrint('SyncService: Local data cleared');
  }
  
  /// Dispose
  void dispose() {
    _syncStateController.close();
  }
}


