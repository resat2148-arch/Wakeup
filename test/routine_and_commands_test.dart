import 'package:flutter_test/flutter_test.dart';
import 'package:wakeup_coach/logic/routine_session.dart';
import 'package:wakeup_coach/logic/stats.dart';
import 'package:wakeup_coach/logic/voice_commands.dart';
import 'package:wakeup_coach/models/routine_step.dart';
import 'package:wakeup_coach/models/user_settings.dart';
import 'package:wakeup_coach/models/wake_record.dart';

void main() {
  group('RoutineSession', () {
    test('kapalı adımlar rutine dahil edilmez', () {
      final steps = [
        defaultRoutine[0],
        defaultRoutine[1].copyWith(enabled: false),
        defaultRoutine[2],
      ];
      final session = RoutineSession(steps);
      expect(session.total, 2);
      expect(session.current!.id, defaultRoutine[0].id);
    });

    test('tamamla ve atla sayılır, sonunda biter', () {
      final session = RoutineSession(defaultRoutine.take(3).toList());
      session.complete();
      session.skip();
      expect(session.isLast, isTrue);
      session.complete();
      expect(session.isFinished, isTrue);
      expect(session.current, isNull);
      expect(session.doneCount, 2);
      expect(session.skippedCount, 1);
      expect(session.progress, 1);
      // Bittikten sonra çağrılar etkisizdir.
      session.complete();
      expect(session.doneCount, 2);
    });

    test('boş rutin hemen biter', () {
      final session = RoutineSession(const []);
      expect(session.isFinished, isTrue);
      expect(session.progress, 1);
    });
  });

  group('parseVoiceCommand', () {
    test('Türkçe onay ifadeleri', () {
      for (final s in [
        'Tamam',
        'yaptım',
        'BİTTİ',
        'tamamdır!',
        'su içtim',
        'Hazırım.',
      ]) {
        expect(parseVoiceCommand(s), VoiceCommand.done, reason: s);
      }
    });

    test('atla, tekrar, bekle, devam', () {
      expect(parseVoiceCommand('bunu atla'), VoiceCommand.skip);
      expect(parseVoiceCommand('sonraki'), VoiceCommand.skip);
      expect(parseVoiceCommand('Tekrar söyler misin'), VoiceCommand.repeat);
      expect(parseVoiceCommand('bir dakika'), VoiceCommand.pause);
      expect(parseVoiceCommand('devam et'), VoiceCommand.resume);
    });

    test('ilgisiz konuşma komut sayılmaz', () {
      expect(parseVoiceCommand(''), isNull);
      expect(parseVoiceCommand('bugün hava güzel'), isNull);
      // "tamamen" kelimesi "tamam" sayılmamalı.
      expect(parseVoiceCommand('tamamen uyumuşum'), isNull);
    });

    test('büyük I/İ harflerini doğru küçültür', () {
      expect(normalizeTurkish('IŞIK İÇTİM'), 'ışık içtim');
    });
  });

  group('istatistik', () {
    WakeRecord record(DateTime day, {bool completed = true, int latency = 30}) {
      final ring = DateTime(day.year, day.month, day.day, 7);
      return WakeRecord(
        ringAt: ring,
        awakeAt: ring.add(Duration(seconds: latency)),
        completedAt: completed ? ring.add(const Duration(minutes: 10)) : null,
        stepsDone: completed ? 5 : 0,
        stepsTotal: 8,
      );
    }

    test('ardışık günleri sayar, bugün henüz yapılmadıysa dünden başlar', () {
      final now = DateTime(2026, 10, 5, 6);
      final records = [
        record(DateTime(2026, 10, 1)),
        record(DateTime(2026, 10, 2)),
        record(DateTime(2026, 10, 3)),
        record(DateTime(2026, 10, 4)),
      ];
      expect(currentStreak(records, now), 3 + 1);
      expect(
        currentStreak([...records, record(DateTime(2026, 10, 5))], now),
        5,
      );
    });

    test('kırılan seri sıfırlanır, tamamlanmamış günler sayılmaz', () {
      final now = DateTime(2026, 10, 5, 9);
      final records = [
        record(DateTime(2026, 10, 2)),
        record(DateTime(2026, 10, 4), completed: false),
      ];
      expect(currentStreak(records, now), 0);
    });

    test('ortalama uyanma süresi', () {
      final records = [
        record(DateTime(2026, 10, 3), latency: 20),
        record(DateTime(2026, 10, 4), latency: 40),
      ];
      expect(averageWakeLatency(records), const Duration(seconds: 30));
      expect(averageWakeLatency(const []), isNull);
    });
  });

  test('UserSettings JSON gidiş-dönüş ve eksik alanlarda varsayılanlar', () {
    const settings = UserSettings(
      name: 'Reşat',
      maxSnoozes: 0,
      voiceCommands: false,
    );
    expect(
      UserSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
    expect(
      UserSettings.fromJson(const {}).toJson(),
      const UserSettings().toJson(),
    );
  });
}
