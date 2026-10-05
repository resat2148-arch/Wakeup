import '../models/wake_alarm.dart';

/// [alarm]'ın [now]'dan sonraki ilk çalma zamanı.
///
/// Tekrarlayan alarmlar için seçili günlerden ilki, tek seferlikler için
/// bugün (henüz geçmediyse) ya da yarın döner.
DateTime nextOccurrence(WakeAlarm alarm, DateTime now) {
  for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
    final day = DateTime(now.year, now.month, now.day + dayOffset);
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      alarm.hour,
      alarm.minute,
    );
    if (!candidate.isAfter(now)) continue;
    if (alarm.repeats && !alarm.weekdays.contains(candidate.weekday)) continue;
    return candidate;
  }
  // Tekrarlayan alarmın en az bir günü olduğundan buraya ulaşılmaz.
  throw StateError('Alarm ${alarm.id} için çalma zamanı bulunamadı');
}

/// "7 saat 25 dakika sonra" gibi okunabilir kalan süre.
String timeUntilText(DateTime target, DateTime now) {
  final diff = target.difference(now);
  final totalMinutes = (diff.inSeconds / 60).ceil();
  final days = totalMinutes ~/ (60 * 24);
  final hours = (totalMinutes % (60 * 24)) ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days gün',
    if (hours > 0) '$hours saat',
    if (minutes > 0 && days == 0) '$minutes dakika',
  ];
  if (parts.isEmpty) return '1 dakikadan az sonra';
  return '${parts.join(' ')} sonra';
}

const weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const weekdayLong = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String twoDigits(int n) => n.toString().padLeft(2, '0');

String formatTime(int hour, int minute) =>
    '${twoDigits(hour)}:${twoDigits(minute)}';

/// Alarmın hangi günler çaldığını özetler.
String repeatSummary(Set<int> weekdays) {
  if (weekdays.isEmpty) return 'Bir kez';
  if (weekdays.length == 7) return 'Her gün';
  if (weekdays.length == 5 && weekdays.containsAll({1, 2, 3, 4, 5})) {
    return 'Hafta içi';
  }
  if (weekdays.length == 2 && weekdays.containsAll({6, 7})) {
    return 'Hafta sonu';
  }
  final sorted = weekdays.toList()..sort();
  return sorted.map((d) => weekdayShort[d - 1]).join(', ');
}
