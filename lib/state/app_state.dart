import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logic/stats.dart';
import '../models/routine_step.dart';
import '../models/user_settings.dart';
import '../models/wake_alarm.dart';
import '../models/wake_record.dart';
import '../services/alarm_scheduler.dart';
import '../services/storage.dart';

/// Uygulamanın tüm kalıcı durumu: alarmlar, rutin, ayarlar ve geçmiş.
class AppState extends ChangeNotifier {
  AppState(this._storage, this._scheduler) {
    _alarms = _storage.loadAlarms();
    _routine = _storage.loadRoutine();
    _settings = _storage.loadSettings();
    _history = _storage.loadHistory();
  }

  final Storage _storage;
  final AlarmScheduler _scheduler;

  late List<WakeAlarm> _alarms;
  late List<RoutineStep> _routine;
  late UserSettings _settings;
  late List<WakeRecord> _history;

  List<WakeAlarm> get alarms => List.unmodifiable(_alarms);
  List<RoutineStep> get routine => List.unmodifiable(_routine);
  UserSettings get settings => _settings;
  List<WakeRecord> get history => List.unmodifiable(_history);

  int get streak => currentStreak(_history, DateTime.now());

  WakeAlarm? alarmById(int id) {
    for (final a in _alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  int newAlarmId() {
    final used = _alarms.map((a) => a.id).toSet();
    var id = 1 + Random().nextInt(100000);
    while (used.contains(id)) {
      id++;
    }
    return id;
  }

  /// Eklentideki alarmları uygulama durumuyla eşitler.
  Future<void> sync() async {
    try {
      await _scheduler.syncAll(_alarms, _settings);
    } catch (e) {
      debugPrint('Alarm eşitleme hatası: $e');
    }
  }

  Future<void> saveAlarm(WakeAlarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index == -1) {
      _alarms.add(alarm);
    } else {
      _alarms[index] = alarm;
    }
    _alarms.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    notifyListeners();
    await _storage.saveAlarms(_alarms);
    await sync();
  }

  Future<void> deleteAlarm(int id) async {
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
    await _storage.saveAlarms(_alarms);
    await sync();
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final alarm = alarmById(id);
    if (alarm == null) return;
    await saveAlarm(alarm.copyWith(enabled: enabled));
  }

  /// Tek seferlik alarm çaldıktan sonra kapatılır.
  Future<void> markRang(int id) async {
    final alarm = alarmById(id);
    if (alarm == null || alarm.repeats) return;
    final index = _alarms.indexWhere((a) => a.id == id);
    _alarms[index] = alarm.copyWith(enabled: false);
    notifyListeners();
    await _storage.saveAlarms(_alarms);
  }

  Future<void> saveRoutine(List<RoutineStep> steps) async {
    _routine = List.of(steps);
    notifyListeners();
    await _storage.saveRoutine(_routine);
  }

  Future<void> resetRoutine() => saveRoutine(defaultRoutine);

  Future<void> saveSettings(UserSettings settings) async {
    final previous = _settings;
    _settings = settings;
    notifyListeners();
    await _storage.saveSettings(_settings);
    // Bildirim metni (isim) ve titreşim alarm kaydının parçası.
    if (previous.name != settings.name ||
        previous.vibrate != settings.vibrate) {
      await sync();
    }
  }

  Future<void> addRecord(WakeRecord record) async {
    _history.add(record);
    notifyListeners();
    await _storage.saveHistory(_history);
  }
}
