class ReminderCompletion {
  final String id; // reminderId_date formatında
  final String reminderId;
  final DateTime completedDate;
  final DateTime completedAt;
  // Veteriner masraf bilgileri (opsiyonel)
  final String? vetClinicName;
  final double? cost;
  final String? currency;
  final String? notes;

  ReminderCompletion({
    required this.id,
    required this.reminderId,
    required this.completedDate,
    required this.completedAt,
    this.vetClinicName,
    this.cost,
    this.currency,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'completedDate': completedDate.toIso8601String().split('T')[0],
      'completedAt': completedAt.toIso8601String(),
      'vetClinicName': vetClinicName,
      'cost': cost,
      'currency': currency,
      'notes': notes,
    };
  }

  factory ReminderCompletion.fromMap(Map<String, dynamic> map) {
    return ReminderCompletion(
      id: map['id'] as String,
      reminderId: map['reminderId'] as String,
      completedDate: DateTime.parse(map['completedDate'] as String),
      completedAt: DateTime.parse(map['completedAt'] as String),
      vetClinicName: map['vetClinicName'] as String?,
      cost: (map['cost'] as num?)?.toDouble(),
      currency: map['currency'] as String?,
      notes: map['notes'] as String?,
    );
  }

  ReminderCompletion copyWith({
    DateTime? completedDate,
    DateTime? completedAt,
    String? vetClinicName,
    double? cost,
    String? currency,
    String? notes,
  }) {
    return ReminderCompletion(
      id: id,
      reminderId: reminderId,
      completedDate: completedDate ?? this.completedDate,
      completedAt: completedAt ?? this.completedAt,
      vetClinicName: vetClinicName ?? this.vetClinicName,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  /// Masraf bilgisi var mı?
  bool get hasExpense => cost != null && cost! > 0;

  /// Formatlanmış masraf string'i
  String get formattedCost {
    if (!hasExpense) return '';
    final currencySymbol = _getCurrencySymbol(currency ?? 'TRY');
    return '$currencySymbol${cost!.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'TRY':
        return '₺';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currencyCode;
    }
  }
}
