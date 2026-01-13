import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore Timestamp için extension methods
///
/// Firestore Timestamp ve DateTime arasında tutarlı dönüşümler sağlar.
extension FirestoreTimestampExtension on Timestamp {
  /// Timestamp'i DateTime'a çevir
  DateTime toDateTime() => toDate();

  /// Timestamp'i ISO8601 string'e çevir
  String toIso8601String() => toDate().toIso8601String();

  /// Timestamp'i sadece tarih kısmı (YYYY-MM-DD) olarak string'e çevir
  String toDateString() => toDate().toIso8601String().split('T')[0];

  /// Timestamp'i local timezone'da formatlı string'e çevir
  String toFormattedString([String format = 'dd/MM/yyyy HH:mm']) {
    final date = toDate();
    // Bu format için intl paketi kullanılabilir, şimdilik basit format
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

/// DateTime için Firestore extension
extension DateTimeFirestoreExtension on DateTime {
  /// DateTime'ı Firestore Timestamp'e çevir
  Timestamp toFirestoreTimestamp() => Timestamp.fromDate(this);

  /// DateTime'ı sadece tarih kısmı (YYYY-MM-DD) olarak string'e çevir
  String toDateString() => toIso8601String().split('T')[0];

  /// DateTime'ı sadece tarih kısmı olarak DateTime'a çevir (saat sıfırlanır)
  DateTime toDateOnly() => DateTime(year, month, day);
}

/// Map'ten Timestamp safe extraction
extension MapTimestampExtension on Map<String, dynamic> {
  /// Map'ten Timestamp veya DateTime çıkar
  /// Firestore'dan gelen data bazen Timestamp, bazen DateTime olabiliyor
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      // ISO8601 string parse et
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Map'ten date string (YYYY-MM-DD) çıkar
  String? getDateString(String key) {
    final dateTime = getDateTime(key);
    return dateTime?.toDateString();
  }

  /// Map'e DateTime'ı Timestamp olarak ekle (Firestore için)
  void setDateTime(String key, DateTime? dateTime) {
    if (dateTime != null) {
      this[key] = Timestamp.fromDate(dateTime);
    } else {
      this[key] = null;
    }
  }

  /// Map'e DateTime'ı ISO8601 string olarak ekle (SQLite için)
  void setDateTimeAsString(String key, DateTime? dateTime) {
    if (dateTime != null) {
      this[key] = dateTime.toIso8601String();
    } else {
      this[key] = null;
    }
  }
}

/// Firestore document data dönüşümleri için helper
class FirestoreDataConverter {
  /// Firestore document'ten DateTime çıkar (Timestamp veya String handle eder)
  static DateTime? extractDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// DateTime'ı Firestore'a kaydetmek için Timestamp'e çevir
  static Timestamp? dateTimeToTimestamp(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  /// Timestamp'i SQLite için ISO8601 string'e çevir
  static String? timestampToString(Timestamp? timestamp) {
    if (timestamp == null) return null;
    return timestamp.toDate().toIso8601String();
  }

  /// Date-only string (YYYY-MM-DD) al
  static String? getDateString(dynamic value) {
    final dateTime = extractDateTime(value);
    if (dateTime == null) return null;
    return dateTime.toIso8601String().split('T')[0];
  }
}
