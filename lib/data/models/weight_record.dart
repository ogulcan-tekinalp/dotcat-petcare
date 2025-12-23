class WeightRecord {
  final String id;
  final String catId;
  final double weight;
  final String? notes;
  final DateTime recordedAt;

  WeightRecord({
    required this.id,
    required this.catId,
    required this.weight,
    this.notes,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'catId': catId,
      'weight': weight,
      'notes': notes,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as String,
      catId: map['catId'] as String,
      weight: map['weight'] as double,
      notes: map['notes'] as String?,
      recordedAt: DateTime.parse(map['recordedAt'] as String),
    );
  }
}
