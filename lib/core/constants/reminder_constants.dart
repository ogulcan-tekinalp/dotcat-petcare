import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/localization.dart';
import '../../data/models/pet_type.dart';

/// Hatırlatıcı tipleri
enum ReminderType {
  // ============ ORTAK (Kedi + Köpek) ============
  food,           // Mama
  water,          // Su tazeleme
  medicine,       // İlaç
  vet,            // Veteriner ziyareti
  vaccine,        // Aşı
  grooming,       // Tüy bakımı
  brushing,       // Tarama/Fırçalama
  nailTrim,       // Tırnak kesimi
  bath,           // Banyo
  earCleaning,    // Kulak temizliği
  dentalCare,     // Diş bakımı
  fleaTick,       // Pire/Kene ilacı
  deworming,      // İç parazit
  weightCheck,    // Tartım
  neutering,      // Kısırlaştırma
  microchip,      // Mikroçip
  petInsurance,   // Sigorta yenileme
  treat,          // Ödül/Atıştırmalık
  vitamin,        // Vitamin/Takviye
  playtime,       // Oyun zamanı
  training,       // Eğitim
  photo,          // Fotoğraf çekimi

  // ============ SAĞLIK/VETERİNER İŞLEMLERİ ============
  bloodTest,      // Kan tahlili
  xray,           // Röntgen
  ultrasound,     // Ultrason
  surgery,        // Ameliyat
  dentalCleaningPro, // Profesyonel diş temizliği
  allergyTest,    // Alerji testi
  eyeExam,        // Göz muayenesi
  emergency,      // Acil durum

  // ============ SADECE KÖPEK ============
  walk,           // Yürüyüş
  poopCleanup,    // Kaka toplama
  dogPark,        // Köpek parkı
  socialization,  // Sosyalleşme
  leashTraining,  // Tasma eğitimi
  pottyTraining,  // Tuvalet eğitimi (yavru)

  // ============ SADECE KEDİ ============
  litterCleaning, // Kum temizliği
  litterChange,   // Kum değişimi
  scratchingPost, // Tırmalama tahtası
  hairballPrevention, // Tüy yumağı önleme
  catnip,         // Kedi otu

  // ============ ÖZEL ============
  dotcatComplete, // Uygulama check-in
  exercise,       // Egzersiz (genel)
  other,          // Diğer
}

extension ReminderTypeExtension on ReminderType {
  /// String değerini döndürür (Firestore/SQLite uyumu için)
  String get value {
    switch (this) {
      // Ortak
      case ReminderType.food: return 'food';
      case ReminderType.water: return 'water';
      case ReminderType.medicine: return 'medicine';
      case ReminderType.vet: return 'vet';
      case ReminderType.vaccine: return 'vaccine';
      case ReminderType.grooming: return 'grooming';
      case ReminderType.brushing: return 'brushing';
      case ReminderType.nailTrim: return 'nail_trim';
      case ReminderType.bath: return 'bath';
      case ReminderType.earCleaning: return 'ear_cleaning';
      case ReminderType.dentalCare: return 'dental_care';
      case ReminderType.fleaTick: return 'flea_tick';
      case ReminderType.deworming: return 'deworming';
      case ReminderType.weightCheck: return 'weight_check';
      case ReminderType.neutering: return 'neutering';
      case ReminderType.microchip: return 'microchip';
      case ReminderType.petInsurance: return 'pet_insurance';
      case ReminderType.treat: return 'treat';
      case ReminderType.vitamin: return 'vitamin';
      case ReminderType.playtime: return 'playtime';
      case ReminderType.training: return 'training';
      case ReminderType.photo: return 'photo';
      // Sağlık/Veteriner
      case ReminderType.bloodTest: return 'blood_test';
      case ReminderType.xray: return 'xray';
      case ReminderType.ultrasound: return 'ultrasound';
      case ReminderType.surgery: return 'surgery';
      case ReminderType.dentalCleaningPro: return 'dental_cleaning_pro';
      case ReminderType.allergyTest: return 'allergy_test';
      case ReminderType.eyeExam: return 'eye_exam';
      case ReminderType.emergency: return 'emergency';
      // Köpek
      case ReminderType.walk: return 'walk';
      case ReminderType.poopCleanup: return 'poop_cleanup';
      case ReminderType.dogPark: return 'dog_park';
      case ReminderType.socialization: return 'socialization';
      case ReminderType.leashTraining: return 'leash_training';
      case ReminderType.pottyTraining: return 'potty_training';
      // Kedi
      case ReminderType.litterCleaning: return 'litter_cleaning';
      case ReminderType.litterChange: return 'litter_change';
      case ReminderType.scratchingPost: return 'scratching_post';
      case ReminderType.hairballPrevention: return 'hairball_prevention';
      case ReminderType.catnip: return 'catnip';
      // Özel
      case ReminderType.dotcatComplete: return 'dotcat_complete';
      case ReminderType.exercise: return 'exercise';
      case ReminderType.other: return 'other';
    }
  }

  /// Lokalize edilmiş görüntüleme adı
  String get displayName {
    return AppLocalizations.get('reminder_type_${value}');
  }

  /// Tip için ikon
  IconData get icon {
    switch (this) {
      // Ortak
      case ReminderType.food: return Icons.restaurant_rounded;
      case ReminderType.water: return Icons.water_drop_rounded;
      case ReminderType.medicine: return Icons.medication_rounded;
      case ReminderType.vet: return Icons.local_hospital_rounded;
      case ReminderType.vaccine: return Icons.vaccines_rounded;
      case ReminderType.grooming: return Icons.content_cut_rounded;
      case ReminderType.brushing: return Icons.brush_rounded;
      case ReminderType.nailTrim: return Icons.carpenter_rounded;
      case ReminderType.bath: return Icons.bathtub_rounded;
      case ReminderType.earCleaning: return Icons.hearing_rounded;
      case ReminderType.dentalCare: return Icons.cleaning_services_rounded;
      case ReminderType.fleaTick: return Icons.bug_report_rounded;
      case ReminderType.deworming: return Icons.pest_control_rounded;
      case ReminderType.weightCheck: return Icons.monitor_weight_rounded;
      case ReminderType.neutering: return Icons.medical_services_rounded;
      case ReminderType.microchip: return Icons.memory_rounded;
      case ReminderType.petInsurance: return Icons.health_and_safety_rounded;
      case ReminderType.treat: return Icons.cookie_rounded;
      case ReminderType.vitamin: return Icons.medication_liquid_rounded;
      case ReminderType.playtime: return Icons.sports_soccer_rounded;
      case ReminderType.training: return Icons.school_rounded;
      case ReminderType.photo: return Icons.camera_alt_rounded;
      // Sağlık/Veteriner
      case ReminderType.bloodTest: return Icons.bloodtype_rounded;
      case ReminderType.xray: return Icons.radio_button_checked_rounded;
      case ReminderType.ultrasound: return Icons.monitor_heart_rounded;
      case ReminderType.surgery: return Icons.healing_rounded;
      case ReminderType.dentalCleaningPro: return Icons.auto_fix_high_rounded;
      case ReminderType.allergyTest: return Icons.science_rounded;
      case ReminderType.eyeExam: return Icons.visibility_rounded;
      case ReminderType.emergency: return Icons.emergency_rounded;
      // Köpek
      case ReminderType.walk: return Icons.directions_walk_rounded;
      case ReminderType.poopCleanup: return Icons.delete_rounded;
      case ReminderType.dogPark: return Icons.park_rounded;
      case ReminderType.socialization: return Icons.groups_rounded;
      case ReminderType.leashTraining: return Icons.link_rounded;
      case ReminderType.pottyTraining: return Icons.wc_rounded;
      // Kedi
      case ReminderType.litterCleaning: return Icons.cleaning_services_rounded;
      case ReminderType.litterChange: return Icons.autorenew_rounded;
      case ReminderType.scratchingPost: return Icons.chair_rounded;
      case ReminderType.hairballPrevention: return Icons.grass_rounded;
      case ReminderType.catnip: return Icons.local_florist_rounded;
      // Özel
      case ReminderType.dotcatComplete: return Icons.pets_rounded;
      case ReminderType.exercise: return Icons.fitness_center_rounded;
      case ReminderType.other: return Icons.more_horiz_rounded;
    }
  }

  /// Tip için renk
  Color get color {
    switch (this) {
      // Ortak
      case ReminderType.food: return AppColors.food;
      case ReminderType.water: return AppColors.water;
      case ReminderType.medicine: return AppColors.medicine;
      case ReminderType.vet: return AppColors.vet;
      case ReminderType.vaccine: return AppColors.vaccine;
      case ReminderType.grooming: return AppColors.grooming;
      case ReminderType.brushing: return AppColors.brushing;
      case ReminderType.nailTrim: return AppColors.nailTrim;
      case ReminderType.bath: return AppColors.bath;
      case ReminderType.earCleaning: return AppColors.earCleaning;
      case ReminderType.dentalCare: return AppColors.dentalCare;
      case ReminderType.fleaTick: return AppColors.fleaTick;
      case ReminderType.deworming: return AppColors.deworming;
      case ReminderType.weightCheck: return AppColors.weight;
      case ReminderType.neutering: return AppColors.neutering;
      case ReminderType.microchip: return AppColors.microchip;
      case ReminderType.petInsurance: return AppColors.petInsurance;
      case ReminderType.treat: return AppColors.treat;
      case ReminderType.vitamin: return AppColors.vitamin;
      case ReminderType.playtime: return AppColors.playtime;
      case ReminderType.training: return AppColors.training;
      case ReminderType.photo: return AppColors.photo;
      // Sağlık/Veteriner
      case ReminderType.bloodTest: return AppColors.health;
      case ReminderType.xray: return AppColors.health;
      case ReminderType.ultrasound: return AppColors.health;
      case ReminderType.surgery: return AppColors.emergency;
      case ReminderType.dentalCleaningPro: return AppColors.dentalCare;
      case ReminderType.allergyTest: return AppColors.health;
      case ReminderType.eyeExam: return AppColors.health;
      case ReminderType.emergency: return AppColors.emergency;
      // Köpek
      case ReminderType.walk: return AppColors.walk;
      case ReminderType.poopCleanup: return AppColors.poopCleanup;
      case ReminderType.dogPark: return AppColors.dogPark;
      case ReminderType.socialization: return AppColors.socialization;
      case ReminderType.leashTraining: return AppColors.training;
      case ReminderType.pottyTraining: return AppColors.training;
      // Kedi
      case ReminderType.litterCleaning: return AppColors.litterCleaning;
      case ReminderType.litterChange: return AppColors.litterChange;
      case ReminderType.scratchingPost: return AppColors.scratchingPost;
      case ReminderType.hairballPrevention: return AppColors.hairball;
      case ReminderType.catnip: return AppColors.catnip;
      // Özel
      case ReminderType.dotcatComplete: return AppColors.dotcat;
      case ReminderType.exercise: return AppColors.exercise;
      case ReminderType.other: return AppColors.info;
    }
  }

  /// Sağlık ile ilgili mi? (tamamlandığında tarih ve masraf sorulacak)
  bool get isHealthRelated {
    return this == ReminderType.vaccine ||
        this == ReminderType.medicine ||
        this == ReminderType.vet ||
        this == ReminderType.bloodTest ||
        this == ReminderType.xray ||
        this == ReminderType.ultrasound ||
        this == ReminderType.surgery ||
        this == ReminderType.dentalCleaningPro ||
        this == ReminderType.allergyTest ||
        this == ReminderType.eyeExam ||
        this == ReminderType.emergency ||
        this == ReminderType.neutering ||
        this == ReminderType.microchip ||
        this == ReminderType.fleaTick ||
        this == ReminderType.deworming;
  }

  /// Günlük tekrar edecek mi?
  bool get isDailyByDefault {
    return this == ReminderType.food ||
        this == ReminderType.water ||
        this == ReminderType.dotcatComplete;
  }

  /// Günde birden fazla kez ayarlanabilir mi? (max 5)
  bool get allowsMultipleDaily {
    return this == ReminderType.food ||
        this == ReminderType.water ||
        this == ReminderType.medicine ||
        this == ReminderType.treat ||
        this == ReminderType.vitamin ||
        this == ReminderType.playtime ||
        this == ReminderType.training ||
        this == ReminderType.walk ||
        this == ReminderType.poopCleanup ||
        this == ReminderType.pottyTraining ||
        this == ReminderType.litterCleaning ||
        this == ReminderType.brushing ||
        this == ReminderType.dentalCare;
  }

  /// Tek seferlik mi? (bir kez yapılır)
  bool get isOneTimeOnly {
    return this == ReminderType.neutering ||
        this == ReminderType.microchip ||
        this == ReminderType.surgery;
  }

  /// Sadece kedi için mi?
  bool get isCatOnly {
    return this == ReminderType.litterCleaning ||
        this == ReminderType.litterChange ||
        this == ReminderType.scratchingPost ||
        this == ReminderType.hairballPrevention ||
        this == ReminderType.catnip;
  }

  /// Sadece köpek için mi?
  bool get isDogOnly {
    return this == ReminderType.walk ||
        this == ReminderType.poopCleanup ||
        this == ReminderType.dogPark ||
        this == ReminderType.socialization ||
        this == ReminderType.leashTraining ||
        this == ReminderType.pottyTraining;
  }

  /// Pet tipine göre kullanılabilir mi?
  bool isAvailableFor(PetType? petType) {
    if (petType == null) return true; // Tüm tipler

    if (petType == PetType.cat && isDogOnly) return false;
    if (petType == PetType.dog && isCatOnly) return false;

    return true;
  }

  /// String'den enum'a çevir
  static ReminderType fromString(String value) {
    switch (value) {
      // Ortak
      case 'food': return ReminderType.food;
      case 'water': return ReminderType.water;
      case 'medicine': return ReminderType.medicine;
      case 'vet': return ReminderType.vet;
      case 'vaccine': return ReminderType.vaccine;
      case 'grooming': return ReminderType.grooming;
      case 'brushing': return ReminderType.brushing;
      case 'nail_trim': return ReminderType.nailTrim;
      case 'bath': return ReminderType.bath;
      case 'ear_cleaning': return ReminderType.earCleaning;
      case 'dental_care': return ReminderType.dentalCare;
      case 'flea_tick': return ReminderType.fleaTick;
      case 'deworming': return ReminderType.deworming;
      case 'weight_check': return ReminderType.weightCheck;
      case 'weight': return ReminderType.weightCheck; // eski uyumluluk
      case 'neutering': return ReminderType.neutering;
      case 'microchip': return ReminderType.microchip;
      case 'pet_insurance': return ReminderType.petInsurance;
      case 'treat': return ReminderType.treat;
      case 'vitamin': return ReminderType.vitamin;
      case 'playtime': return ReminderType.playtime;
      case 'training': return ReminderType.training;
      case 'photo': return ReminderType.photo;
      // Sağlık/Veteriner
      case 'blood_test': return ReminderType.bloodTest;
      case 'xray': return ReminderType.xray;
      case 'ultrasound': return ReminderType.ultrasound;
      case 'surgery': return ReminderType.surgery;
      case 'dental_cleaning_pro': return ReminderType.dentalCleaningPro;
      case 'allergy_test': return ReminderType.allergyTest;
      case 'eye_exam': return ReminderType.eyeExam;
      case 'emergency': return ReminderType.emergency;
      // Köpek
      case 'walk': return ReminderType.walk;
      case 'poop_cleanup': return ReminderType.poopCleanup;
      case 'dog_park': return ReminderType.dogPark;
      case 'socialization': return ReminderType.socialization;
      case 'leash_training': return ReminderType.leashTraining;
      case 'potty_training': return ReminderType.pottyTraining;
      // Kedi
      case 'litter_cleaning': return ReminderType.litterCleaning;
      case 'litter_change': return ReminderType.litterChange;
      case 'scratching_post': return ReminderType.scratchingPost;
      case 'hairball_prevention': return ReminderType.hairballPrevention;
      case 'catnip': return ReminderType.catnip;
      // Özel
      case 'dotcat_complete': return ReminderType.dotcatComplete;
      case 'exercise': return ReminderType.exercise;
      case 'other': return ReminderType.other;
      default: return ReminderType.other;
    }
  }
}

/// Pet tipine göre mevcut hatırlatıcı türlerini döndür
List<ReminderType> getReminderTypesForPet(PetType? petType) {
  return ReminderType.values
      .where((type) => type.isAvailableFor(petType) && type != ReminderType.other)
      .toList();
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

// ============ HATIRLATICI KATEGORİ SİSTEMİ ============

/// Ana kategoriler
enum ReminderCategory {
  dotcat,       // DotCat (Uygulama check-in)
  feeding,      // Beslenme (Mama, Su, Ödül, Vitamin)
  health,       // Sağlık (Aşı, İlaç, Parazit)
  veterinary,   // Veteriner (Muayene, Testler, Ameliyat)
  grooming,     // Bakım (Banyo, Tıraş, Tırnak, Diş)
  activity,     // Aktivite (Oyun, Egzersiz, Eğitim)
  hygiene,      // Hijyen (Kum, Kaka temizliği)
  other,        // Diğer
}

/// Kategori bilgileri
class ReminderCategoryInfo {
  final ReminderCategory category;
  final String nameKey;
  final IconData icon;
  final Color color;
  final List<ReminderType> types;

  const ReminderCategoryInfo({
    required this.category,
    required this.nameKey,
    required this.icon,
    required this.color,
    required this.types,
  });

  String get name => AppLocalizations.get(nameKey);
}

/// Tüm kategorileri ve altındaki türleri döndür
List<ReminderCategoryInfo> getReminderCategories(PetType? petType) {
  return [
    // DotCat - EN BAŞTA
    ReminderCategoryInfo(
      category: ReminderCategory.dotcat,
      nameKey: 'category_dotcat',
      icon: Icons.pets_rounded,
      color: AppColors.dotcat,
      types: [
        ReminderType.dotcatComplete,
      ],
    ),
    // Beslenme
    ReminderCategoryInfo(
      category: ReminderCategory.feeding,
      nameKey: 'category_feeding',
      icon: Icons.restaurant_rounded,
      color: AppColors.food,
      types: [
        ReminderType.food,
        ReminderType.water,
        ReminderType.treat,
        ReminderType.vitamin,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Sağlık
    ReminderCategoryInfo(
      category: ReminderCategory.health,
      nameKey: 'category_health',
      icon: Icons.favorite_rounded,
      color: AppColors.vaccine,
      types: [
        ReminderType.vaccine,
        ReminderType.medicine,
        ReminderType.fleaTick,
        ReminderType.deworming,
        ReminderType.weightCheck,
        if (petType == PetType.cat) ReminderType.hairballPrevention,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Veteriner
    ReminderCategoryInfo(
      category: ReminderCategory.veterinary,
      nameKey: 'category_veterinary',
      icon: Icons.local_hospital_rounded,
      color: AppColors.vet,
      types: [
        ReminderType.vet,
        ReminderType.bloodTest,
        ReminderType.xray,
        ReminderType.ultrasound,
        ReminderType.surgery,
        ReminderType.dentalCleaningPro,
        ReminderType.allergyTest,
        ReminderType.eyeExam,
        ReminderType.neutering,
        ReminderType.microchip,
        ReminderType.emergency,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Bakım - grooming artık alt tür değil, sadece fırçalama vb.
    ReminderCategoryInfo(
      category: ReminderCategory.grooming,
      nameKey: 'category_grooming',
      icon: Icons.content_cut_rounded,
      color: AppColors.grooming,
      types: [
        ReminderType.brushing,
        ReminderType.bath,
        ReminderType.nailTrim,
        ReminderType.earCleaning,
        ReminderType.dentalCare,
        if (petType == PetType.cat) ReminderType.scratchingPost,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Aktivite
    ReminderCategoryInfo(
      category: ReminderCategory.activity,
      nameKey: 'category_activity',
      icon: Icons.sports_rounded,
      color: AppColors.playtime,
      types: [
        ReminderType.playtime,
        ReminderType.training,
        ReminderType.exercise,
        if (petType == PetType.dog) ReminderType.walk,
        if (petType == PetType.dog) ReminderType.dogPark,
        if (petType == PetType.dog) ReminderType.socialization,
        if (petType == PetType.dog) ReminderType.leashTraining,
        if (petType == PetType.dog) ReminderType.pottyTraining,
        if (petType == PetType.cat) ReminderType.catnip,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Hijyen
    ReminderCategoryInfo(
      category: ReminderCategory.hygiene,
      nameKey: 'category_hygiene',
      icon: Icons.cleaning_services_rounded,
      color: AppColors.litterCleaning,
      types: [
        if (petType == PetType.cat) ReminderType.litterCleaning,
        if (petType == PetType.cat) ReminderType.litterChange,
        if (petType == PetType.dog) ReminderType.poopCleanup,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
    // Diğer
    ReminderCategoryInfo(
      category: ReminderCategory.other,
      nameKey: 'category_other',
      icon: Icons.more_horiz_rounded,
      color: AppColors.info,
      types: [
        ReminderType.photo,
        ReminderType.petInsurance,
      ].where((t) => t.isAvailableFor(petType)).toList(),
    ),
  ].where((cat) => cat.types.isNotEmpty).toList();
}
