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
    test('her cümle dokunmaya çağırır ve yer tutucu bırakmaz', () {
      final engine = MotivationEngine(random: Random(1));
      for (var level = 1; level <= 3; level++) {
        for (var i = 0; i < 30; i++) {
          final line = engine
              .wakeCall(
                level,
                MotivationContext(
                  now: monday,
                  name: 'Reşat',
                  reason: 'sabah koşusu',
                  streak: 4,
                ),
              )
              .text;
          expect(line.toLowerCase(), contains('ekrana dokun'), reason: line);
          expect(line, isNot(contains('{')));
        }
      }
    });

    test('isim yoksa cümleler bozulmadan kalır', () {
      final engine = MotivationEngine(random: Random(2));
      for (var level = 1; level <= 3; level++) {
        for (var i = 0; i < 30; i++) {
          final line = engine
              .wakeCall(level, MotivationContext(now: monday))
              .text;
          expect(line, isNot(contains('{')));
          expect(line, isNot(contains(' ,')));
          expect(line, isNot(contains('  ')));
          expect(line, isNot(contains('Hadi Battaniyeyi')));
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
        final line = engine
            .wakeCall(2, MotivationContext(now: monday, name: 'Ali'))
            .text;
        expect(line, isNot(contains('zinciri')));
        expect(line, isNot(contains('söz verdin')));
      }
    });

    test('aynı cümle art arda tekrarlanmaz', () {
      final engine = MotivationEngine(random: Random(4));
      final ctx = MotivationContext(now: monday, name: 'Ali');
      var previous = '';
      for (var i = 0; i < 40; i++) {
        final line = engine.wakeCall(1, ctx).text;
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
    test('hızlı uyanmayı, günü, saati ve nedeni anar', () {
      final engine = MotivationEngine(random: Random(5));
      final text = engine
          .awakeGreeting(
            MotivationContext(
              now: monday,
              name: 'Ayşe',
              reason: 'sıcak bir kahve',
            ),
            latency: const Duration(seconds: 12),
            stepCount: 8,
          )
          .text;
      expect(text, contains('12 saniyede'));
      expect(text, contains('Bugün pazartesi, saat yedi buçuk.'));
      expect(text, contains('sıcak bir kahve'));
      expect(text, contains('8 adımlık'));
      expect(text, contains('Ayşe'));
    });
  });

  group('rutin sözleri', () {
    test('ilk adımda "yaptım" ipucu verilir', () {
      final engine = MotivationEngine();
      final step = defaultRoutine.first;
      final first = engine
          .stepIntro(step, index: 0, total: 8, voiceCommands: true)
          .text;
      final touch = engine
          .stepIntro(step, index: 0, total: 8, voiceCommands: false)
          .text;
      final later = engine
          .stepIntro(step, index: 1, total: 8, voiceCommands: true)
          .text;
      expect(first, startsWith('1. adım: '));
      expect(first, contains('"yaptım" de'));
      expect(touch, contains('düğmesine dokun'));
      expect(later, isNot(contains('"yaptım" de')));
    });

    test('son adım olarak duyurulur', () {
      final engine = MotivationEngine();
      final text = engine
          .stepIntro(
            defaultRoutine.last,
            index: 7,
            total: 8,
            voiceCommands: false,
          )
          .text;
      expect(text, startsWith('Son adım: '));
    });

    test('kalan adım sayısı söylenir', () {
      final engine = MotivationEngine(random: Random(6));
      final ctx = MotivationContext(now: monday);
      expect(
        engine.stepDone(ctx, remaining: 1).text,
        endsWith('Sadece bir adım kaldı.'),
      );
      expect(
        engine.stepDone(ctx, remaining: 3).text,
        endsWith('Üç adım kaldı.'),
      );
    });

    test('finale seriyi ve tamamlanan adımları anar', () {
      final engine = MotivationEngine(random: Random(7));
      final full = engine
          .finale(
            MotivationContext(now: monday, name: 'Can', streak: 5),
            done: 8,
            total: 8,
          )
          .text;
      expect(full, contains('tüm 8 adımını'));
      expect(full, contains('5 gün'));

      final partial = engine
          .finale(MotivationContext(now: monday), done: 3, total: 8)
          .text;
      expect(partial, contains('8 adımın 3 tanesini'));
      expect(partial, isNot(contains('{')));
    });

    test('erteleme uyarısı kalan hakkı belirtir', () {
      final engine = MotivationEngine();
      final last = engine
          .snoozed(MotivationContext(now: monday, snoozesLeft: 0), 5)
          .text;
      expect(last, contains('5 dakika erteledim'));
      expect(last, contains('son ertelemeydi'));
    });
  });

  group('kayıtlı ses', () {
    final allIds = {
      for (final g in MotivationEngine.script())
        for (final l in g.lines) l.id,
    };

    test('kayıt varken konuşma parçaları kayda bağlanır', () {
      final engine = MotivationEngine(random: Random(8), clips: allIds);
      final speech = engine.awakeGreeting(
        MotivationContext(now: monday, name: 'Reşat', reason: 'koşu'),
        latency: const Duration(seconds: 20),
        stepCount: 8,
      );
      expect(speech.parts.every((p) => p.clip != null), isTrue);
      expect(
        speech.parts.map((p) => p.clip),
        containsAll(['awake_fast', 'day_1', 'awake_reason', 'routine_start']),
      );
      // Altyazı da kaydedilen metne uyar: değişken bilgi içermez.
      expect(speech.text, isNot(contains('20 saniye')));

      final step = engine.stepIntro(
        defaultRoutine[1],
        index: 1,
        total: 8,
        voiceCommands: true,
      );
      expect(step.parts.single.clip, 'step_light');
      expect(step.text, isNot(contains('2. adım')));
    });

    test('kayıt varken kaydı olan cümleler tercih edilir', () {
      final engine = MotivationEngine(
        random: Random(9),
        clips: {'wake_gentle_2'},
      );
      for (var i = 0; i < 10; i++) {
        final speech = engine.wakeCall(1, MotivationContext(now: monday));
        expect(speech.parts.single.clip, 'wake_gentle_2');
      }
    });

    test('kaydı olmayan cümle metin okumaya düşer', () {
      final engine = MotivationEngine(clips: {'praise_1'});
      final speech = engine.timerHalfway();
      expect(speech.parts.single.clip, isNull);
      expect(speech.text, 'Yarıladık, devam!');
    });

    test('seslendirme metninde kimlikler benzersiz ve değişken içermez', () {
      final lines = [for (final g in MotivationEngine.script()) ...g.lines];
      expect(lines.map((l) => l.id).toSet(), hasLength(lines.length));
      for (final l in lines) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(l.id), isTrue, reason: l.id);
        final vars = RegExp(r'\{(\w+)\}')
            .allMatches(l.scriptText)
            .map((m) => m[1])
            .toSet();
        // Kayıtta yalnızca isteğe bağlı isim olabilir.
        expect(vars.difference({'ad'}), isEmpty, reason: l.id);
      }
      expect(
        lines.map((l) => l.id),
        containsAll(defaultRoutine.map(MotivationEngine.stepClipId)),
      );
    });
  });
}
