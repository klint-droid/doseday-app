class DoseStatus {
  static const taken = 'taken';
  static const skipped = 'skipped';
  static const missed = 'missed';
}

class DoseLog {
  const DoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.recordedAt,
  });

  final int id;
  final int medicationId;
  final String scheduledDate; // yyyy-MM-dd
  final String scheduledTime; // HH:mm
  final String status; // taken | skipped | missed
  final String recordedAt;

  factory DoseLog.fromMap(Map<String, Object?> m) => DoseLog(
        id: m['id'] as int,
        medicationId: m['medication_id'] as int,
        scheduledDate: m['scheduled_date'] as String,
        scheduledTime: m['scheduled_time'] as String,
        status: m['status'] as String,
        recordedAt: m['recorded_at'] as String,
      );
}
