import 'dart:async';

import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/wake_screen.dart';
import 'services/services.dart';
import 'theme.dart';

class WakeUpApp extends StatefulWidget {
  const WakeUpApp({super.key, required this.services});

  final Services services;

  @override
  State<WakeUpApp> createState() => _WakeUpAppState();
}

class _WakeUpAppState extends State<WakeUpApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AlarmSet>? _ringingSub;
  bool _wakeScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _ringingSub = widget.services.scheduler.ringing.listen(_onRinging);
  }

  /// Alarm çalmaya başladığında uyandırma ekranını aç.
  void _onRinging(AlarmSet set) {
    if (set.alarms.isEmpty || _wakeScreenOpen) return;
    final alarm = set.alarms.first;
    _wakeScreenOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = _navigatorKey.currentState;
      if (nav == null) {
        _wakeScreenOpen = false;
        return;
      }
      await nav.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => WakeScreen(ringing: alarm),
        ),
      );
      _wakeScreenOpen = false;
    });
  }

  @override
  void dispose() {
    _ringingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.services.state;
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Günaydın Koçu',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ListenableBuilder(
          listenable: state,
          builder: (context, _) => state.settings.onboarded
              ? const HomeScreen()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
