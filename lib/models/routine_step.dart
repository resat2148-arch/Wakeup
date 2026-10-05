/// Sabah rutinindeki tek bir adım.
class RoutineStep {
  const RoutineStep({
    required this.id,
    required this.emoji,
    required this.title,
    required this.instruction,
    this.why = '',
    this.durationSeconds = 0,
    this.enabled = true,
  });

  final String id;
  final String emoji;
  final String title;

  /// Asistanın sesli olarak söylediği yönerge.
  final String instruction;

  /// Adımın neden işe yaradığına dair kısa, bilimsel gerekçe.
  final String why;

  /// 0 ise zamanlayıcı yoktur; kullanıcı "Yaptım" diyene kadar beklenir.
  final int durationSeconds;

  final bool enabled;

  bool get timed => durationSeconds > 0;

  RoutineStep copyWith({
    String? emoji,
    String? title,
    String? instruction,
    String? why,
    int? durationSeconds,
    bool? enabled,
  }) {
    return RoutineStep(
      id: id,
      emoji: emoji ?? this.emoji,
      title: title ?? this.title,
      instruction: instruction ?? this.instruction,
      why: why ?? this.why,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'emoji': emoji,
    'title': title,
    'instruction': instruction,
    'why': why,
    'durationSeconds': durationSeconds,
    'enabled': enabled,
  };

  factory RoutineStep.fromJson(Map<String, dynamic> json) {
    return RoutineStep(
      id: json['id'] as String,
      emoji: json['emoji'] as String? ?? '✅',
      title: json['title'] as String,
      instruction: json['instruction'] as String? ?? '',
      why: json['why'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Uyku ataletini kırmak ve güne iyi başlamak için araştırmalarla
/// desteklenen varsayılan sabah rutini.
const List<RoutineStep> defaultRoutine = [
  RoutineStep(
    id: 'sit_up',
    emoji: '🛏️',
    title: 'Doğrul ve ayaklarını yere bas',
    instruction: 'Önce yatakta doğrul, ayaklarını yere bas. Telefonu bırakma, benimle kal.',
    why: 'Dik oturmak kan akışını hızlandırır ve tekrar uykuya dalmayı zorlaştırır.',
  ),
  RoutineStep(
    id: 'light',
    emoji: '☀️',
    title: 'Perdeyi aç, ışığa çık',
    instruction: 'Şimdi kalk, perdeyi aç ya da ışığı yak. Mümkünse cama yaklaş ve gün ışığını gözlerine al.',
    why: 'Sabah ışığı uyku hormonu melatonini baskılar ve biyolojik saatini güne ayarlar.',
  ),
  RoutineStep(
    id: 'water',
    emoji: '💧',
    title: 'Bir bardak su iç',
    instruction: 'Mutfağa ya da lavaboya git ve bir bardak su iç.',
    why: 'Gece boyunca vücudun susuz kaldı. Su, zihinsel bulanıklığı azaltır.',
  ),
  RoutineStep(
    id: 'cold_water',
    emoji: '🚿',
    title: 'Yüzünü soğuk suyla yıka',
    instruction: 'Yüzüne bol soğuk su çarp. Birkaç kez, cesurca!',
    why: 'Soğuk su dalış refleksini tetikler ve uyanıklık sağlayan noradrenalini artırır.',
  ),
  RoutineStep(
    id: 'move',
    emoji: '🤸',
    title: 'Bir dakika hareket',
    instruction: 'Bir dakika boyunca hareket ediyoruz: kollarını açıp esne, sonra yavaş yavaş squat yap. Ben süreyi tutuyorum.',
    why: 'Kısa egzersiz kalp atışını ve vücut ısısını artırarak sersemliği hızla atar.',
    durationSeconds: 60,
  ),
  RoutineStep(
    id: 'bed',
    emoji: '🧺',
    title: 'Yatağını topla',
    instruction: 'Şimdi yatağını topla. Böylece geri dönme cazibesi de kalmaz.',
    why: 'Günün ilk küçük başarısı, sonraki adımlar için motivasyon yaratır.',
  ),
  RoutineStep(
    id: 'breathe',
    emoji: '🌬️',
    title: 'Derin nefes',
    instruction: 'Otuz saniye derin nefes alıyoruz. Burnundan dört saniye al, dört saniye tut, ağzından yavaşça ver.',
    why: 'Kontrollü nefes zihni berraklaştırır ve güne sakin başlamanı sağlar.',
    durationSeconds: 30,
  ),
  RoutineStep(
    id: 'intention',
    emoji: '🎯',
    title: 'Günün niyeti',
    instruction: 'Son olarak: bugün yapmak istediğin en önemli tek şey ne? Bunu kendine yüksek sesle söyle.',
    why: 'Net bir niyet belirlemek, günün geri kalanında odaklanmayı kolaylaştırır.',
  ),
];
