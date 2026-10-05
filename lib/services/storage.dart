import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine_step.dart';
import '../models/user_settings.dart';
import '../models/wake_alarm.dart';
import '../models/wake_record.dart';

/// Uygulama verilerini cihazda JSON olarak saklar.
class Storage {
  Storage(this._prefs);

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _alarmsKey = 'alarms.v1';
  static const _routineKey = 'routine.v1';
  static const _settingsKey = 'settings.v1';
  static const _historyKey = 'history.v1';

  /// Geçmişte tutulacak en fazla kayıt sayısı.
  static const maxHistory = 120;

  List<WakeAlarm> loadAlarms() => _loadList(_alarmsKey, WakeAlarm.fromJson);

  Future<void> saveAlarms(List<WakeAlarm> alarms) =>
      _saveList(_alarmsKey, alarms.map((a) => a.toJson()));

  List<RoutineStep> loadRoutine() {
    if (!_prefs.containsKey(_routineKey)) return List.of(defaultRoutine);
    return _loadList(_routineKey, RoutineStep.fromJson);
  }

  Future<void> saveRoutine(List<RoutineStep> steps) =>
      _saveList(_routineKey, steps.map((s) => s.toJson()));

  UserSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const UserSettings();
    try {
      return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const UserSettings();
    }
  }

  Future<void> saveSettings(UserSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  List<WakeRecord> loadHistory() => _loadList(_historyKey, WakeRecord.fromJson);

  Future<void> saveHistory(List<WakeRecord> history) {
    final trimmed = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;
    return _saveList(_historyKey, trimmed.map((r) => r.toJson()));
  }

  List<T> _loadList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _saveList(String key, Iterable<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items.toList()));
}
