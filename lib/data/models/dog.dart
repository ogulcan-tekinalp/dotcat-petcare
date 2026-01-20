import '../../core/utils/localization.dart';
import 'pet_type.dart';

class Dog {
  final String id;
  final String name;
  final DateTime birthDate;
  final String? breed;
  final String? gender; // 'male', 'female', 'unknown'
  final double? weight;
  final String? size; // Köpek boyutu: Çok Küçük, Küçük, Orta, Büyük, Çok Büyük
  final String? photoPath;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt; // For conflict resolution in sync
  final PetType petType; // Her zaman PetType.dog

  Dog({
    required this.id,
    required this.name,
    required this.birthDate,
    this.breed,
    this.gender,
    this.weight,
    this.size,
    this.photoPath,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.petType = PetType.dog, // Default: dog
  });

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
  }

  String get ageText {
    final months = ageInMonths;
    return AppLocalizations.getAgeText(months);
  }

  bool get isPuppy => ageInMonths < 12;
  bool get isSenior => ageInMonths >= 84; // 7 yıl (köpekler için senior yaş)

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate.toIso8601String(),
      'breed': breed,
      'gender': gender,
      'weight': weight,
      'size': size,
      'photoPath': photoPath,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? createdAt.toIso8601String(),
      'petType': petType.toJson(),
    };
  }

  factory Dog.fromMap(Map<String, dynamic> map) {
    return Dog(
      id: map['id'] as String,
      name: map['name'] as String,
      birthDate: DateTime.parse(map['birthDate'] as String),
      breed: map['breed'] as String?,
      gender: map['gender'] as String?,
      weight: map['weight'] as double?,
      size: map['size'] as String?,
      photoPath: map['photoPath'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      petType: map['petType'] != null
          ? PetType.fromJson(map['petType'] as String)
          : PetType.dog,
    );
  }

  Dog copyWith({
    String? name,
    DateTime? birthDate,
    String? breed,
    String? gender,
    double? weight,
    String? size,
    String? photoPath,
    String? notes,
  }) {
    return Dog(
      id: id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      size: size ?? this.size,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(), // Update timestamp on copy
    );
  }
}
