import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Alarmın güvenilir çalması ve sesli komutlar için gereken izinler.
class Permissions {
  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Bildirim ve (Android 12+) tam zamanlı alarm izni.
  static Future<void> requestAlarmPermissions() async {
    if (kIsWeb) return;
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (_android && await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Mikrofon ve (iOS) konuşma tanıma izni.
  static Future<bool> requestVoicePermissions() async {
    if (kIsWeb) return false;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (!_android) {
      final speech = await Permission.speech.request();
      return speech.isGranted;
    }
    return true;
  }

  /// Bazı Android üreticileri pil tasarrufu için alarmı geciktirebilir.
  static Future<bool> batteryOptimizationIgnored() async {
    if (!_android) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_android) return;
    await Permission.ignoreBatteryOptimizations.request();
  }
}
