class Vaccination {
  final String id;
  final String petId; // Pet ID (supports both cats and dogs)
  final String name;
  final DateTime date;
  final DateTime? nextDate;
  final bool isCompleted;
  final String? veterinarian;
  final String? notes;
  final DateTime createdAt;

  Vaccination({
    required this.id,
    required this.petId,
    required this.name,
    required this.date,
    this.nextDate,
    this.isCompleted = false,
    this.veterinarian,
    this.notes,
    required this.createdAt,
  });

  // Legacy support: catId getter for backwards compatibility
  String get catId => petId;

  bool get isUpcoming {
    if (nextDate == null || isCompleted) return false;
    final now = DateTime.now();
    final diff = nextDate!.difference(now).inDays;
    return diff >= 0 && diff <= 30;
  }

  bool get isOverdue {
    if (nextDate == null || isCompleted) return false;
    return nextDate!.isBefore(DateTime.now());
  }

  int? get daysUntilNext {
    if (nextDate == null) return null;
    return nextDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'catId': petId, // Database field still named 'catId' for compatibility
      'name': name,
      'date': date.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'veterinarian': veterinarian,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vaccination.fromMap(Map<String, dynamic> map) {
    return Vaccination(
      id: map['id'] as String,
      petId: map['catId'] as String, // Read from 'catId' field for compatibility
      name: map['name'] as String,
      date: DateTime.parse(map['date'] as String),
      nextDate: map['nextDate'] != null ? DateTime.parse(map['nextDate'] as String) : null,
      isCompleted: map['isCompleted'] == 1,
      veterinarian: map['veterinarian'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Vaccination copyWith({
    String? name,
    DateTime? date,
    DateTime? nextDate,
    bool? isCompleted,
    String? veterinarian,
    String? notes,
  }) {
    return Vaccination(
      id: id,
      petId: petId,
      name: name ?? this.name,
      date: date ?? this.date,
      nextDate: nextDate ?? this.nextDate,
      isCompleted: isCompleted ?? this.isCompleted,
      veterinarian: veterinarian ?? this.veterinarian,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
