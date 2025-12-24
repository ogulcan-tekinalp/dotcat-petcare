import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';
import '../../data/models/reminder_completion.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  bool get isLoggedIn => _userId != null;

  // ============ CATS ============
  Future<void> saveCat(Cat cat) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to save data');
    }
    await _db.collection('users').doc(_userId).collection('cats').doc(cat.id).set(cat.toMap());
  }

  Future<void> deleteCat(String catId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete data');
    }
    await _db.collection('users').doc(_userId).collection('cats').doc(catId).delete();
    // İlgili reminder ve weight kayıtlarını da sil
    final reminders = await _db.collection('users').doc(_userId).collection('reminders').where('catId', isEqualTo: catId).get();
    for (var doc in reminders.docs) {
      await doc.reference.delete();
    }
    final weights = await _db.collection('users').doc(_userId).collection('weights').where('catId', isEqualTo: catId).get();
    for (var doc in weights.docs) {
      await doc.reference.delete();
    }
  }

  Future<List<Cat>> getCats() async {
    if (!isLoggedIn) return [];
    final snapshot = await _db.collection('users').doc(_userId).collection('cats').get();
    return snapshot.docs.map((doc) => Cat.fromMap(doc.data())).toList();
  }

  // ============ REMINDERS ============
  Future<void> saveReminder(Reminder reminder) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to save data');
    }
    await _db.collection('users').doc(_userId).collection('reminders').doc(reminder.id).set(reminder.toMap());
  }

  Future<void> deleteReminder(String reminderId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete data');
    }
    await _db.collection('users').doc(_userId).collection('reminders').doc(reminderId).delete();
  }

  Future<List<Reminder>> getReminders() async {
    if (!isLoggedIn) return [];
    final snapshot = await _db.collection('users').doc(_userId).collection('reminders').get();
    return snapshot.docs.map((doc) => Reminder.fromMap(doc.data())).toList();
  }

  // ============ WEIGHTS ============
  Future<void> saveWeight(WeightRecord weight) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to save data');
    }
    await _db.collection('users').doc(_userId).collection('weights').doc(weight.id).set(weight.toMap());
  }

  Future<void> deleteWeight(String weightId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete data');
    }
    await _db.collection('users').doc(_userId).collection('weights').doc(weightId).delete();
  }

  Future<List<WeightRecord>> getWeights() async {
    if (!isLoggedIn) return [];
    final snapshot = await _db.collection('users').doc(_userId).collection('weights').get();
    return snapshot.docs.map((doc) => WeightRecord.fromMap(doc.data())).toList();
  }

  // ============ REMINDER COMPLETIONS ============
  Future<void> saveCompletion(ReminderCompletion completion) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to save data');
    }
    await _db.collection('users').doc(_userId).collection('reminder_completions').doc(completion.id).set(completion.toMap());
  }

  Future<void> deleteCompletion(String completionId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete data');
    }
    await _db.collection('users').doc(_userId).collection('reminder_completions').doc(completionId).delete();
  }

  Future<List<ReminderCompletion>> getCompletions() async {
    if (!isLoggedIn) return [];
    final snapshot = await _db.collection('users').doc(_userId).collection('reminder_completions').get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      // Firestore Timestamp'leri DateTime'a çevir
      if (data['completedDate'] is Timestamp) {
        data['completedDate'] = (data['completedDate'] as Timestamp).toDate().toIso8601String().split('T')[0];
      } else if (data['completedDate'] is String) {
        // Zaten string ise olduğu gibi kullan
      }
      if (data['completedAt'] is Timestamp) {
        data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
      } else if (data['completedAt'] is String) {
        // Zaten string ise olduğu gibi kullan
      }
      // ID'yi doc.id'den al (eğer data'da yoksa)
      if (!data.containsKey('id') || data['id'] == null) {
        data['id'] = doc.id;
      }
      return ReminderCompletion.fromMap(data);
    }).toList();
  }

  // Real-time completion stream (gerçek zamanlı sync için)
  Stream<List<ReminderCompletion>> getCompletionsStream() {
    if (!isLoggedIn) return Stream.value([]);
    return _db.collection('users').doc(_userId).collection('reminder_completions').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        // Firestore Timestamp'leri DateTime'a çevir
        if (data['completedDate'] is Timestamp) {
          data['completedDate'] = (data['completedDate'] as Timestamp).toDate().toIso8601String().split('T')[0];
        } else if (data['completedDate'] is String) {
          // Zaten string ise olduğu gibi kullan
        }
        if (data['completedAt'] is Timestamp) {
          data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
        } else if (data['completedAt'] is String) {
          // Zaten string ise olduğu gibi kullan
        }
        // ID'yi doc.id'den al (eğer data'da yoksa)
        if (!data.containsKey('id') || data['id'] == null) {
          data['id'] = doc.id;
        }
        return ReminderCompletion.fromMap(data);
      }).toList();
    });
  }

  // ============ FULL SYNC ============
  Future<void> syncFromCloud({
    required Future<void> Function(Cat) onCat,
    required Future<void> Function(Reminder) onReminder,
    required Future<void> Function(WeightRecord) onWeight,
  }) async {
    if (!isLoggedIn) return;
    
    final cats = await getCats();
    for (var cat in cats) {
      await onCat(cat);
    }
    
    final reminders = await getReminders();
    for (var reminder in reminders) {
      await onReminder(reminder);
    }
    
    final weights = await getWeights();
    for (var weight in weights) {
      await onWeight(weight);
    }
  }
}
