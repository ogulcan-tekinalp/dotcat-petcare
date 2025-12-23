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
