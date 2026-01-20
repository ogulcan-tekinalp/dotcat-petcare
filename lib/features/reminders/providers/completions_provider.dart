import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/reminder_completion.dart';

/// Merkezi completion state provider - tüm ekranlar bu state'i kullanır
final completionsProvider = StateNotifierProvider<CompletionsNotifier, CompletionsState>((ref) {
  return CompletionsNotifier();
});

class CompletionsState {
  final Set<String> completedDates;
  final Map<String, DateTime> completionTimes;
  final bool isLoading;
  final String? error;

  CompletionsState({
    required this.completedDates,
    required this.completionTimes,
    this.isLoading = false,
    this.error,
  });

  CompletionsState copyWith({
    Set<String>? completedDates,
    Map<String, DateTime>? completionTimes,
    bool? isLoading,
    String? error,
  }) {
    return CompletionsState(
      completedDates: completedDates ?? this.completedDates,
      completionTimes: completionTimes ?? this.completionTimes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class CompletionsNotifier extends StateNotifier<CompletionsState> {
  CompletionsNotifier() : super(CompletionsState(
    completedDates: {},
    completionTimes: {},
  )) {
    _loadCompletions();
    _setupRealtimeSync();
  }

  final _firestore = FirestoreService();
  StreamSubscription<List<ReminderCompletion>>? _completionsSubscription;

  void _setupRealtimeSync() {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      _completionsSubscription = _firestore.getCompletionsStream().listen((completions) {
        state = CompletionsState(
          completedDates: completions.map((c) => c.id).toSet(),
          completionTimes: {for (var c in completions) c.id: c.completedAt},
          isLoading: false,
        );
      }, onError: (error) {
        debugPrint('CompletionsNotifier: Realtime sync error: $error');
        state = state.copyWith(error: error.toString());
      });
    }
  }

  Future<void> _loadCompletions() async {
    state = state.copyWith(isLoading: true);
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        // Firebase'den çek
        final cloudCompletions = await _firestore.getCompletions();
        state = CompletionsState(
          completedDates: cloudCompletions.map((c) => c.id).toSet(),
          completionTimes: {for (var c in cloudCompletions) c.id: c.completedAt},
          isLoading: false,
        );
      } else {
        // Local DB'den çek (offline/anonim durumlar için fallback)
        final completions = await DatabaseHelper.instance.getAllCompletedDates();
        final completionTimes = await DatabaseHelper.instance.getCompletionTimes();
        state = CompletionsState(
          completedDates: completions,
          completionTimes: completionTimes,
          isLoading: false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('CompletionsNotifier: Load error: $e');
      debugPrint('CompletionsNotifier: stackTrace: $stackTrace');
      // Hata durumunda local DB'den çek (fallback)
      try {
        final completions = await DatabaseHelper.instance.getAllCompletedDates();
        final completionTimes = await DatabaseHelper.instance.getCompletionTimes();
        state = CompletionsState(
          completedDates: completions,
          completionTimes: completionTimes,
          isLoading: false,
          error: e.toString(),
        );
      } catch (e2) {
        debugPrint('CompletionsNotifier: Local DB fallback error: $e2');
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> refresh() async {
    await _loadCompletions();
  }

  Future<void> saveCompletion(ReminderCompletion completion) async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await _firestore.saveCompletion(completion);
        // Real-time stream otomatik güncelleyecek
      } else {
        // Local DB'ye kaydet
        await DatabaseHelper.instance.insertCompletion(
          completion.reminderId,
          completion.completedDate,
        );
        // State'i manuel güncelle
        final newDates = Set<String>.from(state.completedDates)..add(completion.id);
        final newTimes = Map<String, DateTime>.from(state.completionTimes)
          ..[completion.id] = completion.completedAt;
        state = state.copyWith(
          completedDates: newDates,
          completionTimes: newTimes,
        );
      }

      // Show ad with 30% probability after completing a reminder
      await AdService.instance.onReminderCompleted();
    } catch (e) {
      debugPrint('CompletionsNotifier: saveCompletion error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCompletion(String completionId, String reminderId, DateTime date) async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await _firestore.deleteCompletion(completionId);
        // Real-time stream otomatik güncelleyecek
      } else {
        // Local DB'den sil
        await DatabaseHelper.instance.deleteCompletion(reminderId, date);
        // State'i manuel güncelle
        final newDates = Set<String>.from(state.completedDates)..remove(completionId);
        final newTimes = Map<String, DateTime>.from(state.completionTimes)..remove(completionId);
        state = state.copyWith(
          completedDates: newDates,
          completionTimes: newTimes,
        );
      }
    } catch (e) {
      debugPrint('CompletionsNotifier: deleteCompletion error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _completionsSubscription?.cancel();
    super.dispose();
  }
}

