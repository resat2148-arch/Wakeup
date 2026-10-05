import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wakeup_coach/logic/motivation.dart';
import 'package:wakeup_coach/models/routine_step.dart';

void main() {
  final monday = DateTime(2026, 10, 5, 7, 30);

  group('spokenTime', () {
    test('saatleri Türkçe yazıyla okur', () {
      expect(spokenTime(DateTime(2026, 1, 1, 7, 0)), 'saat yedi');
      expect(spokenTime(DateTime(2026, 1, 1, 7, 30)), 'saat yedi buçuk');
      expect(spokenTime(DateTime(2026, 1, 1, 6, 45)), 'saat altı kırk beş');
      expect(spokenTime(DateTime(2026, 1, 1, 10, 5)), 'saat on beş');
      expect(spokenTime(DateTime(2026, 1, 1, 0, 15)), 'saat sıfır on beş');
    });

    test('turkishNumber', () {
      expect(turkishNumber(0), 'sıfır');
      expect(turkishNumber(9), 'dokuz');
      expect(turkishNumber(20), 'yirmi');
      expect(turkishNumber(59), 'elli dokuz');
    });
  });

  group('wakeCall', () {
    test('her cümle bir kez dokunmaya çağırır ve yer tutucu bırakmaz', () {
      final engine = MotivationEngine(random: Random(1));
      for (var level = 1; level <= 3; level++) {
        for (var i = 0; i < 30; i++) {
          final line = engine.wakeCall(
            level,
            MotivationContext(
              now: monday,
              name: 'Reşat',
              reason: 'sabah koşusu',
              streak: 4,
            ),
          );
          expect(
            'ekrana dokun'.allMatches(line.toLowerCase()).length,
            1,
            reason: line,
          );
          expect(line, isNot(contains('{')));
        }
      }
    });

    test('isim yoksa cümleler bozulmadan kalır', () {
      final engine = MotivationEngine(random: Random(2));
      for (var level = 1; level <= 3; level++) {
        for (var i = 0; i < 30; i++) {
          final line = engine.wakeCall(level, MotivationContext(now: monday));
          expect(line, isNot(contains('{')));
          expect(line, isNot(contains(' ,')));
          expect(line, isNot(contains('  ')));
          expect(line, isNot(contains('Hadi Battaniyeyi')));
          expect(line, isNot(startsWith(',')));
          expect(
            RegExp(r'^\p{Lu}', unicode: true).hasMatch(line),
            isTrue,
            reason: line,
          );
        }
      }
    });

    test('neden ve seri yoksa bunlara dayanan cümleler seçilmez', () {
      final engine = MotivationEngine(random: Random(3));
      for (var i = 0; i < 60; i++) {
        final line = engine.wakeCall(
          2,
          MotivationContext(now: monday, name: 'Ali'),
        );
        expect(line, isNot(contains('zinciri')));
        expect(line, isNot(contains('bekliyor. Kalkmak')));
      }
    });

    test('aynı cümle art arda tekrarlanmaz', () {
      final engine = MotivationEngine(random: Random(4));
      final ctx = MotivationContext(now: monday, name: 'Ali');
      var previous = '';
      for (var i = 0; i < 40; i++) {
        final line = engine.wakeCall(1, ctx);
        expect(line, isNot(previous));
        previous = line;
      }
    });

    test('seviye uyanma süresiyle yükselir', () {
      expect(MotivationEngine.levelFor(const Duration(seconds: 10)), 1);
      expect(MotivationEngine.levelFor(const Duration(seconds: 60)), 2);
      expect(MotivationEngine.levelFor(const Duration(minutes: 5)), 3);
    });
  });

  group('awakeGreeting', () {
    test('hızlı uyanmayı, günü ve nedeni anar', () {
      final engine = MotivationEngine(random: Random(5));
      final text = engine.awakeGreeting(
        MotivationContext(now: monday, name: 'Ayşe', reason: 'sıcak bir kahve'),
        latency: const Duration(seconds: 12),
        stepCount: 8,
      );
      expect(text, contains('12 saniyede'));
      expect(text, contains('pazartesi'));
      expect(text, contains('saat yedi buçuk'));
      expect(text, contains('sıcak bir kahve'));
      expect(text, contains('8 adımlık'));
      expect(text, contains('Ayşe'));
    });
  });

  group('rutin sözleri', () {
    test('ilk adımda sesli komut ipucu verilir', () {
      final engine = MotivationEngine();
      final step = defaultRoutine.first;
      final first = engine.stepIntro(
        step,
        index: 0,
        total: 8,
        voiceCommands: true,
      );
      final later = engine.stepIntro(
        step,
        index: 1,
        total: 8,
        voiceCommands: true,
      );
      expect(first, startsWith('1. adım: '));
      expect(first, contains('"tamam" de'));
      expect(later, isNot(contains('"tamam" de')));
    });

    test('son adım olarak duyurulur', () {
      final engine = MotivationEngine();
      final text = engine.stepIntro(
        defaultRoutine.last,
        index: 7,
        total: 8,
        voiceCommands: false,
      );
      expect(text, startsWith('Son adım: '));
    });

    test('kalan adım sayısı söylenir', () {
      final engine = MotivationEngine(random: Random(6));
      final ctx = MotivationContext(now: monday);
      expect(
        engine.stepDone(ctx, remaining: 1),
        endsWith('Sadece bir adım kaldı.'),
      );
      expect(engine.stepDone(ctx, remaining: 3), endsWith('3 adım kaldı.'));
    });

    test('finale seriyi ve tamamlanan adımları anar', () {
      final engine = MotivationEngine(random: Random(7));
      final full = engine.finale(
        MotivationContext(now: monday, name: 'Can', streak: 5),
        done: 8,
        total: 8,
      );
      expect(full, contains('tüm 8 adımını'));
      expect(full, contains('5 gün'));

      final partial = engine.finale(
        MotivationContext(now: monday),
        done: 3,
        total: 8,
      );
      expect(partial, contains('8 adımın 3 tanesini'));
      expect(partial, isNot(contains('{')));
    });

    test('erteleme uyarısı kalan hakkı belirtir', () {
      final engine = MotivationEngine();
      final last = engine.snoozed(
        MotivationContext(now: monday, snoozesLeft: 0),
        5,
      );
      expect(last, contains('5 dakika erteledim'));
      expect(last, contains('son ertelemeydi'));
    });
  });
}
