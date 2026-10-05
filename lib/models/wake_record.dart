/// Bir sabahın kaydı: alarm ne zaman çaldı, ne zaman uyanıldı, rutin
/// ne kadar tamamlandı.
class WakeRecord {
  const WakeRecord({
    required this.ringAt,
    required this.awakeAt,
    this.completedAt,
    this.snoozes = 0,
    this.stepsDone = 0,
    this.stepsTotal = 0,
  });

  final DateTime ringAt;
  final DateTime awakeAt;
  final DateTime? completedAt;
  final int snoozes;
  final int stepsDone;
  final int stepsTotal;

  /// Alarmın çalmaya başlamasından ekrana dokunulmasına kadar geçen süre.
  Duration get wakeLatency => awakeAt.difference(ringAt);

  bool get completed => completedAt != null && stepsDone > 0;

  Map<String, dynamic> toJson() => {
    'ringAt': ringAt.toIso8601String(),
    'awakeAt': awakeAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'snoozes': snoozes,
    'stepsDone': stepsDone,
    'stepsTotal': stepsTotal,
  };

  factory WakeRecord.fromJson(Map<String, dynamic> json) {
    return WakeRecord(
      ringAt: DateTime.parse(json['ringAt'] as String),
      awakeAt: DateTime.parse(json['awakeAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      snoozes: json['snoozes'] as int? ?? 0,
      stepsDone: json['stepsDone'] as int? ?? 0,
      stepsTotal: json['stepsTotal'] as int? ?? 0,
    );
  }
}
