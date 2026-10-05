import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:wakeup_coach/models/user_settings.dart';
import 'package:wakeup_coach/models/wake_alarm.dart';
import 'package:wakeup_coach/services/alarm_scheduler.dart';
import 'package:wakeup_coach/services/listener.dart';
import 'package:wakeup_coach/services/voice.dart';

/// Söylenenleri kaydeden, hemen biten sahte ses servisi.
class FakeVoice extends VoiceService {
  final spoken = <String>[];

  @override
  Future<void> say(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class FakeListener extends CommandListener {
  @override
  Future<void> stop() async {}
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
