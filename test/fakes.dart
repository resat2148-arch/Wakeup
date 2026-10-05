import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';
import 'package:wakeup_coach/logic/voice_commands.dart';
import 'package:wakeup_coach/logic/speech.dart';
import 'package:wakeup_coach/models/user_settings.dart';
import 'package:wakeup_coach/models/wake_alarm.dart';
import 'package:wakeup_coach/services/alarm_scheduler.dart';
import 'package:wakeup_coach/services/listener.dart';
import 'package:wakeup_coach/services/voice.dart';

/// Söylenenleri kaydeden, hemen biten sahte ses servisi.
class FakeVoice extends VoiceService {
  final spoken = <String>[];
  final speeches = <Speech>[];

  @override
  Future<void> say(Speech speech) async {
    speeches.add(speech);
    spoken.add(speech.text);
  }

  @override
  Future<void> stop() async {}
}

/// Sahte mikrofon: testte [hear] ile kullanıcının söylediği simüle edilir.
class FakeListener extends CommandListener {
  FakeListener({this.enabled = false});

  final bool enabled;
  bool _listening = false;
  void Function(VoiceCommand)? _onCommand;
  VoidCallback? _onSpeech;
  int sessions = 0;

  @override
  Future<bool> prepare() async => enabled;

  @override
  bool get isListening => _listening;

  @override
  Future<void> listen(
    void Function(VoiceCommand command) onCommand, {
    VoidCallback? onSpeech,
    Duration listenFor = const Duration(seconds: 60),
  }) async {
    sessions++;
    _listening = true;
    _onCommand = onCommand;
    _onSpeech = onSpeech;
  }

  @override
  Future<void> stop() async => _listening = false;

  /// Kullanıcı bir şey söyler. Mikrofon o an dinlemiyorsa duyulmaz.
  bool hear(String words) {
    if (!_listening) return false;
    _onSpeech?.call();
    final command = parseVoiceCommand(words);
    if (command != null && _listening) {
      _listening = false;
      _onCommand?.call(command);
    }
    return true;
  }
}

/// Platform eklentisine dokunmadan çağrıları kaydeden sahte zamanlayıcı.
class FakeScheduler extends AlarmScheduler {
  final calls = <String>[];

  @override
  Stream<AlarmSet> get ringing => const Stream.empty();

  @override
  Future<DateTime> scheduleTest(
    UserSettings settings, {
    Duration delay = const Duration(seconds: 10),
  }) async {
    calls.add('test');
    return DateTime.now().add(delay);
  }

  @override
  Future<void> syncAll(List<WakeAlarm> alarms, UserSettings settings) async {}

  @override
  Future<void> dismiss(
    WakeAlarm? alarm,
    int ringingId,
    UserSettings settings,
  ) async => calls.add('dismiss:$ringingId');

  @override
  Future<void> snooze(AlarmSettings ringing, int minutes) async =>
      calls.add('snooze:$minutes');

  @override
  Future<void> reRing(
    WakeAlarm? alarm,
    int id,
    UserSettings settings,
    RingPayload previous,
    DateTime firstRingAt,
  ) async => calls.add('reRing:$id');
}
