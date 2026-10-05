/// Kullanıcının kurduğu bir uyandırma alarmı.
///
/// [weekdays] `DateTime.weekday` değerlerini tutar (1 = Pazartesi … 7 = Pazar).
/// Boşsa alarm tek seferliktir.
class WakeAlarm {
  const WakeAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.weekdays = const {},
    this.enabled = true,
    this.label = '',
    this.reason = '',
    this.sound = AlarmSound.sunrise,
  });

  final int id;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final bool enabled;

  /// Kısa ad, örn. "İş günü".
  final String label;

  /// "Bu sabah seni ne bekliyor?" — uyanma anında sesli olarak hatırlatılır.
  /// Araştırmalar, güne dair somut bir beklenti ya da amaç olmasının
  /// yataktan çıkmayı kolaylaştırdığını gösteriyor.
  final String reason;

  final AlarmSound sound;

  bool get repeats => weekdays.isNotEmpty;

  WakeAlarm copyWith({
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? enabled,
    String? label,
    String? reason,
    AlarmSound? sound,
  }) {
    return WakeAlarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      reason: reason ?? this.reason,
      sound: sound ?? this.sound,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
    'label': label,
    'reason': reason,
    'sound': sound.name,
  };

  factory WakeAlarm.fromJson(Map<String, dynamic> json) {
    return WakeAlarm(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      weekdays: ((json['weekdays'] as List?) ?? const [])
          .map((e) => e as int)
          .toSet(),
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      sound: AlarmSound.values.firstWhere(
        (s) => s.name == json['sound'],
        orElse: () => AlarmSound.sunrise,
      ),
    );
  }
}

/// Melodik alarm sesleri. RMIT araştırmasına göre melodik sesler, klasik
/// "bip-bip" alarmlara kıyasla uyku ataletini (sersemliği) azaltıyor.
enum AlarmSound {
  sunrise('Gündoğumu (sakin)', 'assets/sounds/sunrise.mp3'),
  energy('Enerji (ritmik)', 'assets/sounds/energy.mp3');

  const AlarmSound(this.title, this.assetPath);

  final String title;
  final String assetPath;
}
