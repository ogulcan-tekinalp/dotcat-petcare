class ReminderCompletion {
  final String id; // reminderId_date formatında
  final String reminderId;
  final DateTime completedDate;
  final DateTime completedAt;

  ReminderCompletion({
    required this.id,
    required this.reminderId,
    required this.completedDate,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'completedDate': completedDate.toIso8601String().split('T')[0],
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory ReminderCompletion.fromMap(Map<String, dynamic> map) {
    return ReminderCompletion(
      id: map['id'] as String,
      reminderId: map['reminderId'] as String,
      completedDate: DateTime.parse(map['completedDate'] as String),
      completedAt: DateTime.parse(map['completedAt'] as String),
    );
  }
}

