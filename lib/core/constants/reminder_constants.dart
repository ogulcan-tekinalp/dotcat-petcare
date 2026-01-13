import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/localization.dart';

/// Hatırlatıcı tipleri
enum ReminderType {
  food,
  medicine,
  vet,
  vaccine,
  grooming,
  exercise,
  dotcatComplete,
}

extension ReminderTypeExtension on ReminderType {
  /// String değerini döndürür (Firestore/SQLite uyumu için)
  String get value {
    switch (this) {
      case ReminderType.food:
        return 'food';
      case ReminderType.medicine:
        return 'medicine';
      case ReminderType.vet:
        return 'vet';
      case ReminderType.vaccine:
        return 'vaccine';
      case ReminderType.grooming:
        return 'grooming';
      case ReminderType.exercise:
        return 'exercise';
      case ReminderType.dotcatComplete:
        return 'dotcat_complete';
    }
  }

  /// Lokalize edilmiş görüntüleme adı
  String get displayName {
    switch (this) {
      case ReminderType.food:
        return AppLocalizations.get('food');
      case ReminderType.medicine:
        return AppLocalizations.get('medicine');
      case ReminderType.vet:
        return AppLocalizations.get('vet_visit');
      case ReminderType.vaccine:
        return AppLocalizations.get('vaccination');
      case ReminderType.grooming:
        return AppLocalizations.get('grooming');
      case ReminderType.exercise:
        return 'Egzersiz';
      case ReminderType.dotcatComplete:
        return 'dotcat Complete';
    }
  }

  /// Tip için ikon
  IconData get icon {
    switch (this) {
      case ReminderType.food:
        return Icons.restaurant_rounded;
      case ReminderType.medicine:
        return Icons.medication_rounded;
      case ReminderType.vet:
        return Icons.local_hospital_rounded;
      case ReminderType.vaccine:
        return Icons.vaccines_rounded;
      case ReminderType.grooming:
        return Icons.content_cut_rounded;
      case ReminderType.exercise:
        return Icons.fitness_center_rounded;
      case ReminderType.dotcatComplete:
        return Icons.pets_rounded;
    }
  }

  /// Tip için renk
  Color get color {
    switch (this) {
      case ReminderType.food:
        return AppColors.food;
      case ReminderType.medicine:
        return AppColors.medicine;
      case ReminderType.vet:
        return AppColors.vet;
      case ReminderType.vaccine:
        return AppColors.vaccine;
      case ReminderType.grooming:
        return AppColors.grooming;
      case ReminderType.exercise:
        return Colors.orange;
      case ReminderType.dotcatComplete:
        return AppColors.dotcat;
    }
  }

  /// Sağlık ile ilgili mi? (tamamlandığında tarih sorulacak)
  bool get isHealthRelated {
    return this == ReminderType.vaccine ||
        this == ReminderType.medicine ||
        this == ReminderType.vet;
  }

  /// Günlük tekrar edecek mi?
  bool get isDailyByDefault {
    return this == ReminderType.food || this == ReminderType.dotcatComplete;
  }

  /// String'den enum'a çevir
  static ReminderType fromString(String value) {
    switch (value) {
      case 'food':
        return ReminderType.food;
      case 'medicine':
        return ReminderType.medicine;
      case 'vet':
        return ReminderType.vet;
      case 'vaccine':
        return ReminderType.vaccine;
      case 'grooming':
        return ReminderType.grooming;
      case 'exercise':
        return ReminderType.exercise;
      case 'dotcat_complete':
        return ReminderType.dotcatComplete;
      default:
        return ReminderType.food;
    }
  }
}

/// Hatırlatıcı frekansları
enum ReminderFrequency {
  once,
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
}

extension ReminderFrequencyExtension on ReminderFrequency {
  /// String değerini döndürür
  String get value {
    switch (this) {
      case ReminderFrequency.once:
        return 'once';
      case ReminderFrequency.daily:
        return 'daily';
      case ReminderFrequency.weekly:
        return 'weekly';
      case ReminderFrequency.monthly:
        return 'monthly';
      case ReminderFrequency.quarterly:
        return 'quarterly';
      case ReminderFrequency.biannual:
        return 'biannual';
      case ReminderFrequency.yearly:
        return 'yearly';
    }
  }

  /// Lokalize edilmiş görüntüleme adı
  String get displayName {
    switch (this) {
      case ReminderFrequency.once:
        return AppLocalizations.get('once');
      case ReminderFrequency.daily:
        return AppLocalizations.get('daily');
      case ReminderFrequency.weekly:
        return AppLocalizations.get('weekly');
      case ReminderFrequency.monthly:
        return AppLocalizations.get('monthly');
      case ReminderFrequency.quarterly:
        return AppLocalizations.get('quarterly');
      case ReminderFrequency.biannual:
        return AppLocalizations.get('biannual');
      case ReminderFrequency.yearly:
        return AppLocalizations.get('yearly');
    }
  }

  /// String'den enum'a çevir
  static ReminderFrequency fromString(String value) {
    switch (value) {
      case 'once':
        return ReminderFrequency.once;
      case 'daily':
        return ReminderFrequency.daily;
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'monthly':
        return ReminderFrequency.monthly;
      case 'quarterly':
        return ReminderFrequency.quarterly;
      case 'biannual':
        return ReminderFrequency.biannual;
      case 'yearly':
        return ReminderFrequency.yearly;
      default:
        return ReminderFrequency.daily;
    }
  }
}

/// Sync durumları (offline-first için)
enum SyncStatus {
  synced,
  pending,
  error,
}

extension SyncStatusExtension on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.error:
        return 'error';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pending;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }
}

