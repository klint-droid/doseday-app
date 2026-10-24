import 'dart:convert';

class Medication {
  const Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.dosageUnit,
    this.instructions = '',
    required this.startDate,
    this.endDate,
    required this.stockQuantity,
    required this.refillThreshold,
    required this.times,
    this.isActive = true,
    this.trackingSince,
  });

  final int? id;
  final String name;
  final String dosage;
  final String dosageUnit;
  final String instructions;
  final String startDate; // yyyy-MM-dd
  final String? endDate; // yyyy-MM-dd
  final int stockQuantity;
  final int refillThreshold;
  final List<String> times; // HH:mm local times
  final bool isActive;

  /// ISO timestamp of the last schedule change. Doses scheduled before this
  /// moment are never auto-marked as missed.
  final String? trackingSince;

  static const units = ['tablet(s)', 'capsule(s)', 'mg', 'mL', 'drop(s)', 'puff(s)', 'other'];
  static const _countableUnits = {'tablet(s)', 'capsule(s)', 'drop(s)', 'puff(s)'};

  bool get needsRefill => stockQuantity <= refillThreshold;

  String get doseLabel => '$dosage $dosageUnit';

  /// How many stock units one dose consumes (e.g. "2 tablet(s)" -> 2).
  int get unitsPerDose {
    if (!_countableUnits.contains(dosageUnit)) return 1;
    final n = double.tryParse(dosage);
    if (n == null || n <= 0) return 1;
    return n.ceil();
  }

  bool isScheduledOn(String day) =>
      isActive &&
      startDate.compareTo(day) <= 0 &&
      (endDate == null || endDate!.compareTo(day) >= 0);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'dosage_unit': dosageUnit,
        'instructions': instructions,
        'start_date': startDate,
        'end_date': endDate,
        'stock_quantity': stockQuantity,
        'refill_threshold': refillThreshold,
        'times_json': jsonEncode(times),
        'is_active': isActive ? 1 : 0,
        'tracking_since': trackingSince,
      };

  factory Medication.fromMap(Map<String, Object?> map) => Medication(
        id: map['id'] as int?,
        name: map['name'] as String,
        dosage: map['dosage'] as String,
        dosageUnit: map['dosage_unit'] as String,
        instructions: (map['instructions'] as String?) ?? '',
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String?,
        stockQuantity: (map['stock_quantity'] as int?) ?? 0,
        refillThreshold: (map['refill_threshold'] as int?) ?? 0,
        times: (jsonDecode((map['times_json'] as String?) ?? '[]') as List)
            .map((e) => e.toString())
            .toList(),
        isActive: ((map['is_active'] as int?) ?? 1) == 1,
        trackingSince: map['tracking_since'] as String?,
      );

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? dosageUnit,
    String? instructions,
    String? startDate,
    String? endDate,
    int? stockQuantity,
    int? refillThreshold,
    List<String>? times,
    bool? isActive,
    String? trackingSince,
    bool clearEndDate = false,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        dosageUnit: dosageUnit ?? this.dosageUnit,
        instructions: instructions ?? this.instructions,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        stockQuantity: stockQuantity ?? this.stockQuantity,
        refillThreshold: refillThreshold ?? this.refillThreshold,
        times: times ?? this.times,
        isActive: isActive ?? this.isActive,
        trackingSince: trackingSince ?? this.trackingSince,
      );
}
