import '../models/wake_record.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Rutinin tamamlandığı ardışık gün sayısı. Bugün henüz tamamlanmadıysa
/// dünden geriye doğru sayılır, böylece seri sabah erkenden "0" görünmez.
int currentStreak(List<WakeRecord> records, DateTime now) {
  final days = records
      .where((r) => r.completed)
      .map((r) => _dateOnly(r.awakeAt))
      .toSet();
  var day = _dateOnly(now);
  if (!days.contains(day)) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Son [lastN] sabahın ortalama uyanma süresi (alarm → dokunma).
Duration? averageWakeLatency(List<WakeRecord> records, {int lastN = 7}) {
  if (records.isEmpty) return null;
  final recent = records.length > lastN
      ? records.sublist(records.length - lastN)
      : records;
  final totalMs = recent.fold<int>(
    0,
    (sum, r) => sum + r.wakeLatency.inMilliseconds,
  );
  return Duration(milliseconds: totalMs ~/ recent.length);
}

int completedCount(List<WakeRecord> records) =>
    records.where((r) => r.completed).length;
