import 'package:intl/intl.dart';
import 'localization.dart';

class DateHelper {
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatShortDate(DateTime date) {
    return AppLocalizations.formatLocalizedDate(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inDays > 30) {
        return '${(absDiff.inDays / 30).floor()} ay once';
      } else if (absDiff.inDays > 0) {
        return '${absDiff.inDays} gun once';
      } else if (absDiff.inHours > 0) {
        return '${absDiff.inHours} saat once';
      } else {
        return '${absDiff.inMinutes} dakika once';
      }
    } else {
      if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} ay sonra';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} gun sonra';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat sonra';
      } else {
        return '${difference.inMinutes} dakika sonra';
      }
    }
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  static bool isUpcoming(DateTime date, {int days = 7}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    return date.isAfter(now) && date.isBefore(future);
  }

  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  /// Güvenli ay ekleme - gün taşmasını önler
  /// Örnek: 31 Ocak + 1 ay = 28/29 Şubat (ayın son günü)
  static DateTime addMonths(DateTime date, int months) {
    int newYear = date.year;
    int newMonth = date.month + months;
    
    // Yıl taşmasını hesapla
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }
    
    // Ayın son gününü bul
    final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
    
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  /// Güvenli yıl ekleme - 29 Şubat durumunu yönetir
  static DateTime addYears(DateTime date, int years) {
    final newYear = date.year + years;
    
    // 29 Şubat kontrolü
    if (date.month == 2 && date.day == 29) {
      final isLeapYear = (newYear % 4 == 0 && newYear % 100 != 0) || (newYear % 400 == 0);
      if (!isLeapYear) {
        return DateTime(newYear, 2, 28, date.hour, date.minute, date.second);
      }
    }
    
    return DateTime(newYear, date.month, date.day, date.hour, date.minute, date.second);
  }

  /// Frequency'ye göre sonraki tarihi hesapla
  static DateTime? calculateNextDate(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
        return addMonths(date, 1);
      case 'quarterly':
        return addMonths(date, 3);
      case 'biannual':
        return addMonths(date, 6);
      case 'yearly':
        return addYears(date, 1);
      default:
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7));
          if (days != null) return date.add(Duration(days: days));
        }
        return null;
    }
  }

  static String getAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    
    if (months < 0 || (months == 0 && now.day < birthDate.day)) {
      years--;
      months += 12;
    }
    if (now.day < birthDate.day) {
      months--;
      if (months < 0) months = 0;
    }
    
    // Türkçe için "yaş" formatı
    if (AppLocalizations.currentLanguage == AppLanguage.tr) {
      if (years > 0) {
        if (months >= 6) {
          // 6 ay ve üzeri ise yarım yaş ekle
          return '${years + 0.5} yaş';
        }
        return '$years yaş';
      } else if (months > 0) {
        return '$months aylık';
      } else {
        final days = now.difference(birthDate).inDays;
        return '$days günlük';
      }
    }
    
    // Diğer diller için eski format
    if (years > 0) {
      if (months > 0) {
        return '$years ${AppLocalizations.get('years')} $months ${AppLocalizations.get('months')}';
      }
      return '$years ${AppLocalizations.get('years')}';
    } else if (months > 0) {
      return '$months ${AppLocalizations.get('months')}';
    } else {
      final days = now.difference(birthDate).inDays;
      return '$days ${AppLocalizations.get('days')}';
    }
  }
}
