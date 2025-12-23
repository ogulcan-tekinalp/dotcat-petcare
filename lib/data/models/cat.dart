import '../../core/utils/localization.dart';

class Cat {
  final String id;
  final String name;
  final DateTime birthDate;
  final String? breed;
  final double? weight;
  final String? photoPath;
  final String? notes;
  final DateTime createdAt;

  Cat({
    required this.id,
    required this.name,
    required this.birthDate,
    this.breed,
    this.weight,
    this.photoPath,
    this.notes,
    required this.createdAt,
  });

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
  }

  String get ageText {
    final months = ageInMonths;
    return AppLocalizations.getAgeText(months);
  }

  bool get isKitten => ageInMonths < 12;
  bool get isSenior => ageInMonths >= 84;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate.toIso8601String(),
      'breed': breed,
      'weight': weight,
      'photoPath': photoPath,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Cat.fromMap(Map<String, dynamic> map) {
    return Cat(
      id: map['id'] as String,
      name: map['name'] as String,
      birthDate: DateTime.parse(map['birthDate'] as String),
      breed: map['breed'] as String?,
      weight: map['weight'] as double?,
      photoPath: map['photoPath'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Cat copyWith({
    String? name,
    DateTime? birthDate,
    String? breed,
    double? weight,
    String? photoPath,
    String? notes,
  }) {
    return Cat(
      id: id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      breed: breed ?? this.breed,
      weight: weight ?? this.weight,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
