import 'package:flutter/widgets.dart';

import '../logic/motivation.dart';
import '../state/app_state.dart';
import 'alarm_scheduler.dart';
import 'listener.dart';
import 'voice.dart';

/// Uygulama genelinde paylaşılan servisler.
class Services {
  Services({
    required this.state,
    required this.scheduler,
    required this.voice,
    required this.listener,
    required this.motivation,
  });

  final AppState state;
  final AlarmScheduler scheduler;
  final VoiceService voice;
  final CommandListener listener;
  final MotivationEngine motivation;
}

/// Servisleri widget ağacına sağlar.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
