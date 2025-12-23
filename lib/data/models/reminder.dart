class Reminder {
  final String id;
  final String catId;
  final String title;
  final String type; // food, medicine, vet, vaccine, dotcat_complete
  final String time; // HH:mm format
  final String frequency; // once, daily, weekly, monthly
  final bool isActive;
  final bool isCompleted;
  final String? notes;
  final DateTime createdAt;
  final DateTime? nextDate;

  Reminder({
    required this.id,
    required this.catId,
    required this.title,
    required this.type,
    required this.time,
    this.frequency = 'daily',
    required this.isActive,
    this.isCompleted = false,
    this.notes,
    required this.createdAt,
    this.nextDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'catId': catId,
      'title': title,
      'type': type,
      'time': time,
      'frequency': frequency,
      'isActive': isActive ? 1 : 0,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      catId: map['catId'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      time: map['time'] as String,
      frequency: map['frequency'] as String? ?? 'daily',
      isActive: map['isActive'] == 1,
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      nextDate: map['nextDate'] != null ? DateTime.parse(map['nextDate'] as String) : null,
    );
  }

  Reminder copyWith({
    String? title,
    String? type,
    String? time,
    String? frequency,
    bool? isActive,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
    DateTime? nextDate,
  }) {
    return Reminder(
      id: id,
      catId: catId,
      title: title ?? this.title,
      type: type ?? this.type,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      nextDate: nextDate ?? this.nextDate,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'food':
        return 'Food';
      case 'medicine':
        return 'Medicine';
      case 'vet':
        return 'Vet';
      case 'vaccine':
        return 'Vaccine';
      case 'dotcat_complete':
        return 'dotcat Complete';
      default:
        return 'Other';
    }
  }

  String get frequencyDisplayName {
    switch (frequency) {
      case 'once':
        return 'Once';
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Daily';
    }
  }
}
