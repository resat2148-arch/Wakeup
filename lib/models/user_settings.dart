/// Kullanıcıya ait tercihler.
class UserSettings {
  const UserSettings({
    this.name = '',
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.voiceCommands = true,
    this.talkWhileRinging = true,
    this.talkIntervalSeconds = 20,
    this.maxSnoozes = 1,
    this.snoozeMinutes = 5,
    this.sleepBackGuardSeconds = 90,
    this.vibrate = true,
    this.onboarded = false,
  });

  final String name;

  /// 0.5 her iki platformda da normal konuşma hızıdır.
  final double speechRate;
  final double pitch;

  /// Rutin sırasında "tamam", "yaptım", "atla" gibi sesli komutları dinle.
  final bool voiceCommands;

  /// Alarm çalarken belirli aralıklarla motive edici sözler söyle.
  final bool talkWhileRinging;
  final int talkIntervalSeconds;

  /// Erteleme sayısı sınırı. Ertelemek uyku ataletini artırdığı için
  /// varsayılan olarak yalnızca bir kez izin verilir.
  final int maxSnoozes;
  final int snoozeMinutes;

  /// Uyandıktan sonra bu kadar saniye etkileşim olmazsa kullanıcının
  /// tekrar uyuduğu varsayılır ve alarm yeniden çalar.
  final int sleepBackGuardSeconds;

  final bool vibrate;
  final bool onboarded;

  UserSettings copyWith({
    String? name,
    double? speechRate,
    double? pitch,
    bool? voiceCommands,
    bool? talkWhileRinging,
    int? talkIntervalSeconds,
    int? maxSnoozes,
    int? snoozeMinutes,
    int? sleepBackGuardSeconds,
    bool? vibrate,
    bool? onboarded,
  }) {
    return UserSettings(
      name: name ?? this.name,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      voiceCommands: voiceCommands ?? this.voiceCommands,
      talkWhileRinging: talkWhileRinging ?? this.talkWhileRinging,
      talkIntervalSeconds: talkIntervalSeconds ?? this.talkIntervalSeconds,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      sleepBackGuardSeconds:
          sleepBackGuardSeconds ?? this.sleepBackGuardSeconds,
      vibrate: vibrate ?? this.vibrate,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'speechRate': speechRate,
    'pitch': pitch,
    'voiceCommands': voiceCommands,
    'talkWhileRinging': talkWhileRinging,
    'talkIntervalSeconds': talkIntervalSeconds,
    'maxSnoozes': maxSnoozes,
    'snoozeMinutes': snoozeMinutes,
    'sleepBackGuardSeconds': sleepBackGuardSeconds,
    'vibrate': vibrate,
    'onboarded': onboarded,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    const d = UserSettings();
    return UserSettings(
      name: json['name'] as String? ?? d.name,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? d.speechRate,
      pitch: (json['pitch'] as num?)?.toDouble() ?? d.pitch,
      voiceCommands: json['voiceCommands'] as bool? ?? d.voiceCommands,
      talkWhileRinging: json['talkWhileRinging'] as bool? ?? d.talkWhileRinging,
      talkIntervalSeconds:
          json['talkIntervalSeconds'] as int? ?? d.talkIntervalSeconds,
      maxSnoozes: json['maxSnoozes'] as int? ?? d.maxSnoozes,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? d.snoozeMinutes,
      sleepBackGuardSeconds:
          json['sleepBackGuardSeconds'] as int? ?? d.sleepBackGuardSeconds,
      vibrate: json['vibrate'] as bool? ?? d.vibrate,
      onboarded: json['onboarded'] as bool? ?? d.onboarded,
    );
  }
}
