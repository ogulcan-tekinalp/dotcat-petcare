class HealthNote {
  final String id;
  final String petId; // Pet ID (supports both cats and dogs)
  final String title;
  final String type; // vet_visit, symptom, medication, surgery, other
  final String? description;
  final DateTime date;
  final String? veterinarian;
  final DateTime createdAt;

  HealthNote({
    required this.id,
    required this.petId,
    required this.title,
    required this.type,
    this.description,
    required this.date,
    this.veterinarian,
    required this.createdAt,
  });

  // Legacy support: catId getter for backwards compatibility
  String get catId => petId;

  String get typeDisplayName {
    switch (type) {
      case 'vet_visit':
        return 'Veteriner Ziyareti';
      case 'symptom':
        return 'Belirti/Semptom';
      case 'medication':
        return 'İlaç Tedavisi';
      case 'surgery':
        return 'Ameliyat';
      default:
        return 'Diğer';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'catId': petId, // Database field still named 'catId' for compatibility
      'title': title,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'veterinarian': veterinarian,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HealthNote.fromMap(Map<String, dynamic> map) {
    return HealthNote(
      id: map['id'] as String,
      petId: map['catId'] as String, // Read from 'catId' field for compatibility
      title: map['title'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      veterinarian: map['veterinarian'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  HealthNote copyWith({
    String? title,
    String? type,
    String? description,
    DateTime? date,
    String? veterinarian,
  }) {
    return HealthNote(
      id: id,
      petId: petId,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      veterinarian: veterinarian ?? this.veterinarian,
      createdAt: createdAt,
    );
  }
}
