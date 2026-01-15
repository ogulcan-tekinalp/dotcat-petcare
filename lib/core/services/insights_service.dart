import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/cat.dart';
import '../../data/models/reminder.dart';
import '../../data/models/weight_record.dart';
import '../utils/localization.dart';
import '../theme/app_theme.dart';

/// Insight türleri
enum InsightType {
  warning,    // Dikkat gerektiren durum
  suggestion, // Öneri
  achievement,// Başarı/tebrik
  info,       // Bilgilendirme
}

/// Insight önceliği
enum InsightPriority {
  high,
  medium,
  low,
}

/// Tek bir insight
class Insight {
  final String id;
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final String? actionRoute;
  final Map<String, dynamic>? actionData;
  final DateTime createdAt;

  Insight({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.actionRoute,
    this.actionData,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Kedi için ideal kilo aralığı
class IdealWeightRange {
  final double min;
  final double max;
  final String category; // underweight, normal, overweight

  IdealWeightRange({
    required this.min,
    required this.max,
    required this.category,
  });
}

/// Kilo trendi
enum WeightTrend {
  increasing,
  stable,
  decreasing,
  insufficient, // Yeterli veri yok
}

/// Akıllı Öneriler ve Sağlık İçgörüleri Servisi
class InsightsService {
  static final InsightsService instance = InsightsService._init();

  String? _cachedCatType;
  String? _cachedNotificationTime;

  InsightsService._init();

  /// Onboarding preferences'ları oku
  Future<void> _loadPreferences() async {
    if (_cachedCatType != null) return; // Already loaded

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedCatType = prefs.getString('onboarding_cat_type');
      _cachedNotificationTime = prefs.getString('onboarding_notification_time');
      debugPrint('InsightsService: Loaded preferences - catType: $_cachedCatType, notificationTime: $_cachedNotificationTime');
    } catch (e) {
      debugPrint('InsightsService: Error loading preferences: $e');
    }
  }

  /// Tüm kediler için insights üret
  Future<List<Insight>> generateInsights({
    required List<Cat> cats,
    required List<Reminder> reminders,
    required List<WeightRecord> weightRecords,
    required Set<String> completedDates,
  }) async {
    // Load preferences first
    await _loadPreferences();

    final insights = <Insight>[];

    for (final cat in cats) {
      final catReminders = reminders.where((r) => r.catId == cat.id).toList();
      final catWeights = weightRecords.where((w) => w.catId == cat.id).toList();

      // Kilo ile ilgili insights
      insights.addAll(_generateWeightInsights(cat, catWeights));

      // Aşı ile ilgili insights
      insights.addAll(_generateVaccineInsights(cat, catReminders));

      // Yaş ile ilgili insights
      insights.addAll(_generateAgeInsights(cat, catReminders));

      // Aktivite/tamamlama ile ilgili insights
      insights.addAll(_generateActivityInsights(cat, catReminders, completedDates));

      // Cat type-specific insights (based on onboarding)
      insights.addAll(_generateCatTypeSpecificInsights(cat, catReminders));
    }

    // Genel insights
    insights.addAll(_generateGeneralInsights(cats, reminders));

    // Mevsimsel insights
    insights.addAll(generateSeasonalInsights(cats));

    // Önceliğe göre sırala
    insights.sort((a, b) {
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return insights;
  }
  
  // ============ WEIGHT INSIGHTS ============
  
  List<Insight> _generateWeightInsights(Cat cat, List<WeightRecord> weights) {
    final insights = <Insight>[];
    
    if (weights.isEmpty) {
      // Hiç kilo kaydı yok
      insights.add(Insight(
        id: 'weight_no_record_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.medium,
        title: '${cat.name} ${AppLocalizations.get('no_weight_record')}',
        description: AppLocalizations.get('weight_tracking_benefit'),
        icon: Icons.monitor_weight_outlined,
        color: AppColors.warning,
        actionLabel: AppLocalizations.get('add_weight'),
        actionRoute: '/weight/add',
        actionData: {'catId': cat.id},
      ));
      return insights;
    }
    
    // Son kilo
    final sortedWeights = List<WeightRecord>.from(weights)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latestWeight = sortedWeights.first;
    
    // İdeal kilo kontrolü
    final idealRange = getIdealWeightRange(cat);
    final currentWeight = latestWeight.weight;
    
    if (currentWeight < idealRange.min) {
      insights.add(Insight(
        id: 'weight_underweight_${cat.id}',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_underweight_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_underweight_description')
            .replaceAll('{weight}', currentWeight.toStringAsFixed(1))
            .replaceAll('{min}', idealRange.min.toStringAsFixed(1))
            .replaceAll('{max}', idealRange.max.toStringAsFixed(1)),
        icon: Icons.trending_down_rounded,
        color: AppColors.error,
        actionLabel: AppLocalizations.get('insight_underweight_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'vet'},
      ));
    } else if (currentWeight > idealRange.max) {
      insights.add(Insight(
        id: 'weight_overweight_${cat.id}',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_overweight_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_overweight_description')
            .replaceAll('{weight}', currentWeight.toStringAsFixed(1))
            .replaceAll('{min}', idealRange.min.toStringAsFixed(1))
            .replaceAll('{max}', idealRange.max.toStringAsFixed(1)),
        icon: Icons.trending_up_rounded,
        color: AppColors.warning,
        actionLabel: AppLocalizations.get('insight_underweight_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'vet'},
      ));
    }
    
    // Kilo trendi
    if (weights.length >= 3) {
      final trend = calculateWeightTrend(weights);
      final trendChange = calculateWeightChange(weights);
      
      if (trend == WeightTrend.decreasing && trendChange.abs() > 0.5) {
        insights.add(Insight(
          id: 'weight_decreasing_${cat.id}',
          type: InsightType.warning,
          priority: InsightPriority.medium,
          title: AppLocalizations.get('insight_weight_decreasing_title').replaceAll('{catName}', cat.name),
          description: AppLocalizations.get('insight_weight_decreasing_description')
              .replaceAll('{change}', trendChange.abs().toStringAsFixed(1)),
          icon: Icons.trending_down_rounded,
          color: AppColors.warning,
        ));
      } else if (trend == WeightTrend.increasing && trendChange > 0.5) {
        final description = currentWeight > idealRange.max
            ? AppLocalizations.get('insight_weight_increasing_description_warning')
            : AppLocalizations.get('insight_weight_increasing_description_normal');
        insights.add(Insight(
          id: 'weight_increasing_${cat.id}',
          type: InsightType.info,
          priority: InsightPriority.low,
          title: AppLocalizations.get('insight_weight_increasing_title').replaceAll('{catName}', cat.name),
          description: description.replaceAll('{change}', trendChange.toStringAsFixed(1)),
          icon: Icons.trending_up_rounded,
          color: currentWeight > idealRange.max ? AppColors.warning : AppColors.info,
        ));
      }
    }
    
    // Eski kilo kaydı uyarısı
    final daysSinceLastWeight = DateTime.now().difference(latestWeight.recordedAt).inDays;
    if (daysSinceLastWeight > 30) {
      insights.add(Insight(
        id: 'weight_outdated_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.low,
        title: '${cat.name} ${AppLocalizations.get('weight_update_needed')}',
        description: '${AppLocalizations.get('last_weight_days_ago').replaceAll('{days}', daysSinceLastWeight.toString())}',
        icon: Icons.update_rounded,
        color: AppColors.info,
        actionLabel: AppLocalizations.get('add_weight'),
        actionRoute: '/weight/add',
        actionData: {'catId': cat.id},
      ));
    }
    
    return insights;
  }
  
  /// İdeal kilo aralığını hesapla
  IdealWeightRange getIdealWeightRange(Cat cat) {
    final ageInMonths = cat.ageInMonths;
    
    // Yavru kediler (0-12 ay)
    if (ageInMonths < 12) {
      if (ageInMonths < 2) {
        return IdealWeightRange(min: 0.2, max: 0.5, category: 'kitten');
      } else if (ageInMonths < 4) {
        return IdealWeightRange(min: 0.5, max: 1.5, category: 'kitten');
      } else if (ageInMonths < 6) {
        return IdealWeightRange(min: 1.5, max: 2.5, category: 'kitten');
      } else if (ageInMonths < 9) {
        return IdealWeightRange(min: 2.5, max: 3.5, category: 'kitten');
      } else {
        return IdealWeightRange(min: 3.0, max: 4.5, category: 'kitten');
      }
    }
    
    // Yetişkin kediler - cins bazlı (TODO: breed-specific ranges)
    // Genel olarak 3.5-5.5 kg ideal kabul edilir
    
    // Yaşlı kediler (7+ yaş) biraz daha düşük olabilir
    if (ageInMonths >= 84) {
      return IdealWeightRange(min: 3.0, max: 5.0, category: 'senior');
    }
    
    // Normal yetişkin
    return IdealWeightRange(min: 3.5, max: 5.5, category: 'adult');
  }
  
  /// Kilo trendini hesapla
  WeightTrend calculateWeightTrend(List<WeightRecord> weights) {
    if (weights.length < 3) return WeightTrend.insufficient;
    
    final sorted = List<WeightRecord>.from(weights)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    
    // Son 3 kaydı al
    final recent = sorted.length > 5 ? sorted.sublist(sorted.length - 5) : sorted;
    
    // Basit lineer trend analizi
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < recent.length; i++) {
      sumX += i;
      sumY += recent[i].weight;
      sumXY += i * recent[i].weight;
      sumX2 += i * i;
    }
    
    final n = recent.length;
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    
    if (slope > 0.05) return WeightTrend.increasing;
    if (slope < -0.05) return WeightTrend.decreasing;
    return WeightTrend.stable;
  }
  
  /// Kilo değişimini hesapla (en eski ile en yeni arasındaki fark)
  double calculateWeightChange(List<WeightRecord> weights) {
    if (weights.length < 2) return 0;
    
    final sorted = List<WeightRecord>.from(weights)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    
    return sorted.last.weight - sorted.first.weight;
  }
  
  // ============ VACCINE INSIGHTS ============
  
  List<Insight> _generateVaccineInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];
    
    final vaccineReminders = reminders.where((r) => r.type == 'vaccine').toList();
    
    if (vaccineReminders.isEmpty && cat.ageInMonths < 12) {
      // Yavru kedi için aşı uyarısı
      insights.add(Insight(
        id: 'vaccine_kitten_${cat.id}',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_vaccine_kitten_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_vaccine_kitten_description'),
        icon: Icons.vaccines_rounded,
        color: AppColors.error,
        actionLabel: AppLocalizations.get('insight_vaccine_kitten_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'vaccine'},
      ));
    }
    
    // Yaklaşan aşılar için hatırlatma
    final now = DateTime.now();
    for (final vaccine in vaccineReminders) {
      if (vaccine.nextDate != null) {
        final daysUntil = vaccine.nextDate!.difference(now).inDays;
        if (daysUntil > 0 && daysUntil <= 14) {
          insights.add(Insight(
            id: 'vaccine_upcoming_${vaccine.id}',
            type: InsightType.info,
            priority: InsightPriority.medium,
            title: AppLocalizations.get('insight_vaccine_upcoming_title').replaceAll('{title}', vaccine.title),
            description: AppLocalizations.get('insight_vaccine_upcoming_description')
                .replaceAll('{catName}', cat.name)
                .replaceAll('{title}', vaccine.title)
                .replaceAll('{days}', daysUntil.toString()),
            icon: Icons.event_rounded,
            color: AppColors.vaccine,
          ));
        }
      }
    }
    
    return insights;
  }
  
  // ============ AGE INSIGHTS ============
  
  List<Insight> _generateAgeInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];
    final ageInMonths = cat.ageInMonths;
    
    // Yaşlı kedi bakımı önerileri
    if (ageInMonths >= 84) { // 7+ yaş
      final hasVetCheckup = reminders.any((r) => r.type == 'vet' && r.frequency != 'once');
      
      if (!hasVetCheckup) {
        insights.add(Insight(
          id: 'senior_checkup_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.medium,
          title: AppLocalizations.get('insight_senior_checkup_title').replaceAll('{catName}', cat.name),
          description: AppLocalizations.get('insight_senior_checkup_description'),
          icon: Icons.elderly_rounded,
          color: AppColors.info,
          actionLabel: AppLocalizations.get('insight_senior_checkup_action'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'vet', 'frequency': 'biannual'},
        ));
      }
    }
    
    // Yavru kedi gelişim aşamaları
    if (ageInMonths == 2) {
      insights.add(Insight(
        id: 'kitten_milestone_2mo_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_kitten_2months_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_kitten_2months_description'),
        icon: Icons.cake_rounded,
        color: AppColors.success,
      ));
    } else if (ageInMonths == 6) {
      insights.add(Insight(
        id: 'kitten_milestone_6mo_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_kitten_6months_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_kitten_6months_description'),
        icon: Icons.cake_rounded,
        color: AppColors.success,
      ));
    } else if (ageInMonths == 12) {
      insights.add(Insight(
        id: 'cat_birthday_${cat.id}',
        type: InsightType.achievement,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_cat_1year_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_cat_1year_description').replaceAll('{catName}', cat.name),
        icon: Icons.celebration_rounded,
        color: AppColors.success,
      ));
    }
    
    return insights;
  }
  
  // ============ ACTIVITY INSIGHTS ============
  
  List<Insight> _generateActivityInsights(Cat cat, List<Reminder> reminders, Set<String> completedDates) {
    final insights = <Insight>[];
    
    // Günlük tamamlama oranı
    final dailyReminders = reminders.where((r) => r.frequency == 'daily' && r.isActive).toList();
    
    if (dailyReminders.isNotEmpty) {
      // Son 7 günün tamamlama oranını hesapla
      final now = DateTime.now();
      int completedCount = 0;
      int totalCount = 0;
      
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        
        for (final reminder in dailyReminders) {
          totalCount++;
          final key = '${reminder.id}_$dateStr';
          if (completedDates.contains(key)) {
            completedCount++;
          }
        }
      }
      
      if (totalCount > 0) {
        final rate = completedCount / totalCount;
        
        if (rate >= 0.9) {
          insights.add(Insight(
            id: 'streak_excellent_${cat.id}',
            type: InsightType.achievement,
            priority: InsightPriority.low,
            title: AppLocalizations.get('insight_streak_excellent_title'),
            description: AppLocalizations.get('insight_streak_excellent_description')
                .replaceAll('{catName}', cat.name)
                .replaceAll('{rate}', (rate * 100).toInt().toString()),
            icon: Icons.star_rounded,
            color: AppColors.success,
          ));
        } else if (rate < 0.5) {
          insights.add(Insight(
            id: 'streak_low_${cat.id}',
            type: InsightType.suggestion,
            priority: InsightPriority.medium,
            title: AppLocalizations.get('insight_streak_low_title'),
            description: AppLocalizations.get('insight_streak_low_description')
                .replaceAll('{catName}', cat.name)
                .replaceAll('{rate}', (rate * 100).toInt().toString()),
            icon: Icons.notification_important_rounded,
            color: AppColors.warning,
          ));
        }
      }
    }
    
    return insights;
  }
  
  // ============ GENERAL INSIGHTS ============
  
  List<Insight> _generateGeneralInsights(List<Cat> cats, List<Reminder> reminders) {
    final insights = <Insight>[];
    
    // Hiç kedi yoksa
    if (cats.isEmpty) {
      insights.add(Insight(
        id: 'no_cats',
        type: InsightType.suggestion,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_no_cats_title'),
        description: AppLocalizations.get('insight_no_cats_description'),
        icon: Icons.pets_rounded,
        color: AppColors.primary,
        actionLabel: AppLocalizations.get('insight_no_cats_action'),
        actionRoute: '/cat/add',
      ));
    }
    
    // Gecikmiş hatırlatıcı sayısı
    final now = DateTime.now();
    final overdueCount = reminders.where((r) {
      if (!r.isActive || r.isCompleted) return false;
      if (r.nextDate == null) return false;
      return r.nextDate!.isBefore(now);
    }).length;
    
    if (overdueCount > 3) {
      insights.add(Insight(
        id: 'overdue_many',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_overdue_many_title').replaceAll('{count}', overdueCount.toString()),
        description: AppLocalizations.get('insight_overdue_many_description'),
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        actionLabel: AppLocalizations.get('insight_overdue_many_action'),
        actionRoute: '/home',
      ));
    }
    
    
    // Sağlık bakım önerileri
    insights.addAll(_generateHealthCareInsights(cats, reminders));
    
    return insights;
  }
  
  // ============ CAT TYPE-SPECIFIC INSIGHTS ============
  // Onboarding sırasında belirlenen kedi tipine göre özel öneriler

  List<Insight> _generateCatTypeSpecificInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];

    // ALWAYS use actual age - ignore onboarding preferences
    final ageInMonths = cat.ageInMonths;
    final catType = ageInMonths < 12 ? 'kitten' : (ageInMonths >= 84 ? 'senior' : 'adult');

    switch (catType) {
      case 'kitten':
        insights.addAll(_generateKittenSpecificInsights(cat, reminders));
        break;
      case 'senior':
        insights.addAll(_generateSeniorSpecificInsights(cat, reminders));
        break;
      case 'adult':
      default:
        insights.addAll(_generateAdultSpecificInsights(cat, reminders));
        break;
    }

    return insights;
  }

  /// Yavru kedi (kitten) özel önerileri
  List<Insight> _generateKittenSpecificInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];

    // Oyun ve enerji
    final hasPlayReminder = reminders.any((r) =>
      r.title.toLowerCase().contains('oyun') ||
      r.title.toLowerCase().contains('play')
    );

    if (!hasPlayReminder) {
      insights.add(Insight(
        id: 'kitten_play_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_kitten_play_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_kitten_play_description'),
        icon: Icons.sports_esports_rounded,
        color: AppColors.primary,
        actionLabel: AppLocalizations.get('insight_kitten_play_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'other', 'title': 'Oyun zamanı'},
      ));
    }

    // Sosyalleşme
    if (cat.ageInMonths >= 2 && cat.ageInMonths <= 7) {
      insights.add(Insight(
        id: 'kitten_socialization_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_kitten_socialization_title'),
        description: AppLocalizations.get('insight_kitten_socialization_description').replaceAll('{catName}', cat.name),
        icon: Icons.group_rounded,
        color: AppColors.info,
      ));
    }

    // Yavru mama kontrolü
    final hasFoodReminder = reminders.any((r) =>
      r.type == 'food' ||
      r.title.toLowerCase().contains('mama') ||
      r.title.toLowerCase().contains('food')
    );

    if (!hasFoodReminder) {
      insights.add(Insight(
        id: 'kitten_food_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_kitten_food_title'),
        description: AppLocalizations.get('insight_kitten_food_description').replaceAll('{catName}', cat.name),
        icon: Icons.restaurant_rounded,
        color: AppColors.food,
        actionLabel: AppLocalizations.get('insight_kitten_food_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'food'},
      ));
    }

    return insights;
  }

  /// Yetişkin kedi (adult) özel önerileri
  List<Insight> _generateAdultSpecificInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];

    // Düzenli egzersiz
    final hasExerciseReminder = reminders.any((r) =>
      r.title.toLowerCase().contains('egzersiz') ||
      r.title.toLowerCase().contains('exercise') ||
      r.title.toLowerCase().contains('oyun') ||
      r.title.toLowerCase().contains('play')
    );

    if (!hasExerciseReminder && cat.ageInMonths >= 12 && cat.ageInMonths < 84) {
      insights.add(Insight(
        id: 'adult_exercise_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_adult_exercise_title').replaceAll('{catName}', cat.name),
        description: AppLocalizations.get('insight_adult_exercise_description'),
        icon: Icons.fitness_center_rounded,
        color: AppColors.info,
        actionLabel: AppLocalizations.get('add_reminder'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'other', 'title': 'Egzersiz/Oyun'},
      ));
    }

    // Su tüketimi
    final hasWaterReminder = reminders.any((r) =>
      r.title.toLowerCase().contains('su') ||
      r.title.toLowerCase().contains('water')
    );

    if (!hasWaterReminder) {
      insights.add(Insight(
        id: 'adult_water_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_adult_water_title'),
        description: AppLocalizations.get('insight_adult_water_description').replaceAll('{catName}', cat.name),
        icon: Icons.water_drop_rounded,
        color: AppColors.info,
      ));
    }

    return insights;
  }

  /// Yaşlı kedi (senior) özel önerileri
  List<Insight> _generateSeniorSpecificInsights(Cat cat, List<Reminder> reminders) {
    final insights = <Insight>[];

    // Eklem sağlığı
    insights.add(Insight(
      id: 'senior_joint_health_${cat.id}',
      type: InsightType.info,
      priority: InsightPriority.medium,
      title: AppLocalizations.get('insight_senior_joint_title').replaceAll('{catName}', cat.name),
      description: AppLocalizations.get('insight_senior_joint_description'),
      icon: Icons.accessibility_new_rounded,
      color: AppColors.warning,
    ));

    // Düzenli veteriner kontrolü
    final hasRegularVet = reminders.any((r) =>
      r.type == 'vet' && (r.frequency == 'biannual' || r.frequency == 'monthly')
    );

    if (!hasRegularVet) {
      insights.add(Insight(
        id: 'senior_vet_checkup_${cat.id}',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_senior_vet_title'),
        description: AppLocalizations.get('insight_senior_vet_description').replaceAll('{catName}', cat.name),
        icon: Icons.medical_services_rounded,
        color: AppColors.vet,
        actionLabel: AppLocalizations.get('insight_senior_vet_action'),
        actionRoute: '/reminder/add',
        actionData: {'catId': cat.id, 'type': 'vet', 'frequency': 'biannual'},
      ));
    }

    // Özel yaşlı mama
    final hasSeniorFood = reminders.any((r) =>
      r.title.toLowerCase().contains('yaşlı') ||
      r.title.toLowerCase().contains('senior') ||
      (r.type == 'food' && r.notes?.toLowerCase().contains('senior') == true)
    );

    if (!hasSeniorFood) {
      insights.add(Insight(
        id: 'senior_food_${cat.id}',
        type: InsightType.suggestion,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_senior_food_title'),
        description: AppLocalizations.get('insight_senior_food_description').replaceAll('{catName}', cat.name),
        icon: Icons.restaurant_rounded,
        color: AppColors.food,
      ));
    }

    // Davranış değişiklikleri
    insights.add(Insight(
      id: 'senior_behavior_${cat.id}',
      type: InsightType.info,
      priority: InsightPriority.low,
      title: AppLocalizations.get('insight_senior_behavior_title'),
      description: AppLocalizations.get('insight_senior_behavior_description'),
      icon: Icons.visibility_rounded,
      color: AppColors.info,
    ));

    return insights;
  }

  // ============ SEASONAL INSIGHTS ============
  // Mevsimsel öneriler - mevsimlere göre özel öneriler

  List<Insight> generateSeasonalInsights(List<Cat> cats) {
    final insights = <Insight>[];

    if (cats.isEmpty) return insights;

    final now = DateTime.now();
    final month = now.month;

    // Yaz ayları (Haziran-Ağustos): 6-8
    if (month >= 6 && month <= 8) {
      insights.add(Insight(
        id: 'seasonal_summer_hydration',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_summer_hydration_title'),
        description: AppLocalizations.get('insight_summer_hydration_description'),
        icon: Icons.thermostat_rounded,
        color: AppColors.warning,
      ));

      insights.add(Insight(
        id: 'seasonal_summer_heat',
        type: InsightType.info,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_summer_heat_title'),
        description: AppLocalizations.get('insight_summer_heat_description'),
        icon: Icons.wb_sunny_rounded,
        color: AppColors.warning,
      ));
    }

    // Kış ayları (Aralık-Şubat): 12, 1, 2
    if (month == 12 || month <= 2) {
      insights.add(Insight(
        id: 'seasonal_winter_warmth',
        type: InsightType.info,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_winter_warmth_title'),
        description: AppLocalizations.get('insight_winter_warmth_description'),
        icon: Icons.ac_unit_rounded,
        color: AppColors.info,
      ));

      // Yavru ve yaşlı kediler için özel kış uyarısı
      final vulnerableCats = cats.where((cat) => cat.isKitten || cat.isSenior).toList();
      if (vulnerableCats.isNotEmpty) {
        insights.add(Insight(
          id: 'seasonal_winter_vulnerable',
          type: InsightType.warning,
          priority: InsightPriority.medium,
          title: AppLocalizations.get('insight_winter_vulnerable_title'),
          description: AppLocalizations.get('insight_winter_vulnerable_description'),
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ));
      }
    }

    // İlkbahar ayları (Mart-Mayıs): 3-5
    if (month >= 3 && month <= 5) {
      insights.add(Insight(
        id: 'seasonal_spring_parasites',
        type: InsightType.warning,
        priority: InsightPriority.high,
        title: AppLocalizations.get('insight_spring_parasites_title'),
        description: AppLocalizations.get('insight_spring_parasites_description'),
        icon: Icons.bug_report_rounded,
        color: AppColors.error,
        actionLabel: AppLocalizations.get('insight_spring_parasites_action'),
        actionRoute: '/reminder/add',
        actionData: {'type': 'medication', 'title': 'Parazit Kontrolü'},
      ));

      insights.add(Insight(
        id: 'seasonal_spring_shedding',
        type: InsightType.suggestion,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_spring_shedding_title'),
        description: AppLocalizations.get('insight_spring_shedding_description'),
        icon: Icons.brush_rounded,
        color: AppColors.grooming,
        actionLabel: AppLocalizations.get('insight_spring_shedding_action'),
        actionRoute: '/reminder/add',
        actionData: {'type': 'grooming', 'title': 'Tüy Tarama'},
      ));
    }

    // Sonbahar ayları (Eylül-Kasım): 9-11
    if (month >= 9 && month <= 11) {
      insights.add(Insight(
        id: 'seasonal_autumn_checkup',
        type: InsightType.suggestion,
        priority: InsightPriority.medium,
        title: AppLocalizations.get('insight_autumn_checkup_title'),
        description: AppLocalizations.get('insight_autumn_checkup_description'),
        icon: Icons.medical_services_rounded,
        color: AppColors.vet,
        actionLabel: AppLocalizations.get('insight_autumn_checkup_action'),
        actionRoute: '/reminder/add',
        actionData: {'type': 'vet', 'title': 'Kış Öncesi Kontrol'},
      ));

      insights.add(Insight(
        id: 'seasonal_autumn_weight',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_autumn_weight_title'),
        description: AppLocalizations.get('insight_autumn_weight_description'),
        icon: Icons.monitor_weight_outlined,
        color: AppColors.info,
      ));
    }

    return insights;
  }
  
  // ============ HEALTH CARE INSIGHTS ============
  // Sadece gerçekten aksiyon gerektiren önemli önerileri göster
  
  List<Insight> _generateHealthCareInsights(List<Cat> cats, List<Reminder> reminders) {
    final insights = <Insight>[];
    
    for (final cat in cats) {
      final catReminders = reminders.where((r) => r.catId == cat.id).toList();
      
      // Tırnak bakımı - sadece hatırlatıcı yoksa ve 3 aydan fazlaysa göster
      final hasNailReminder = catReminders.any((r) =>
        r.type == 'grooming' ||
        r.title.toLowerCase().contains('tırnak') ||
        r.title.toLowerCase().contains('nail')
      );
      
      if (!hasNailReminder && cat.ageInMonths >= 3) {
        insights.add(Insight(
          id: 'nail_care_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.medium,
          title: '${cat.name} ${AppLocalizations.get('nail_trimming').toLowerCase()}',
          description: AppLocalizations.get('nail_care_description'),
          icon: Icons.content_cut_rounded,
          color: AppColors.grooming,
          actionLabel: AppLocalizations.get('add_reminder'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'grooming', 'subType': 'nail_trimming'},
        ));
      }
      
      // Kulak bakımı - 6 aydan büyük kediler için
      final hasEarReminder = catReminders.any((r) =>
        r.title.toLowerCase().contains('kulak') ||
        r.title.toLowerCase().contains('ear')
      );
      
      if (!hasEarReminder && cat.ageInMonths >= 6) {
        insights.add(Insight(
          id: 'ear_care_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.low,
          title: '${cat.name} ${AppLocalizations.get('ear_cleaning').toLowerCase()}',
          description: AppLocalizations.get('ear_care_description'),
          icon: Icons.hearing_rounded,
          color: AppColors.grooming,
          actionLabel: AppLocalizations.get('add_reminder'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'grooming', 'subType': 'ear_cleaning'},
        ));
      }
      
      // Tüy bakımı - 3 aydan büyük kediler için
      final hasBrushingReminder = catReminders.any((r) =>
        r.title.toLowerCase().contains('tüy') ||
        r.title.toLowerCase().contains('brush') ||
        r.title.toLowerCase().contains('tarama')
      );
      
      if (!hasBrushingReminder && cat.ageInMonths >= 3) {
        insights.add(Insight(
          id: 'brushing_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.low,
          title: '${cat.name} ${AppLocalizations.get('brushing').toLowerCase()}',
          description: AppLocalizations.get('brushing_description'),
          icon: Icons.brush_rounded,
          color: AppColors.grooming,
          actionLabel: AppLocalizations.get('add_reminder'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'grooming', 'subType': 'brushing'},
        ));
      }
      
      // Diş bakımı - 1 yaşından büyük kediler için
      final hasDentalReminder = catReminders.any((r) =>
        r.title.toLowerCase().contains('diş') ||
        r.title.toLowerCase().contains('dental') ||
        r.title.toLowerCase().contains('tooth')
      );
      
      if (!hasDentalReminder && cat.ageInMonths >= 12) {
        insights.add(Insight(
          id: 'dental_care_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.low,
          title: '${cat.name} ${AppLocalizations.get('dental_care').toLowerCase()}',
          description: AppLocalizations.get('dental_care_description'),
          icon: Icons.mood_rounded,
          color: AppColors.info,
          actionLabel: AppLocalizations.get('add_reminder'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'grooming', 'subType': 'dental_care'},
        ));
      }

      // Su tüketimi takibi
      final hasWaterReminder = catReminders.any((r) =>
        r.title.toLowerCase().contains('su') ||
        r.title.toLowerCase().contains('water') ||
        r.title.toLowerCase().contains('hidrasyon')
      );

      if (!hasWaterReminder && cat.ageInMonths >= 3) {
        insights.add(Insight(
          id: 'water_intake_${cat.id}',
          type: InsightType.info,
          priority: InsightPriority.low,
          title: AppLocalizations.get('insight_water_intake_title'),
          description: AppLocalizations.get('insight_water_intake_description').replaceAll('{catName}', cat.name),
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF2196F3),
        ));
      }

      // Oyun ve zihinsel stimülasyon
      final hasPlayActivity = catReminders.any((r) =>
        r.type == 'exercise' ||
        r.title.toLowerCase().contains('oyun') ||
        r.title.toLowerCase().contains('play') ||
        r.title.toLowerCase().contains('egzersiz')
      );

      if (!hasPlayActivity && cat.ageInMonths >= 3) {
        insights.add(Insight(
          id: 'play_stimulation_${cat.id}',
          type: InsightType.suggestion,
          priority: InsightPriority.medium,
          title: AppLocalizations.get('insight_play_activity_title').replaceAll('{catName}', cat.name),
          description: AppLocalizations.get('insight_play_activity_description'),
          icon: Icons.sports_esports_rounded,
          color: const Color(0xFFFF9800),
          actionLabel: AppLocalizations.get('insight_play_activity_action'),
          actionRoute: '/reminder/add',
          actionData: {'catId': cat.id, 'type': 'exercise', 'subType': 'playtime'},
        ));
      }

      // Güneş ışığı ve D vitamini
      insights.add(Insight(
        id: 'sunlight_vitamin_d_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_sunlight_vitamin_title'),
        description: AppLocalizations.get('insight_sunlight_vitamin_description').replaceAll('{catName}', cat.name),
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFFFC107),
      ));

      // Stres yönetimi
      final isMultipleCatsHome = cats.length > 1;
      if (isMultipleCatsHome) {
        insights.add(Insight(
          id: 'stress_management_${cat.id}',
          type: InsightType.info,
          priority: InsightPriority.low,
          title: AppLocalizations.get('insight_stress_management_title'),
          description: AppLocalizations.get('insight_stress_management_description'),
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE91E63),
        ));
      }

      // Tuvalet hijyeni
      insights.add(Insight(
        id: 'litter_hygiene_${cat.id}',
        type: InsightType.info,
        priority: InsightPriority.low,
        title: AppLocalizations.get('insight_litter_hygiene_title'),
        description: AppLocalizations.get('insight_litter_hygiene_description'),
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF9C27B0),
      ));
    }

    return insights;
  }
}

