import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/weight_record.dart';
import '../../../core/services/firestore_service.dart';

final weightProvider = StateNotifierProvider<WeightNotifier, List<WeightRecord>>((ref) {
  return WeightNotifier();
});

class WeightNotifier extends StateNotifier<List<WeightRecord>> {
  WeightNotifier() : super([]);

  final _firestore = FirestoreService();
  final _uuid = const Uuid();

  Future<void> loadWeightRecords(String catId) async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        final allWeights = await _firestore.getWeights();
        final catWeights = allWeights.where((w) => w.catId == catId).toList();
        // Tarihe göre sırala (en yeni önce)
        catWeights.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        state = catWeights;
      } else {
        state = [];
      }
    } catch (e) {
      debugPrint('WeightProvider: Load error: $e');
      state = [];
    }
  }

  Future<WeightRecord> addWeightRecord({
    required String catId,
    required double weight,
    String? notes,
  }) async {
    final record = WeightRecord(
      id: _uuid.v4(),
      petId: catId,
      weight: weight,
      notes: notes,
      recordedAt: DateTime.now(),
    );

    try {
      // Firebase'e kaydet
      await _firestore.saveWeight(record);
      state = [record, ...state];
      return record;
    } catch (e) {
      debugPrint('WeightProvider: Error saving weight to Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteWeightRecord(String id) async {
    try {
      // Firebase'den sil
      await _firestore.deleteWeight(id);
      state = state.where((r) => r.id != id).toList();
    } catch (e) {
      debugPrint('WeightProvider: Error deleting weight from Firestore: $e');
      rethrow;
    }
  }

  WeightRecord? getLatestWeight() {
    if (state.isEmpty) return null;
    return state.first;
  }

  double? getWeightChange() {
    if (state.length < 2) return null;
    return state[0].weight - state[1].weight;
  }

  List<WeightRecord> getLast6Months() {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    return state.where((r) => r.recordedAt.isAfter(sixMonthsAgo)).toList().reversed.toList();
  }
}
