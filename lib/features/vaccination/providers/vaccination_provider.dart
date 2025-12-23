import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/vaccination.dart';
import '../../../core/utils/notification_service.dart';

final vaccinationProvider = StateNotifierProvider<VaccinationNotifier, List<Vaccination>>((ref) {
  return VaccinationNotifier();
});

class VaccinationNotifier extends StateNotifier<List<Vaccination>> {
  VaccinationNotifier() : super([]);

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Future<void> loadVaccinations(String catId) async {
    final vaccinations = await _db.getVaccinationsForCat(catId);
    // Merge with existing vaccinations for other cats
    final otherCatVaccinations = state.where((v) => v.catId != catId).toList();
    state = [...otherCatVaccinations, ...vaccinations];
  }

  Future<Vaccination> addVaccination({
    required String catId,
    required String catName,
    required String name,
    required DateTime date,
    DateTime? nextDate,
    String? veterinarian,
    String? notes,
  }) async {
    final vaccination = Vaccination(
      id: _uuid.v4(),
      catId: catId,
      name: name,
      date: date,
      nextDate: nextDate,
      isCompleted: false,
      veterinarian: veterinarian,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _db.insertVaccination(vaccination);

    // Schedule reminder 7 days before next vaccine
    if (nextDate != null) {
      final reminderDate = nextDate.subtract(const Duration(days: 7));
      if (reminderDate.isAfter(DateTime.now())) {
        await NotificationService.instance.scheduleOneTimeReminder(
          id: vaccination.id.hashCode,
          title: 'DOTCAT - Vaccine Reminder',
          body: '$catName - $name vaccine due in 7 days',
          dateTime: reminderDate,
        );
      }
    }

    state = [...state, vaccination];
    return vaccination;
  }

  Future<void> markAsCompleted(String id) async {
    final index = state.indexWhere((v) => v.id == id);
    if (index != -1) {
      final updated = state[index].copyWith(isCompleted: true);
      await _db.updateVaccination(updated);
      await NotificationService.instance.cancelReminder(id.hashCode);
      state = [...state.sublist(0, index), updated, ...state.sublist(index + 1)];
    }
  }

  Future<void> toggleComplete(String id) async {
    final index = state.indexWhere((v) => v.id == id);
    if (index != -1) {
      final current = state[index];
      final updated = current.copyWith(isCompleted: !current.isCompleted);
      await _db.updateVaccination(updated);
      if (updated.isCompleted) {
        await NotificationService.instance.cancelReminder(id.hashCode);
      }
      state = [...state.sublist(0, index), updated, ...state.sublist(index + 1)];
    }
  }

  Future<void> deleteVaccination(String id) async {
    await _db.deleteVaccination(id);
    await NotificationService.instance.cancelReminder(id.hashCode);
    state = state.where((v) => v.id != id).toList();
  }

  List<Vaccination> getUpcomingVaccinations() {
    return state.where((v) => v.isUpcoming && !v.isCompleted).toList();
  }

  List<Vaccination> getOverdueVaccinations() {
    return state.where((v) => v.isOverdue && !v.isCompleted).toList();
  }
}
