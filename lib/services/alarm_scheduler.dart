import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../logic/schedule.dart';
import '../models/user_settings.dart';
import '../models/wake_alarm.dart';

/// Alarmla birlikte taşınan ek bilgi.
class RingPayload {
  const RingPayload({this.snoozes = 0, this.reRing = false, this.firstRingAt});

  /// Bu sabah kaç kez ertelendi.
  final int snoozes;

  /// Kullanıcı uyandıktan sonra tekrar uyuduğu için yeniden çalıyor mu?
  final bool reRing;

  /// Bu sabahki ilk çalma zamanı (uyanma süresini hesaplamak için).
  final DateTime? firstRingAt;

  String encode() => jsonEncode({
    'snoozes': snoozes,
    'reRing': reRing,
    'firstRingAt': firstRingAt?.toIso8601String(),
  });

  static RingPayload decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RingPayload();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final first = json['firstRingAt'] as String?;
      return RingPayload(
        snoozes: json['snoozes'] as int? ?? 0,
        reRing: json['reRing'] as bool? ?? false,
        firstRingAt: first == null ? null : DateTime.parse(first),
      );
    } on FormatException {
      return const RingPayload();
    }
  }

  bool get isFollowUp => snoozes > 0 || reRing;
}

/// Uygulamanın alarmlarını `alarm` eklentisine aktarır.
///
/// Eklenti yalnızca tek seferlik alarmları desteklediği için tekrarlayan
/// alarmlarda her seferinde bir sonraki gün yeniden kurulur.
/// iOS'ta `Alarm.set`/`Alarm.stop` eşzamanlı çağrılırsa çökebildiği için
/// tüm çağrılar sırayla `await` edilir.
class AlarmScheduler {
  AlarmScheduler({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// "Şimdi dene" ile kurulan deneme alarmının kimliği.
  static const testAlarmId = 0;

  Future<void> _queue = Future.value();

  /// Eklenti çağrılarını sıraya koyar: açılıştaki eşitleme ile uyandırma
  /// ekranındaki durdurma aynı anda çalışmasın.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Stream<AlarmSet> get ringing => Alarm.ringing;

  Future<void> init() async {
    await Alarm.init();
    if (!kIsWeb && Platform.isIOS) {
      await Alarm.setWarningNotificationOnKill(
        'Alarmın çalmayabilir',
        'Uygulama kapatıldı. Alarmın çalması için uygulamayı tekrar aç.',
      );
    }
  }

  AlarmSettings _build(
    WakeAlarm alarm,
    DateTime when,
    UserSettings settings, {
    RingPayload payload = const RingPayload(),
  }) {
    final greetingName = settings.name.trim().isEmpty
        ? ''
        : ' ${settings.name.trim()}';
    final body = alarm.reason.trim().isNotEmpty
        ? 'Bugün seni ${alarm.reason.trim()} bekliyor. Dokun ve uyan!'
        : 'Uyanma vakti! Dokun, sabah rutinine birlikte başlayalım.';
    return AlarmSettings(
      id: alarm.id,
      dateTime: when,
      assetAudioPath: alarm.sound.assetPath,
      loopAudio: true,
      vibrate: settings.vibrate,
      warningNotificationOnKill: !kIsWeb && Platform.isIOS,
      androidFullScreenIntent: true,
      payload: payload.encode(),
      // Yumuşak başlayıp yükselen ses: ani, sert uyanış sersemliği artırır.
      volumeSettings: VolumeSettings.fade(
        volume: 0.9,
        fadeDuration: const Duration(seconds: 25),
      ),
      notificationSettings: NotificationSettings(
        title: 'Günaydın$greetingName! ☀️',
        body: body,
        // Durdur düğmesi yok: alarm ancak uygulamada ekrana dokununca susar.
        stopButton: null,
        androidStopAlarmOnDismiss: false,
        iconColor: const Color(0xFFFF8A3D),
      ),
    );
  }

  /// Uygulamadaki alarm listesini eklentiyle eşitler.
  Future<void> syncAll(List<WakeAlarm> alarms, UserSettings settings) =>
      _serial(() => _syncAll(alarms, settings));

  Future<void> _syncAll(List<WakeAlarm> alarms, UserSettings settings) async {
    final now = _clock();
    final existing = {for (final a in await Alarm.getAlarms()) a.id: a};

    for (final alarm in alarms) {
      final current = existing.remove(alarm.id);
      if (!alarm.enabled) {
        if (current != null) await Alarm.stop(alarm.id);
        continue;
      }
      if (current != null) {
        if (await Alarm.isRinging(alarm.id)) continue;
        // Ertelenmiş ya da yeniden çalacak alarma dokunma.
        final payload = RingPayload.decode(current.payload);
        if (payload.isFollowUp && current.dateTime.isAfter(now)) continue;
      }
      final next = nextOccurrence(alarm, now);
      final desired = _build(alarm, next, settings);
      if (current == desired) continue;
      await Alarm.set(alarmSettings: desired);
    }

    // Uygulamada artık olmayan alarmları temizle.
    for (final orphan in existing.keys) {
      if (orphan == testAlarmId) continue;
      await Alarm.stop(orphan);
    }
  }

  /// Uygulamayı denemek için birkaç saniye sonra çalacak bir alarm kurar.
  Future<DateTime> scheduleTest(
    UserSettings settings, {
    Duration delay = const Duration(seconds: 10),
  }) => _serial(() async {
    final when = _clock().add(delay);
    final alarm = WakeAlarm(
      id: testAlarmId,
      hour: when.hour,
      minute: when.minute,
      label: 'Deneme alarmı',
    );
    await Alarm.set(alarmSettings: _build(alarm, when, settings));
    return when;
  });

  /// Kullanıcı uyandı: sesi kes ve tekrarlayan alarmı bir sonraki güne kur.
  Future<void> dismiss(
    WakeAlarm? alarm,
    int ringingId,
    UserSettings settings,
  ) => _serial(() async {
    await Alarm.stop(ringingId);
    if (alarm != null && alarm.enabled && alarm.repeats) {
      final next = nextOccurrence(
        alarm,
        _clock().add(const Duration(minutes: 1)),
      );
      await Alarm.set(alarmSettings: _build(alarm, next, settings));
    }
  });

  Future<void> snooze(AlarmSettings ringing, int minutes) => _serial(() async {
    final payload = RingPayload.decode(ringing.payload);
    await Alarm.stop(ringing.id);
    await Alarm.set(
      alarmSettings: ringing.copyWith(
        dateTime: _clock().add(Duration(minutes: minutes)),
        payload: () => RingPayload(
          snoozes: payload.snoozes + 1,
          firstRingAt: payload.firstRingAt ?? ringing.dateTime,
        ).encode(),
      ),
    );
  });

  /// Uyandıktan sonra hareketsiz kalan kullanıcı için alarmı hemen
  /// yeniden çaldırır.
  Future<void> reRing(
    WakeAlarm? alarm,
    int id,
    UserSettings settings,
    RingPayload previous,
    DateTime firstRingAt,
  ) => _serial(() async {
    final when = _clock().add(const Duration(seconds: 2));
    final payload = RingPayload(
      snoozes: previous.snoozes,
      reRing: true,
      firstRingAt: firstRingAt,
    );
    final base =
        alarm ??
        WakeAlarm(id: id, hour: when.hour, minute: when.minute, enabled: false);
    await Alarm.stop(id);
    await Alarm.set(
      alarmSettings: _build(base, when, settings, payload: payload),
    );
  });
}
