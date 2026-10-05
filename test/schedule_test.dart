import 'package:flutter_test/flutter_test.dart';
import 'package:wakeup_coach/logic/schedule.dart';
import 'package:wakeup_coach/models/wake_alarm.dart';

void main() {
  // 2026-10-05 bir Pazartesi.
  final mondayMorning = DateTime(2026, 10, 5, 6, 30);

  group('nextOccurrence', () {
    test('tek seferlik alarm henüz geçmediyse bugün çalar', () {
      const alarm = WakeAlarm(id: 1, hour: 7, minute: 0);
      expect(nextOccurrence(alarm, mondayMorning), DateTime(2026, 10, 5, 7));
    });

    test('tek seferlik alarm geçtiyse yarın çalar', () {
      const alarm = WakeAlarm(id: 1, hour: 6, minute: 0);
      expect(nextOccurrence(alarm, mondayMorning), DateTime(2026, 10, 6, 6));
    });

    test('tam şu ana kurulan alarm bir sonraki güne kayar', () {
      const alarm = WakeAlarm(id: 1, hour: 6, minute: 30);
      expect(
        nextOccurrence(alarm, mondayMorning),
        DateTime(2026, 10, 6, 6, 30),
      );
    });

    test('hafta içi alarmı Cuma akşamından sonra Pazartesiye atlar', () {
      const alarm = WakeAlarm(
        id: 1,
        hour: 7,
        minute: 0,
        weekdays: {1, 2, 3, 4, 5},
      );
      final fridayNight = DateTime(2026, 10, 9, 22);
      expect(nextOccurrence(alarm, fridayNight), DateTime(2026, 10, 12, 7));
    });

    test('yalnızca bugün seçiliyse ve saat geçtiyse bir hafta sonrası', () {
      const alarm = WakeAlarm(id: 1, hour: 6, minute: 0, weekdays: {1});
      expect(nextOccurrence(alarm, mondayMorning), DateTime(2026, 10, 12, 6));
    });

    test('ay ve yıl sınırını doğru geçer', () {
      const alarm = WakeAlarm(id: 1, hour: 7, minute: 0);
      expect(
        nextOccurrence(alarm, DateTime(2026, 12, 31, 23)),
        DateTime(2027, 1, 1, 7),
      );
    });
  });

  group('metinler', () {
    test('repeatSummary', () {
      expect(repeatSummary({}), 'Bir kez');
      expect(repeatSummary({1, 2, 3, 4, 5}), 'Hafta içi');
      expect(repeatSummary({6, 7}), 'Hafta sonu');
      expect(repeatSummary({1, 2, 3, 4, 5, 6, 7}), 'Her gün');
      expect(repeatSummary({3, 1}), 'Pzt, Çar');
    });

    test('timeUntilText', () {
      final now = DateTime(2026, 10, 5, 22, 0);
      expect(
        timeUntilText(DateTime(2026, 10, 6, 7, 30), now),
        '9 saat 30 dakika sonra',
      );
      expect(
        timeUntilText(DateTime(2026, 10, 5, 22, 0, 20), now),
        '1 dakika sonra',
      );
      expect(
        timeUntilText(DateTime(2026, 10, 8, 7, 0), now),
        '2 gün 9 saat sonra',
      );
    });

    test('formatTime', () {
      expect(formatTime(7, 5), '07:05');
    });
  });

  test('WakeAlarm JSON gidiş-dönüş', () {
    const alarm = WakeAlarm(
      id: 9,
      hour: 6,
      minute: 45,
      weekdays: {1, 3},
      label: 'Spor',
      reason: 'koşu',
      sound: AlarmSound.energy,
    );
    final back = WakeAlarm.fromJson(alarm.toJson());
    expect(back.toJson(), alarm.toJson());
  });
}
