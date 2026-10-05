import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'logic/motivation.dart';
import 'services/alarm_scheduler.dart';
import 'services/listener.dart';
import 'services/services.dart';
import 'services/storage.dart';
import 'services/voice.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final scheduler = AlarmScheduler();
  await scheduler.init();

  final storage = await Storage.open();
  final state = AppState(storage, scheduler);

  final voice = VoiceService();
  await voice.init(
    rate: state.settings.speechRate,
    pitch: state.settings.pitch,
  );

  final services = Services(
    state: state,
    scheduler: scheduler,
    voice: voice,
    listener: CommandListener(),
    // Kayıtlı ses dosyaları varsa motor onları tercih eder.
    motivation: MotivationEngine(clips: voice.clipIds),
  );

  runApp(WakeUpApp(services: services));

  // Uygulama her açıldığında tekrarlayan alarmları bir sonraki güne kur.
  unawaited(state.sync());
}
