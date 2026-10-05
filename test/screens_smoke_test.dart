import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakeup_coach/app.dart';
import 'package:wakeup_coach/logic/motivation.dart';
import 'package:wakeup_coach/models/user_settings.dart';
import 'package:wakeup_coach/models/wake_alarm.dart';
import 'package:wakeup_coach/screens/onboarding_screen.dart';
import 'package:wakeup_coach/screens/settings_screen.dart';
import 'package:wakeup_coach/services/services.dart';
import 'package:wakeup_coach/services/storage.dart';
import 'package:wakeup_coach/state/app_state.dart';

import 'fakes.dart';

Future<Services> _services({required bool onboarded}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await Storage.open();
  final scheduler = FakeScheduler();
  final state = AppState(storage, scheduler);
  await state.saveSettings(UserSettings(name: 'Reşat', onboarded: onboarded));
  if (onboarded) {
    await state.saveAlarm(
      const WakeAlarm(
        id: 3,
        hour: 6,
        minute: 45,
        weekdays: {1, 2, 3, 4, 5},
        label: 'İş günü',
        reason: 'sıcak bir kahve',
      ),
    );
  }
  return Services(
    state: state,
    scheduler: scheduler,
    voice: FakeVoice(),
    listener: FakeListener(),
    motivation: MotivationEngine(),
  );
}

Finder _scrollableIn(Finder screen) =>
    find.descendant(of: screen, matching: find.byType(Scrollable)).first;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Gün doğumu sahnesindeki sürekli animasyonları kapat (pumpAndSettle için).
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets('ilk açılışta tanıtım ekranı görünür', (tester) async {
    _phone(tester);
    final services = (await tester.runAsync(
      () => _services(onboarded: false),
    ))!;
    await tester.pumpWidget(WakeUpApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('Günaydın Koçu'), findsOneWidget);
    expect(find.text('Dokun = uyandım'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Başlayalım'),
      300,
      scrollable: _scrollableIn(find.byType(OnboardingScreen)),
    );
    expect(find.text('Başlayalım'), findsOneWidget);
  });

  testWidgets('ana ekran, alarm düzenleme, rutin ve ayarlar açılır', (
    tester,
  ) async {
    _phone(tester);
    final services = (await tester.runAsync(() => _services(onboarded: true)))!;
    await tester.pumpWidget(WakeUpApp(services: services));
    await tester.pumpAndSettle();

    // Ana ekran
    expect(find.text('06:45'), findsWidgets);
    expect(find.text('Hafta içi · İş günü'), findsOneWidget);
    expect(find.text('🎯 sıcak bir kahve'), findsOneWidget);
    expect(find.text('günlük seri'), findsOneWidget);

    // Deneme alarmı
    await tester.tap(find.text('Şimdi dene'));
    await tester.pump();

    // Alarm düzenleme
    await tester.tap(find.text('Hafta içi · İş günü'));
    await tester.pumpAndSettle();
    expect(find.text('Alarmı düzenle'), findsOneWidget);
    expect(find.text('Bu sabah seni ne bekliyor? 🎯'), findsOneWidget);
    await tester.tap(find.text('sabah sporum'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'sabah sporum'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri')); // Türkçe arayüzde "Back" yerine
    await tester.pumpAndSettle();

    // Rutin
    await tester.tap(find.byTooltip('Sabah rutini'));
    await tester.pumpAndSettle();
    expect(find.text('Sabah rutini'), findsOneWidget);
    expect(find.text('Bir dakika hareket'), findsOneWidget);
    await tester.tap(find.text('Bir dakika hareket'));
    await tester.pumpAndSettle();
    expect(find.text('Adımı düzenle'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Adımı düzenle'), findsNothing);
    await tester.tap(find.byTooltip('Geri')); // Türkçe arayüzde "Back" yerine
    await tester.pumpAndSettle();

    // Ayarlar
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tekrar uyuma koruması'),
      300,
      scrollable: _scrollableIn(find.byType(SettingsScreen)),
    );
    expect(find.text('Tekrar uyuma koruması'), findsOneWidget);
    expect(find.text('Erteleme hakkı'), findsOneWidget);
  });
}
