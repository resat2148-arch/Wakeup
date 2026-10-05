import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakeup_coach/logic/motivation.dart';
import 'package:wakeup_coach/models/routine_step.dart';
import 'package:wakeup_coach/models/user_settings.dart';
import 'package:wakeup_coach/models/wake_alarm.dart';
import 'package:wakeup_coach/screens/wake_screen.dart';
import 'package:wakeup_coach/services/services.dart';
import 'package:wakeup_coach/services/storage.dart';
import 'package:wakeup_coach/state/app_state.dart';

import 'fakes.dart';

const _alarm = WakeAlarm(
  id: 7,
  hour: 7,
  minute: 0,
  weekdays: {1, 2, 3, 4, 5},
  reason: 'sabah koşusu',
);

const _shortRoutine = [
  RoutineStep(
    id: 'a',
    emoji: '☀️',
    title: 'Perdeyi aç',
    instruction: 'Perdeyi aç.',
  ),
  RoutineStep(id: 'b', emoji: '💧', title: 'Su iç', instruction: 'Su iç.'),
  RoutineStep(
    id: 'c',
    emoji: '🌬️',
    title: 'Nefes',
    instruction: 'Nefes al.',
    durationSeconds: 5,
  ),
];

Future<(Services, FakeVoice, FakeScheduler)> _setUp({
  UserSettings settings = const UserSettings(
    name: 'Reşat',
    onboarded: true,
    voiceCommands: false,
    maxSnoozes: 1,
  ),
  FakeListener? listener,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await Storage.open();
  final scheduler = FakeScheduler();
  final state = AppState(storage, scheduler);
  await state.saveSettings(settings);
  await state.saveRoutine(_shortRoutine);
  await state.saveAlarm(_alarm);
  final voice = FakeVoice();
  final services = Services(
    state: state,
    scheduler: scheduler,
    voice: voice,
    listener: listener ?? FakeListener(),
    motivation: MotivationEngine(),
  );
  return (services, voice, scheduler);
}

Widget _app(Services services, AlarmSettings ringing) => AppScope(
  services: services,
  child: MaterialApp(home: WakeScreen(ringing: ringing)),
);

AlarmSettings _ringing() => AlarmSettings(
  id: _alarm.id,
  dateTime: DateTime.now(),
  volumeSettings: const VolumeSettings.fixed(),
  notificationSettings: const NotificationSettings(title: 't', body: 'b'),
);

/// Uyku korumasının sorduğu cümlelerden herhangi biri.
final _idleQuestion = RegExp(
  'benimle misin|sessizleştin|geri dönmek yok',
  caseSensitive: false,
);

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('eller serbest: "yaptım" dedikçe rutin ilerler ve biter', (
    tester,
  ) async {
    final mic = FakeListener(enabled: true);
    final (services, voice, _) =
        await tester.runAsync(
          () => _setUp(
            settings: const UserSettings(
              name: 'Reşat',
              onboarded: true,
              voiceCommands: true,
              sleepBackGuardSeconds: 60,
            ),
            listener: mic,
          ),
        ) ??
        (throw StateError('kurulum'));

    await tester.pumpWidget(_app(services, _ringing()));
    await tester.pump();
    // Uyanmak için ekrana dokunulur (alarm sesi konuşmayı bastırır).
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    await tester.pump();
    expect(find.text('Perdeyi aç'), findsOneWidget);
    expect(
      voice.spoken.last,
      contains('"yaptım" de'),
      reason: 'ilk adımda eller serbest ipucu verilmeli',
    );

    // Konuşma bitince mikrofon hemen açılır.
    await _seconds(tester, 1);
    expect(mic.isListening, isTrue);
    expect(find.textContaining('Dinliyorum'), findsOneWidget);

    expect(mic.hear('yaptım'), isTrue);
    await tester.pump();
    expect(find.text('Su iç'), findsOneWidget);

    // İlgisiz konuşma adımı geçmez.
    await _seconds(tester, 2);
    expect(mic.hear('bugün hava güzel'), isTrue);
    await tester.pump();
    expect(find.text('Su iç'), findsOneWidget);

    expect(mic.hear('Tamam, bitti.'), isTrue);
    await tester.pump();
    expect(find.text('Nefes'), findsOneWidget);

    // Zamanlı adımda "bekle" süreyi durdurur, "devam" sürdürür.
    await _seconds(tester, 2);
    expect(mic.hear('bekle'), isTrue);
    await tester.pump();
    expect(voice.spoken.last, contains('bekliyorum'));
    await _seconds(tester, 10);
    expect(find.text('Güne hazırsın!'), findsNothing);
    expect(mic.hear('devam'), isTrue);
    await tester.pump();
    expect(voice.spoken.last, contains('Devam ediyoruz'));

    await _seconds(tester, 2);
    expect(mic.hear('yaptım'), isTrue);
    await tester.pump();
    expect(find.text('Güne hazırsın!'), findsOneWidget);
    expect(services.state.history.single.stepsDone, 3);
  });

  testWidgets('uyku korumasına sesle "buradayım" yanıtı adımı geçmez', (
    tester,
  ) async {
    final mic = FakeListener(enabled: true);
    final (services, voice, scheduler) =
        await tester.runAsync(
          () => _setUp(
            settings: const UserSettings(
              onboarded: true,
              voiceCommands: true,
              sleepBackGuardSeconds: 60,
            ),
            listener: mic,
          ),
        ) ??
        (throw StateError('kurulum'));

    await tester.pumpWidget(_app(services, _ringing()));
    await tester.pump();
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    await tester.pump();

    await _seconds(tester, 62);
    expect(voice.spoken.last, contains(_idleQuestion));
    await _seconds(tester, 2);
    // "Evet" normalde "yaptım" sayılır; burada yalnızca uyanıklık yanıtıdır.
    expect(mic.hear('evet'), isTrue);
    await tester.pump();
    expect(voice.spoken.last, contains('buradasın'));
    expect(find.text('Perdeyi aç'), findsOneWidget);

    await _seconds(tester, 40);
    expect(scheduler.calls, isNot(contains('reRing:7')));
  });

  testWidgets('alarm konuşur, dokunuşla uyanılır, rutin tamamlanır', (
    tester,
  ) async {
    final (services, voice, scheduler) =
        await tester.runAsync(_setUp) ?? (throw StateError('kurulum'));

    await tester.pumpWidget(_app(services, _ringing()));
    expect(find.text('Uyandıysan ekrana dokun'), findsOneWidget);
    expect(find.textContaining('sabah koşusu'), findsOneWidget);

    // Birkaç saniye sonra asistan konuşmaya başlar.
    await _seconds(tester, 5);
    expect(voice.spoken, isNotEmpty);
    expect(voice.spoken.first.toLowerCase(), contains('ekrana dokun'));

    // Ekrana dokunmak = uyandım.
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    await tester.pump();
    expect(scheduler.calls, contains('dismiss:7'));
    expect(find.text('Perdeyi aç'), findsOneWidget);
    expect(find.text('Adım 1 / 3'), findsOneWidget);
    final greeting = voice.spoken.firstWhere((s) => s.contains('1. adım'));
    expect(greeting, contains('Reşat'));
    expect(greeting, contains('sabah koşusu'));

    // Hızlı çift dokunuş iki adımı birden geçmemeli.
    await tester.tap(find.text('Yaptım'));
    await tester.pump();
    await tester.tap(find.text('Yaptım'));
    await tester.pump();
    expect(find.text('Su iç'), findsOneWidget);

    await _seconds(tester, 2);
    await tester.tap(find.text('Yaptım'));
    await tester.pump();
    expect(find.text('Nefes'), findsOneWidget);
    expect(voice.spoken.last, contains('Son adım: Nefes'));

    // Zamanlı adım kendiliğinden tamamlanır.
    await _seconds(tester, 7);
    expect(find.text('Güne hazırsın!'), findsOneWidget);
    expect(find.text('3/3 adım'), findsOneWidget);
    expect(voice.spoken.last, contains('tüm 3 adımını'));

    final history = services.state.history;
    expect(history, hasLength(1));
    expect(history.single.stepsDone, 3);
    expect(services.state.streak, 1);

    await tester.tap(find.text('Güne başla'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'rutin sırasında hareketsiz kalınca önce sorar, sonra alarmı yeniden çalar',
    (tester) async {
      final (services, voice, scheduler) =
          await tester.runAsync(
            () => _setUp(
              settings: const UserSettings(
                name: 'Reşat',
                onboarded: true,
                voiceCommands: false,
                sleepBackGuardSeconds: 60,
              ),
            ),
          ) ??
          (throw StateError('kurulum'));

      await tester.pumpWidget(_app(services, _ringing()));
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      await tester.pump();
      expect(find.text('Perdeyi aç'), findsOneWidget);

      await _seconds(tester, 61);
      expect(voice.spoken.last, contains(_idleQuestion));
      expect(scheduler.calls, isNot(contains('reRing:7')));

      await _seconds(tester, 31);
      expect(scheduler.calls, contains('reRing:7'));
      expect(find.text('Uyandıysan ekrana dokun'), findsOneWidget);
      // Erteleme, yeniden çalmada sunulmaz.
      expect(find.textContaining('ertele'), findsNothing);

      // Tekrar dokununca kaldığı adımdan devam eder.
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      await tester.pump();
      expect(find.text('Perdeyi aç'), findsOneWidget);
      expect(voice.spoken.any((s) => s.contains('Tekrar hoş geldin')), isTrue);
    },
  );

  testWidgets('dokunmak uyku korumasını sıfırlar', (tester) async {
    final (services, _, scheduler) =
        await tester.runAsync(
          () => _setUp(
            settings: const UserSettings(
              onboarded: true,
              voiceCommands: false,
              sleepBackGuardSeconds: 60,
            ),
          ),
        ) ??
        (throw StateError('kurulum'));

    await tester.pumpWidget(_app(services, _ringing()));
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      await _seconds(tester, 50);
      await tester.tapAt(const Offset(20, 300));
      await tester.pump();
    }
    await _seconds(tester, 40);
    expect(scheduler.calls, isNot(contains('reRing:7')));
  });

  testWidgets('erteleme düğmesi alarmı erteler ve uyarır', (tester) async {
    final (services, voice, scheduler) =
        await tester.runAsync(_setUp) ?? (throw StateError('kurulum'));

    await tester.pumpWidget(_app(services, _ringing()));
    await tester.tap(find.textContaining('dk ertele'));
    await tester.pump();
    await tester.pump();
    expect(scheduler.calls, ['snooze:5']);
    expect(scheduler.calls, isNot(contains('dismiss:7')));
    expect(voice.spoken.last, contains('5 dakika erteledim'));
  });
}
