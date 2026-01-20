import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/dog.dart';
import '../../../core/services/firestore_service.dart';

final dogsProvider = StateNotifierProvider<DogsNotifier, List<Dog>>((ref) {
  return DogsNotifier();
});

final selectedDogProvider = StateProvider<Dog?>((ref) => null);

class DogsNotifier extends StateNotifier<List<Dog>> {
  DogsNotifier() : super([]) {
    loadDogs();
  }

  final _firestore = FirestoreService();
  final _uuid = const Uuid();

  Future<void> loadDogs() async {
    // Sadece cloud'dan yükle (kullanıcı giriş yapmışsa)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        final cloudDogs = await _firestore.getDogs();
        state = cloudDogs;
      } else {
        // Giriş yapılmamışsa boş liste
        state = [];
      }
    } catch (e) {
      debugPrint('DogsProvider: Load error: $e');
      state = [];
    }
  }

  Future<Dog> addDog({
    required String name,
    DateTime? birthDate,
    String? breed,
    String? gender,
    double? weight,
    String? size,
    String? photoPath,
    String? notes,
  }) async {
    final dog = Dog(
      id: _uuid.v4(),
      name: name,
      birthDate: birthDate ?? DateTime.now(),
      breed: breed,
      gender: gender,
      weight: weight,
      size: size,
      photoPath: photoPath,
      notes: notes,
      createdAt: DateTime.now(),
    );

    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveDog(dog);
      state = [dog, ...state];
      return dog;
    } catch (e) {
      debugPrint('DogsProvider: Error saving dog to Firestore: $e');
      rethrow;
    }
  }

  Future<void> updateDog(Dog dog) async {
    try {
      // Sadece Firebase'e kaydet
      await _firestore.saveDog(dog);
      state = state.map((d) => d.id == dog.id ? dog : d).toList();
    } catch (e) {
      debugPrint('DogsProvider: Error updating dog in Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteDog(String id) async {
    try {
      // Sadece Firebase'den sil
      await _firestore.deleteDog(id);
      state = state.where((d) => d.id != id).toList();
    } catch (e) {
      debugPrint('DogsProvider: Error deleting dog from Firestore: $e');
      rethrow;
    }
  }

  // Firebase'den sync et (artık sadece state'i güncelle)
  Future<void> syncFromCloud() async {
    await loadDogs();
  }

  Dog? getDogById(String id) {
    try {
      return state.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
