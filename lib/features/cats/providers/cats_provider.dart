import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/cat.dart';
import '../../../core/services/firestore_service.dart';

final catsProvider = StateNotifierProvider<CatsNotifier, List<Cat>>((ref) {
  return CatsNotifier();
});

final selectedCatProvider = StateProvider<Cat?>((ref) => null);

class CatsNotifier extends StateNotifier<List<Cat>> {
  CatsNotifier() : super([]) {
    loadCats();
  }

  final _firestore = FirestoreService();
  final _uuid = const Uuid();

  Future<void> loadCats() async {
    // Sadece cloud'dan yükle (kullanıcı giriş yapmışsa)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        final cloudCats = await _firestore.getCats();
        state = cloudCats;
      } else {
        // Giriş yapılmamışsa boş liste
        state = [];
      }
    } catch (e) {
      debugPrint('CatsProvider: Load error: $e');
      state = [];
    }
  }

  Future<Cat> addCat({
    required String name,
    DateTime? birthDate,
    String? breed,
    String? gender,
    double? weight,
    String? photoPath,
    String? notes,
  }) async {
    final cat = Cat(
      id: _uuid.v4(),
      name: name,
      birthDate: birthDate ?? DateTime.now(),
      breed: breed,
      gender: gender,
      weight: weight,
      photoPath: photoPath,
      notes: notes,
      createdAt: DateTime.now(),
    );

    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveCat(cat);
      state = [cat, ...state];
      return cat;
    } catch (e) {
      debugPrint('CatsProvider: Error saving cat to Firestore: $e');
      rethrow;
    }
  }

  Future<void> updateCat(Cat cat) async {
    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveCat(cat);
      state = state.map((c) => c.id == cat.id ? cat : c).toList();
    } catch (e) {
      debugPrint('CatsProvider: Error updating cat in Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteCat(String id) async {
    try {
      // Sadece Firebase'den sil
      await _firestore.deleteCat(id);
      state = state.where((c) => c.id != id).toList();
    } catch (e) {
      debugPrint('CatsProvider: Error deleting cat from Firestore: $e');
      rethrow;
    }
  }

  // Firebase'den sync et (artık sadece state'i güncelle)
  Future<void> syncFromCloud() async {
    await loadCats();
  }

  Cat? getCatById(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
