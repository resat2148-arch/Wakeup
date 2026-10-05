import 'dart:math';

import '../models/routine_step.dart';
import 'schedule.dart';

/// Motivasyon cümlelerini kişiselleştirmek için gereken bilgiler.
class MotivationContext {
  const MotivationContext({
    required this.now,
    this.name = '',
    this.reason = '',
    this.streak = 0,
    this.snoozesLeft = 0,
  });

  final DateTime now;
  final String name;
  final String reason;
  final int streak;
  final int snoozesLeft;
}

/// Bir cümle şablonu. Bazı şablonlar yalnızca ilgili bilgi varsa kullanılır
/// (örn. kullanıcı bir "uyanma nedeni" yazdıysa).
class _Line {
  const _Line(this.text, {this.needsReason = false, this.needsStreak = false});

  final String text;
  final bool needsReason;
  final bool needsStreak;

  bool usable(MotivationContext c) =>
      (!needsReason || c.reason.trim().isNotEmpty) &&
      (!needsStreak || c.streak >= 2);
}

/// Uyanma ve sabah rutini boyunca söylenecek sözleri üreten motor.
///
/// Cümleler, insanları uyanmaya neyin motive ettiğine dair araştırmalara
/// dayanır:
/// * **Beklenti ve amaç** – güne dair somut bir neden yataktan çıkmayı
///   kolaylaştırır (kullanıcının yazdığı "uyanma nedeni").
/// * **Uyku ataleti geçicidir** – sersemlik normaldir ve hareketle hızla
///   azalır; bunu bilmek "biraz daha" isteğini zayıflatır.
/// * **Ertelemenin zararı** – ertelemek uyku döngüsünü yeniden başlatıp
///   sersemliği artırır.
/// * **Işık, soğuk su, hareket** – melatonini baskılar, noradrenalini
///   artırır, vücut ısısını yükseltir.
/// * **Seri ve kimlik** – "sözünü tutan biriyim" kimliği ve kırılmamış
///   zincir, alışkanlığı pekiştirir.
/// * **Küçük kazanımlar ve gelecekteki ben** – her adım bir başarı;
///   bugünkü çaba yarım saat sonraki sana iyilik.
/// * **Ekran yerine eylem** – telefonda kaydırmak dopamin düşüşünü
///   bastırır ve harekete geçme isteğini zayıflatır.
class MotivationEngine {
  MotivationEngine({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, int> _lastPick = {};

  // ---------------------------------------------------------------------
  // Alarm çalarken: seviye 1 nazik, 2 bilgilendirici/amaç, 3 enerjik/kararlı.
  // ---------------------------------------------------------------------

  static const _wakeGentle = [
    _Line('Günaydın {ad}. {saat}. Yavaşça gözlerini aç, uyanma vakti geldi.'),
    _Line('{ad}, yeni bir gün başladı. Derin bir nefes al ve gözlerini aç.'),
    _Line('Günaydın {ad}. Bugün {gün}. Hadi, yavaş yavaş uyanıyoruz.'),
    _Line('{ad}, uyanma zamanı. Önce bir esne, sonra ekrana dokun.'),
  ];

  static const _wakePurpose = [
    _Line(
      '{ad}, unutma: bugün seni {neden} bekliyor. Kalkmak için harika bir sebep!',
      needsReason: true,
    ),
    _Line(
      'Dün akşam kendine bir söz verdin: {neden}. Hadi o sözü tutalım {ad}.',
      needsReason: true,
    ),
    _Line(
      '{ad}, tam {seri} gündür zinciri kırmadın. Bugün de kırmayalım!',
      needsStreak: true,
    ),
    _Line(
      'Şu an hissettiğin sersemlik tamamen normal, adı uyku ataleti. '
      'Ayağa kalktığın an hızla azalacak.',
    ),
    _Line(
      'Bilim diyor ki: ertelemek seni daha da sersemletir, çünkü uyku '
      'döngüsünü yeniden başlatır. En kolay yol şimdi kalkmak.',
    ),
    _Line(
      'Yarım saat sonraki sen, şimdi kalktığın için sana teşekkür edecek {ad}.',
    ),
    _Line(
      'Perdeyi açtığın an ışık beynine "gün başladı" diyecek ve uyku hormonun azalacak.',
    ),
    _Line(
      'Bugün sadece ilk adımı at: ekrana dokun. Gerisini birlikte yapacağız.',
    ),
    _Line(
      '{ad}, sabahları erken kalkanlar günün en sakin ve verimli saatlerini kazanır. O saatler senin.',
    ),
  ];

  static const _wakeEnergetic = [
    _Line(
      '{ad}! Beşten geriye sayıyorum: beş, dört, üç, iki, bir! Kalk ve ekrana dokun!',
    ),
    _Line('Hadi {ad}! Battaniyeyi at, ayaklarını yere bas! Gün seni bekliyor!'),
    _Line('{ad}, bu bir uyandırma görevi! Ekrana dokunana kadar susmayacağım!'),
    _Line(
      '{neden}! Bunu kaçırmak istemezsin {ad}. Kalk, kalk, kalk!',
      needsReason: true,
    ),
    _Line(
      '{ad}, {seri} günlük serini bugün bozmak yok! Hemen ekrana dokun!',
      needsStreak: true,
    ),
    _Line(
      'Sen sözünü tutan birisin {ad}. Bunu şimdi kanıtla: gözlerini aç ve ekrana dokun!',
    ),
  ];

  /// Alarm çalarken söylenecek cümle. [level] 1–3 arası.
  String wakeCall(int level, MotivationContext c) {
    final pool = switch (level) {
      <= 1 => _wakeGentle,
      2 => _wakePurpose,
      _ => _wakeEnergetic,
    };
    final line = _pick('wake$level', pool, c);
    // Cümle zaten dokunmayı istiyorsa tekrar etme.
    if (line.toLowerCase().contains('ekrana dokun')) return line;
    return '$line Uyandıysan ekrana dokun.';
  }

  /// Alarmın çalmaya başlamasından bu yana geçen süreye göre seviye.
  static int levelFor(Duration ringingFor) {
    if (ringingFor.inSeconds < 45) return 1;
    if (ringingFor.inSeconds < 120) return 2;
    return 3;
  }

  // ---------------------------------------------------------------------
  // Uyanma anı
  // ---------------------------------------------------------------------

  static const _awakeOpeners = [
    _Line('Harika, uyandın! Günaydın {ad}.'),
    _Line('İşte bu! Günaydın {ad}, seni görmek güzel.'),
    _Line('Süpersin {ad}! İlk ve en zor adımı attın.'),
  ];

  /// Ekrana dokunulduğu an söylenen karşılama.
  String awakeGreeting(
    MotivationContext c, {
    required Duration latency,
    required int stepCount,
  }) {
    final parts = <String>[_pick('awake', _awakeOpeners, c)];
    if (latency.inSeconds <= 60) {
      parts.add(
        'Sadece ${latency.inSeconds} saniyede uyandın, bu harika bir başlangıç.',
      );
    }
    parts.add('Bugün ${_dayName(c.now)}, ${spokenTime(c.now)}.');
    final dayLine = _dayMotivation(c.now);
    if (dayLine != null) parts.add(dayLine);
    if (c.reason.trim().isNotEmpty) {
      parts.add('Unutma, bugün seni ${c.reason.trim()} bekliyor.');
    }
    if (stepCount > 0) {
      parts.add(
        'Şimdi $stepCount adımlık sabah rutinimize başlıyoruz. '
        'Telefonda gezinmek yok, her adımda ben yanındayım.',
      );
    }
    return _fill(parts.join(' '), c);
  }

  /// Tekrar uyuyup alarmla yeniden uyanan kullanıcıya.
  String welcomeBack(MotivationContext c) => _fill(
    'Tekrar hoş geldin {ad}! Bu sefer uyanık kalıyoruz. '
    'Kaldığımız yerden devam ediyoruz.',
    c,
  );

  // ---------------------------------------------------------------------
  // Rutin adımları
  // ---------------------------------------------------------------------

  String stepIntro(
    RoutineStep step, {
    required int index,
    required int total,
    required bool voiceCommands,
  }) {
    final ordinal = index == total - 1 ? 'Son adım' : '${index + 1}. adım';
    final buffer = StringBuffer('$ordinal: ${step.title}. ${step.instruction}');
    if (step.why.isNotEmpty) buffer.write(' ${step.why}');
    if (index == 0 && voiceCommands) {
      buffer.write(' Bitirdiğinde "tamam" de ya da ekrana dokun.');
    }
    return buffer.toString();
  }

  static const _stepDone = [
    _Line('Harika!'),
    _Line('Çok iyi gidiyorsun {ad}!'),
    _Line('Bir adım daha tamam. Böyle devam!'),
    _Line('Mükemmel! Her adım seni daha da uyandırıyor.'),
    _Line('Bravo! Küçük kazanımlar büyük günler yaratır.'),
    _Line('İşte bu! Şimdi kendini daha zinde hissediyorsundur.'),
  ];

  String stepDone(MotivationContext c, {required int remaining}) {
    final praise = _pick('stepDone', _stepDone, c);
    if (remaining == 1) return '$praise Sadece bir adım kaldı.';
    if (remaining > 1 && remaining <= 3) {
      return '$praise $remaining adım kaldı.';
    }
    return praise;
  }

  static const _stepSkipped = [
    _Line('Sorun değil, bir sonrakine geçelim.'),
    _Line('Tamam, bunu atlıyoruz. Devam!'),
    _Line('Olsun, önemli olan devam etmek.'),
  ];

  String stepSkipped(MotivationContext c) =>
      _pick('stepSkipped', _stepSkipped, c);

  String timerHalfway() => 'Yarıladık, devam!';

  String timerLastSeconds() => 'Son on saniye!';

  String timerFinished() => 'Süre doldu.';

  // ---------------------------------------------------------------------
  // Tekrar uykuya dalma koruması ve erteleme
  // ---------------------------------------------------------------------

  static const _inactivity = [
    _Line('{ad}, hâlâ benimle misin? Ekrana bir dokunuş yeter.'),
    _Line('{ad}, sessizleştin. Tekrar uyumadın, değil mi? Ekrana dokun.'),
    _Line('Hey {ad}! Yatağa geri dönmek yok. Bir dokunuşla devam edelim.'),
  ];

  String inactivityCheck(MotivationContext c) =>
      _pick('inactivity', _inactivity, c);

  String reRingWarning(MotivationContext c) =>
      _fill('{ad}, tekrar uyuduğunu düşünüyorum. Alarmı yeniden çalıyorum!', c);

  String snoozed(MotivationContext c, int minutes) {
    final left = c.snoozesLeft;
    final tail = left > 0
        ? 'Bir erteleme hakkın daha var.'
        : 'Bu son ertelemeydi, bir dahaki sefere kalkıyoruz.';
    return _fill(
      'Tamam {ad}, $minutes dakika erteledim. Ama bil ki ertelemek çoğu '
      'zaman daha sersem uyandırır. Bu sürede uyumaya çalışma, gözlerini '
      'açık tut ve esne. $tail',
      c,
    );
  }

  // ---------------------------------------------------------------------
  // Kapanış
  // ---------------------------------------------------------------------

  static const _closers = [
    _Line('Güne kazanan olarak başladın. Harika bir gün geçir {ad}!'),
    _Line('Bugünün ilk zaferi senin. Şimdi gün senin {ad}!'),
    _Line('Yarın sabah yine buradayım. Harika bir gün dilerim {ad}!'),
    _Line('Kendinle gurur duy {ad}. Bu enerjiyle güne başla!'),
  ];

  String finale(MotivationContext c, {required int done, required int total}) {
    final parts = <String>[];
    if (total > 0 && done == total) {
      parts.add(
        'Tebrikler {ad}! Sabah rutininin tüm $total adımını tamamladın.',
      );
    } else if (done > 0) {
      parts.add('Tebrikler {ad}! $total adımın $done tanesini tamamladın.');
    } else {
      parts.add(
        'Bugün adımları atladın ama uyandın, bu da bir başlangıç {ad}.',
      );
    }
    if (c.streak >= 2) {
      parts.add('Serin ${c.streak} gün oldu, zinciri kırmıyorsun!');
    } else if (c.streak == 1 && done > 0) {
      parts.add('Yeni bir seri başladı. Yarın ikinci halkayı ekleyelim.');
    }
    parts.add(_pick('closer', _closers, c));
    return _fill(parts.join(' '), c);
  }

  // ---------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------

  String _pick(String key, List<_Line> pool, MotivationContext c) {
    final candidates = <int>[
      for (var i = 0; i < pool.length; i++)
        if (pool[i].usable(c)) i,
    ];
    if (candidates.isEmpty) return '';
    final last = _lastPick[key];
    final options = candidates.length > 1
        ? candidates.where((i) => i != last).toList()
        : candidates;
    final chosen = options[_random.nextInt(options.length)];
    _lastPick[key] = chosen;
    return _fill(pool[chosen].text, c);
  }

  static String _fill(String text, MotivationContext c) {
    final name = c.name.trim();
    var out = text;
    if (name.isEmpty) {
      out = out
          .replaceAll(RegExp(r',\s*\{ad\}'), '')
          .replaceAll(RegExp(r'^\{ad\}[,!]\s*'), '')
          .replaceAll(RegExp(r'\{ad\},\s*'), '')
          .replaceAll(RegExp(r'\s*\{ad\}'), '');
    } else {
      out = out.replaceAll('{ad}', name);
    }
    out = out
        .replaceAll('{neden}', c.reason.trim())
        .replaceAll('{seri}', '${c.streak}')
        .replaceAll('{gün}', _dayName(c.now))
        .replaceAll('{saat}', _capitalize(spokenTime(c.now)));
    out = out
        .replaceAll(RegExp(r'\s+([,.!?])'), r'$1')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return _capitalize(out);
  }

  static String _dayName(DateTime d) =>
      weekdayLong[d.weekday - 1].toLowerCase();

  static String? _dayMotivation(DateTime d) {
    return switch (d.weekday) {
      DateTime.monday =>
        'Yeni bir hafta, yeni bir başlangıç. Haftaya güçlü gir!',
      DateTime.wednesday => 'Haftanın ortasındayız, ivmeni koru.',
      DateTime.friday => 'Cuma geldi! Haftanın son düzlüğü, bitir şunu.',
      DateTime.saturday || DateTime.sunday =>
        'Hafta sonu erken kalkmak, günün tamamını sana hediye eder.',
      _ => null,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    final first = s[0] == 'i' ? 'İ' : s[0].toUpperCase();
    return first + s.substring(1);
  }
}

// -------------------------------------------------------------------------
// Saatin Türkçe okunuşu: TTS motorları "07:05" gibi ifadeleri farklı
// okuyabildiği için saati yazıyla veriyoruz.
// -------------------------------------------------------------------------

const _ones = [
  '',
  'bir',
  'iki',
  'üç',
  'dört',
  'beş',
  'altı',
  'yedi',
  'sekiz',
  'dokuz',
];
const _tens = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli'];

/// 0–59 arası sayıların Türkçe yazılışı.
String turkishNumber(int n) {
  if (n == 0) return 'sıfır';
  final words = [_tens[n ~/ 10], _ones[n % 10]].where((w) => w.isNotEmpty);
  return words.join(' ');
}

/// "saat yedi", "saat yedi buçuk", "saat yedi on beş" gibi.
String spokenTime(DateTime t) {
  final hourWord = turkishNumber(t.hour);
  if (t.minute == 0) return 'saat $hourWord';
  if (t.minute == 30) return 'saat $hourWord buçuk';
  return 'saat $hourWord ${turkishNumber(t.minute)}';
}
