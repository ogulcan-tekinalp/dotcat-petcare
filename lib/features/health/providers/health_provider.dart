import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/health_note.dart';

final healthProvider = StateNotifierProvider<HealthNotifier, List<HealthNote>>((ref) {
  return HealthNotifier();
});

class HealthNotifier extends StateNotifier<List<HealthNote>> {
  HealthNotifier() : super([]);

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Future<void> loadHealthNotes(String catId) async {
    final notes = await _db.getHealthNotesForCat(catId);
    state = notes;
  }

  Future<HealthNote> addHealthNote({
    required String catId,
    required String title,
    required String type,
    String? description,
    required DateTime date,
    String? veterinarian,
  }) async {
    final note = HealthNote(
      id: _uuid.v4(),
      catId: catId,
      title: title,
      type: type,
      description: description,
      date: date,
      veterinarian: veterinarian,
      createdAt: DateTime.now(),
    );

    await _db.insertHealthNote(note);
    state = [note, ...state];
    return note;
  }

  Future<void> deleteHealthNote(String id) async {
    await _db.deleteHealthNote(id);
    state = state.where((n) => n.id != id).toList();
  }

  List<HealthNote> getRecentNotes({int limit = 5}) {
    return state.take(limit).toList();
  }
}
