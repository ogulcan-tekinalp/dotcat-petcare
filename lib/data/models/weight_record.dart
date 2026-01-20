class WeightRecord {
  final String id;
  final String petId; // Pet ID (supports both cats and dogs)
  final double weight;
  final String? notes;
  final DateTime recordedAt;

  WeightRecord({
    required this.id,
    required this.petId,
    required this.weight,
    this.notes,
    required this.recordedAt,
  });

  // Legacy support: catId getter for backwards compatibility
  String get catId => petId;

  /// Convert to local database format
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petId': petId, // Unified field name for database
      'weight': weight,
      'notes': notes,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  /// Convert to Firestore format (uses 'catId' and 'date' for backwards compatibility)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'catId': petId, // Firestore uses 'catId' for backwards compatibility
      'weight': weight,
      'notes': notes,
      'date': recordedAt.toIso8601String(), // Firestore uses 'date' field
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  /// Create from local database (uses 'petId' and 'recordedAt')
  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as String,
      petId: (map['petId'] ?? map['catId']) as String, // Support both for migration
      weight: (map['weight'] as num).toDouble(),
      notes: map['notes'] as String?,
      recordedAt: DateTime.parse(map['recordedAt'] as String),
    );
  }

  /// Create from Firestore data (may use 'catId' and 'date' fields)
  factory WeightRecord.fromFirestore(Map<String, dynamic> map) {
    // Parse date from various possible field names and formats
    DateTime parsedDate;
    final dateValue = map['date'] ?? map['recordedAt'];
    if (dateValue is DateTime) {
      parsedDate = dateValue;
    } else if (dateValue is String) {
      parsedDate = DateTime.parse(dateValue);
    } else if (dateValue != null && dateValue.runtimeType.toString().contains('Timestamp')) {
      parsedDate = (dateValue as dynamic).toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return WeightRecord(
      id: map['id'] as String,
      petId: (map['catId'] ?? map['petId']) as String, // Support both field names
      weight: (map['weight'] as num).toDouble(),
      notes: map['notes'] as String?,
      recordedAt: parsedDate,
    );
  }

  WeightRecord copyWith({
    double? weight,
    String? notes,
    DateTime? recordedAt,
  }) {
    return WeightRecord(
      id: id,
      petId: petId,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
