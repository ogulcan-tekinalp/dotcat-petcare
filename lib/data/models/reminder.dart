class Reminder {
  final String id;
  final String petId; // Pet ID (supports both cats and dogs)
  final String title;
  final String type; // food, medicine, vet, vaccine, dotcat_complete
  final String time; // HH:mm format (primary time)
  final List<String>? additionalTimes; // Additional times for daily reminders (max 4, total 5 with primary)
  final String frequency; // once, daily, weekly, monthly
  final bool isActive;
  final bool isCompleted;
  final String? notes;
  final DateTime createdAt;
  final DateTime? nextDate;
  final DateTime? lastCompletionDate; // Track when reminder was last completed

  Reminder({
    required this.id,
    required this.petId,
    required this.title,
    required this.type,
    required this.time,
    this.additionalTimes,
    this.frequency = 'daily',
    required this.isActive,
    this.isCompleted = false,
    this.notes,
    required this.createdAt,
    this.nextDate,
    this.lastCompletionDate,
  });

  /// Get all times for this reminder (primary + additional)
  List<String> get allTimes {
    final times = <String>[time];
    if (additionalTimes != null && additionalTimes!.isNotEmpty) {
      times.addAll(additionalTimes!);
    }
    // Sort times chronologically
    times.sort((a, b) => a.compareTo(b));
    return times;
  }

  /// Check if this reminder has multiple daily times
  bool get hasMultipleTimes => additionalTimes != null && additionalTimes!.isNotEmpty;

  // Legacy support: catId getter for backwards compatibility
  String get catId => petId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petId': petId, // Unified field name for database
      'title': title,
      'type': type,
      'time': time,
      'additionalTimes': additionalTimes?.join(','), // Store as comma-separated string
      'frequency': frequency,
      'isActive': isActive ? 1 : 0,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
      'lastCompletionDate': lastCompletionDate?.toIso8601String(),
    };
  }

  /// Create from Firestore data (uses 'catId' for backwards compatibility)
  factory Reminder.fromFirestore(Map<String, dynamic> map) {
    // Parse additionalTimes from Firestore (stored as List<dynamic>)
    List<String>? additionalTimes;
    if (map['additionalTimes'] != null) {
      if (map['additionalTimes'] is List) {
        additionalTimes = (map['additionalTimes'] as List).map((e) => e.toString()).toList();
      } else if (map['additionalTimes'] is String && (map['additionalTimes'] as String).isNotEmpty) {
        additionalTimes = (map['additionalTimes'] as String).split(',');
      }
    }

    return Reminder(
      id: map['id'] as String,
      petId: (map['catId'] ?? map['petId']) as String, // Support both field names from Firestore
      title: map['title'] as String,
      type: map['type'] as String,
      time: map['time'] as String,
      additionalTimes: additionalTimes,
      frequency: map['frequency'] as String? ?? 'daily',
      isActive: map['isActive'] == 1 || map['isActive'] == true,
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      notes: map['notes'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      nextDate: map['nextDate'] != null ? _parseDateTime(map['nextDate']) : null,
      lastCompletionDate: map['lastCompletionDate'] != null ? _parseDateTime(map['lastCompletionDate']) : null,
    );
  }

  /// Create from local database (uses 'petId')
  factory Reminder.fromMap(Map<String, dynamic> map) {
    // Parse additionalTimes from database (stored as comma-separated string)
    List<String>? additionalTimes;
    if (map['additionalTimes'] != null && (map['additionalTimes'] as String).isNotEmpty) {
      additionalTimes = (map['additionalTimes'] as String).split(',');
    }

    return Reminder(
      id: map['id'] as String,
      petId: (map['petId'] ?? map['catId']) as String, // Support both for migration
      title: map['title'] as String,
      type: map['type'] as String,
      time: map['time'] as String,
      additionalTimes: additionalTimes,
      frequency: map['frequency'] as String? ?? 'daily',
      isActive: map['isActive'] == 1 || map['isActive'] == true,
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      nextDate: map['nextDate'] != null ? DateTime.parse(map['nextDate'] as String) : null,
      lastCompletionDate: map['lastCompletionDate'] != null ? DateTime.parse(map['lastCompletionDate'] as String) : null,
    );
  }

  /// Helper to parse DateTime from various formats (Timestamp, String, DateTime)
  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    // Handle Firestore Timestamp
    if (value != null && value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  /// Convert to Firestore format (uses 'catId' for backwards compatibility)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'catId': petId, // Firestore uses 'catId' for backwards compatibility
      'title': title,
      'type': type,
      'time': time,
      'additionalTimes': additionalTimes, // Store as List in Firestore
      'frequency': frequency,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
      'lastCompletionDate': lastCompletionDate?.toIso8601String(),
    };
  }

  Reminder copyWith({
    String? title,
    String? type,
    String? time,
    List<String>? additionalTimes,
    bool clearAdditionalTimes = false,
    String? frequency,
    bool? isActive,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
    DateTime? nextDate,
    DateTime? lastCompletionDate,
  }) {
    return Reminder(
      id: id,
      petId: petId,
      title: title ?? this.title,
      type: type ?? this.type,
      time: time ?? this.time,
      additionalTimes: clearAdditionalTimes ? null : (additionalTimes ?? this.additionalTimes),
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      nextDate: nextDate ?? this.nextDate,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
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
