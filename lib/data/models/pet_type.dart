/// Pet türlerini tanımlar (Kedi, Köpek)
enum PetType {
  cat,
  dog;

  String toJson() => name;

  static PetType fromJson(String json) {
    return PetType.values.firstWhere(
      (type) => type.name == json,
      orElse: () => PetType.cat,
    );
  }

  /// Türkçe isim
  String get displayName {
    switch (this) {
      case PetType.cat:
        return 'Kedi';
      case PetType.dog:
        return 'Köpek';
    }
  }

  /// İngilizce isim
  String get displayNameEn {
    switch (this) {
      case PetType.cat:
        return 'Cat';
      case PetType.dog:
        return 'Dog';
    }
  }

  /// Icon name
  String get icon {
    switch (this) {
      case PetType.cat:
        return '🐱';
      case PetType.dog:
        return '🐶';
    }
  }
}
