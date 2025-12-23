class HealthNote {
  final String id;
  final String catId;
  final String title;
  final String type; // vet_visit, symptom, medication, surgery, other
  final String? description;
  final DateTime date;
  final String? veterinarian;
  final DateTime createdAt;

  HealthNote({
    required this.id,
    required this.catId,
    required this.title,
    required this.type,
    this.description,
    required this.date,
    this.veterinarian,
    required this.createdAt,
  });

  String get typeDisplayName {
    switch (type) {
      case 'vet_visit':
        return 'Veteriner Ziyareti';
      case 'symptom':
        return 'Belirti/Semptom';
      case 'medication':
        return 'Ilac Tedavisi';
      case 'surgery':
        return 'Ameliyat';
      default:
        return 'Diger';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'catId': catId,
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
      catId: map['catId'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      veterinarian: map['veterinarian'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
