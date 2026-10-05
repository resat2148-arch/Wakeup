import 'dart:math';

import '../models/routine_step.dart';
import 'schedule.dart';
import 'speech.dart';

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

/// Asistanın söyleyebileceği tek bir cümle.
///
/// [id] aynı zamanda kayıtlı ses dosyasının adıdır (`assets/voice/<id>.mp3`).
/// [text] sentetik ses için şablondur ve saat, sayı, uyanma nedeni gibi
/// değişken bilgiler içerebilir. [clipText] kayıt için söylenecek metindir;
/// değişken bilgi içermez (verilmezse [text] ile aynıdır).
class VoiceLine {
  const VoiceLine(
    this.id,
    this.text, {
    this.clipText,
    this.needsReason = false,
    this.needsStreak = false,
  });

  final String id;
  final String text;
  final String? clipText;
  final bool needsReason;
  final bool needsStreak;

  String get scriptText => clipText ?? text;

  bool usable(MotivationContext c) =>
      (!needsReason || c.reason.trim().isNotEmpty) &&
      (!needsStreak || c.streak >= 2);
}

/// Seslendirme metnindeki bir bölüm.
class VoiceGroup {
  const VoiceGroup(this.title, this.note, this.lines);

  final String title;
  final String note;
  final List<VoiceLine> lines;
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
///
/// [clips] kayıtlı ses dosyası bulunan cümlelerin kimlikleridir. Kayıt
/// varken motor, sesler birbirine karışmasın diye kaydı olan cümleleri seçer.
class MotivationEngine {
  MotivationEngine({Random? random, this.clips = const {}})
    : _random = random ?? Random();

  final Random _random;
  final Map<String, int> _lastPick = {};

  /// Kaydı bulunan cümle kimlikleri; ses paketi yüklenince güncellenir.
  Set<String> clips;

  bool get hasRecordedVoice => clips.isNotEmpty;

  // =====================================================================
  // Cümle kataloğu
  // =====================================================================

  static const wakeGentle = [
    VoiceLine(
      'wake_gentle_1',
      'Günaydın {ad}. {saat}. Yavaş yavaş gözlerini aç, uyanma vakti geldi. Uyandığında ekrana dokun.',
      clipText: 'Günaydın {ad}. Yavaş yavaş gözlerini aç, uyanma vakti geldi. Uyandığında ekrana dokun.',
    ),
    VoiceLine(
      'wake_gentle_2',
      '{ad}, yeni bir gün başladı. Derin bir nefes al, gözlerini aç ve ekrana dokun.',
    ),
    VoiceLine(
      'wake_gentle_3',
      'Günaydın {ad}. Bugün {gün}. Hadi, yavaş yavaş uyanıyoruz. Hazır olunca ekrana dokun.',
      clipText: 'Günaydın {ad}. Hadi, yavaş yavaş uyanıyoruz. Hazır olunca ekrana dokun.',
    ),
    VoiceLine(
      'wake_gentle_4',
      '{ad}, uyanma zamanı. Önce kocaman bir esne, sonra ekrana dokun.',
    ),
    VoiceLine(
      'wake_gentle_5',
      'Sabah oldu {ad}. Yeni bir gün seni bekliyor. Gözlerini aç ve ekrana dokun.',
    ),
  ];

  static const wakePurpose = [
    VoiceLine(
      'wake_reason_1',
      '{ad}, unutma: bugün seni {neden} bekliyor. Kalkmak için harika bir sebep! Ekrana dokun.',
      clipText: '{ad}, unutma: bugün seni bekleyen güzel bir şey var. Kalkmak için harika bir sebep! Ekrana dokun.',
      needsReason: true,
    ),
    VoiceLine(
      'wake_reason_2',
      'Dün akşam kendine bir söz verdin: {neden}. Hadi o sözü tutalım {ad}. Ekrana dokun.',
      clipText: 'Dün akşam kendine bir söz verdin. Hadi o sözü tutalım {ad}. Ekrana dokun.',
      needsReason: true,
    ),
    VoiceLine(
      'wake_streak_1',
      '{ad}, tam {seri} gündür zinciri kırmadın. Bugün de kırmayalım! Ekrana dokun.',
      clipText: '{ad}, günlerdir zinciri kırmadın. Bugün de kırmayalım! Ekrana dokun.',
      needsStreak: true,
    ),
    VoiceLine(
      'wake_inertia',
      'Şu an hissettiğin ağırlık tamamen normal, adı uyku ataleti. Ayağa kalktığın an hızla geçecek. Ekrana dokun.',
    ),
    VoiceLine(
      'wake_snooze_science',
      'Bilim diyor ki: ertelemek seni daha da sersemletir, çünkü uyku döngüsünü yeniden başlatır. En kolay yol şimdi kalkmak. Ekrana dokun.',
    ),
    VoiceLine(
      'wake_future_self',
      'Yarım saat sonraki sen, şimdi kalktığın için sana teşekkür edecek {ad}. Ekrana dokun.',
    ),
    VoiceLine(
      'wake_light',
      'Perdeyi açtığın an ışık beynine "gün başladı" diyecek ve uyku hormonun azalacak. Önce ekrana dokun.',
    ),
    VoiceLine(
      'wake_first_step',
      'Bugün sadece ilk adımı at: ekrana dokun. Gerisini birlikte yapacağız.',
    ),
    VoiceLine(
      'wake_quiet_hours',
      '{ad}, sabahın bu sakin saatleri senin. Onları kaçırma, ekrana dokun.',
    ),
  ];

  static const wakeEnergetic = [
    VoiceLine(
      'wake_countdown',
      '{ad}! Beşten geriye sayıyorum: beş, dört, üç, iki, bir! Kalk ve ekrana dokun!',
    ),
    VoiceLine(
      'wake_blanket',
      'Hadi {ad}! Battaniyeyi at, ayaklarını yere bas! Gün seni bekliyor, ekrana dokun!',
    ),
    VoiceLine(
      'wake_mission',
      '{ad}, bu bir uyandırma görevi! Ekrana dokunana kadar susmayacağım!',
    ),
    VoiceLine(
      'wake_reason_3',
      '{neden}! Bunu kaçırmak istemezsin {ad}. Kalk, kalk, kalk! Ekrana dokun!',
      clipText: 'Seni bekleyen şeyi kaçırmak istemezsin {ad}. Kalk, kalk, kalk! Ekrana dokun!',
      needsReason: true,
    ),
    VoiceLine(
      'wake_streak_2',
      '{ad}, {seri} günlük serini bugün bozmak yok! Hemen ekrana dokun!',
      clipText: '{ad}, serini bugün bozmak yok! Hemen ekrana dokun!',
      needsStreak: true,
    ),
    VoiceLine(
      'wake_promise',
      'Sen sözünü tutan birisin {ad}. Bunu şimdi kanıtla: gözlerini aç ve ekrana dokun!',
    ),
  ];

  static const awakeOpeners = [
    VoiceLine('awake_1', 'Harika, uyandın! Günaydın {ad}.'),
    VoiceLine('awake_2', 'İşte bu! Günaydın {ad}, seni görmek güzel.'),
    VoiceLine('awake_3', 'Süpersin {ad}! İlk ve en zor adımı attın.'),
  ];

  static const awakeFast = VoiceLine(
    'awake_fast',
    'Sadece {sn} saniyede uyandın, bu harika bir başlangıç.',
    clipText: 'Çok hızlı uyandın, bu harika bir başlangıç.',
  );

  /// Haftanın günü: `DateTime.weekday` sırasıyla (Pazartesi = 1).
  static const dayLines = [
    VoiceLine(
      'day_1',
      'Bugün pazartesi, {saat}. Yeni bir hafta, yeni bir başlangıç. Haftaya güçlü gir!',
      clipText: 'Bugün pazartesi. Yeni bir hafta, yeni bir başlangıç. Haftaya güçlü gir!',
    ),
    VoiceLine(
      'day_2',
      'Bugün salı, {saat}. Dünkü ivmeyi koru, harika gidiyorsun.',
      clipText: 'Bugün salı. Dünkü ivmeyi koru, harika gidiyorsun.',
    ),
    VoiceLine(
      'day_3',
      'Bugün çarşamba, {saat}. Haftanın ortasındayız, ivmeni koru.',
      clipText: 'Bugün çarşamba. Haftanın ortasındayız, ivmeni koru.',
    ),
    VoiceLine(
      'day_4',
      'Bugün perşembe, {saat}. Hafta sonuna az kaldı, güçlü devam!',
      clipText: 'Bugün perşembe. Hafta sonuna az kaldı, güçlü devam!',
    ),
    VoiceLine(
      'day_5',
      'Bugün cuma, {saat}. Haftanın son düzlüğü, bitir şunu!',
      clipText: 'Cuma geldi! Haftanın son düzlüğü, bitir şunu!',
    ),
    VoiceLine(
      'day_6',
      'Bugün cumartesi, {saat}. Hafta sonu erken kalkmak, günün tamamını sana hediye eder.',
      clipText: 'Bugün cumartesi. Hafta sonu erken kalkmak, günün tamamını sana hediye eder.',
    ),
    VoiceLine(
      'day_7',
      'Bugün pazar, {saat}. Sakin ama uyanık bir gün; erken kalkan günün tadını çıkarır.',
      clipText: 'Bugün pazar. Sakin ama uyanık bir gün; erken kalkan günün tadını çıkarır.',
    ),
  ];

  static const awakeReason = VoiceLine(
    'awake_reason',
    'Unutma, bugün seni {neden} bekliyor.',
    clipText: 'Ekrandaki hedefini unutma; bugün seni o bekliyor.',
    needsReason: true,
  );

  static const routineStart = VoiceLine(
    'routine_start',
    'Şimdi {n} adımlık sabah rutinimize başlıyoruz. Telefonda gezinmek yok, her adımda ben yanındayım.',
    clipText: 'Şimdi sabah rutinimize başlıyoruz. Telefonda gezinmek yok, her adımda ben yanındayım.',
  );

  static const welcomeBackLine = VoiceLine(
    'welcome_back',
    'Tekrar hoş geldin {ad}! Bu sefer uyanık kalıyoruz. Kaldığımız yerden devam ediyoruz.',
  );

  static const hintVoice = VoiceLine(
    'hint_voice',
    'Bitirdiğinde bana "yaptım" de, bir sonraki adıma geçelim. Telefona dokunmana gerek yok.',
  );

  static const hintTouch = VoiceLine(
    'hint_touch',
    'Bitirdiğinde ekrandaki "Yaptım" düğmesine dokun.',
  );

  static const praise = [
    VoiceLine('praise_1', 'Harika!'),
    VoiceLine('praise_2', 'Çok iyi gidiyorsun {ad}!'),
    VoiceLine('praise_3', 'Bir adım daha tamam. Böyle devam!'),
    VoiceLine('praise_4', 'Mükemmel! Her adım seni biraz daha uyandırıyor.'),
    VoiceLine('praise_5', 'Bravo! Küçük kazanımlar büyük günler yaratır.'),
    VoiceLine(
      'praise_6',
      'İşte bu! Şimdi kendini daha zinde hissediyorsundur.',
    ),
  ];

  static const remainingLines = [
    VoiceLine('left_1', 'Sadece bir adım kaldı.'),
    VoiceLine('left_2', 'İki adım kaldı.'),
    VoiceLine('left_3', 'Üç adım kaldı.'),
  ];

  static const skipped = [
    VoiceLine('skip_1', 'Sorun değil, bir sonrakine geçelim.'),
    VoiceLine('skip_2', 'Tamam, bunu atlıyoruz. Devam!'),
    VoiceLine('skip_3', 'Olsun, önemli olan devam etmek.'),
  ];

  static const timerHalf = VoiceLine('timer_half', 'Yarıladık, devam!');
  static const timerTen = VoiceLine('timer_10', 'Son on saniye!');
  static const timerDone = VoiceLine('timer_done', 'Süre doldu, harika.');
  static const pauseAckLine = VoiceLine(
    'pause_ack',
    'Tamam, bekliyorum. Hazır olunca "devam" de.',
  );
  static const resumeAckLine = VoiceLine('resume_ack', 'Devam ediyoruz!');

  static const idle = [
    VoiceLine(
      'idle_1',
      '{ad}, hâlâ benimle misin? Bir şey söyle ya da ekrana dokun.',
    ),
    VoiceLine(
      'idle_2',
      '{ad}, sessizleştin. Tekrar uyumadın, değil mi? "Buradayım" de.',
    ),
    VoiceLine(
      'idle_3',
      'Hey {ad}! Yatağa geri dönmek yok. Sesini duyalım, "buradayım" de.',
    ),
  ];

  static const idleAckLine = VoiceLine(
    'idle_ack',
    'Harika, buradasın. Devam ediyoruz.',
  );

  static const reRingLine = VoiceLine(
    'rering',
    '{ad}, tekrar uyuduğunu düşünüyorum. Alarmı yeniden çalıyorum!',
  );

  static const snoozeMore = VoiceLine(
    'snooze_more',
    'Tamam {ad}, {dk} dakika erteledim. Ama bil ki ertelemek çoğu zaman daha sersem uyandırır. Bu sürede uyumaya çalışma, gözlerini açık tut ve esne. Bir erteleme hakkın daha var.',
    clipText: 'Tamam {ad}, alarmı biraz erteledim. Ama bil ki ertelemek çoğu zaman daha sersem uyandırır. Bu sürede uyumaya çalışma, gözlerini açık tut ve esne. Bir erteleme hakkın daha var.',
  );

  static const snoozeLast = VoiceLine(
    'snooze_last',
    'Tamam {ad}, {dk} dakika erteledim. Ama bil ki ertelemek çoğu zaman daha sersem uyandırır. Bu sürede uyumaya çalışma, gözlerini açık tut ve esne. Bu son ertelemeydi, bir dahaki sefere kalkıyoruz.',
    clipText: 'Tamam {ad}, alarmı biraz erteledim. Ama bil ki ertelemek çoğu zaman daha sersem uyandırır. Bu sürede uyumaya çalışma, gözlerini açık tut ve esne. Bu son ertelemeydi, bir dahaki sefere kalkıyoruz.',
  );

  static const finalAll = VoiceLine(
    'final_all',
    'Tebrikler {ad}! Sabah rutininin tüm {n} adımını tamamladın.',
    clipText: 'Tebrikler {ad}! Sabah rutininin bütün adımlarını tamamladın.',
  );

  static const finalSome = VoiceLine(
    'final_some',
    'Tebrikler {ad}! {n} adımın {done} tanesini tamamladın.',
    clipText: 'Tebrikler {ad}! Adımların bir kısmını tamamladın. Yarın hepsini yaparız.',
  );

  static const finalNone = VoiceLine(
    'final_none',
    'Bugün adımları atladın ama uyandın, bu da bir başlangıç {ad}.',
  );

  static const streakOn = VoiceLine(
    'streak_on',
    'Serin {seri} gün oldu, zinciri kırmıyorsun!',
    clipText: 'Serin devam ediyor, zinciri kırmıyorsun!',
  );

  static const streakNew = VoiceLine(
    'streak_new',
    'Yeni bir seri başladı. Yarın ikinci halkayı ekleyelim.',
  );

  static const closers = [
    VoiceLine(
      'closer_1',
      'Güne kazanan olarak başladın. Harika bir gün geçir {ad}!',
    ),
    VoiceLine('closer_2', 'Bugünün ilk zaferi senin. Şimdi gün senin {ad}!'),
    VoiceLine(
      'closer_3',
      'Yarın sabah yine buradayım. Harika bir gün dilerim {ad}!',
    ),
    VoiceLine('closer_4', 'Kendinle gurur duy {ad}. Bu enerjiyle güne başla!'),
  ];

  static const helloLine = VoiceLine(
    'hello',
    'Merhaba {ad}! Ben senin sabah koçunum. Her sabah seni uyandıracağım ve güne birlikte başlayacağız.',
  );

  /// Rutin adımının kayıt kimliği.
  static String stepClipId(RoutineStep step) => 'step_${step.id}';

  static VoiceLine stepLine(RoutineStep step) => VoiceLine(
    stepClipId(step),
    [
      '${step.title}.',
      step.instruction,
      step.why,
    ].where((s) => s.trim().isNotEmpty).join(' '),
  );

  /// Seslendirme metni: kaydedilecek tüm cümleler, bölüm bölüm.
  static List<VoiceGroup> script({List<RoutineStep> steps = defaultRoutine}) {
    return [
      const VoiceGroup(
        'Alarm çalarken – nazik',
        'İlk 45 saniye. Yumuşak, sakin, fısıltıya yakın.',
        wakeGentle,
      ),
      const VoiceGroup(
        'Alarm çalarken – motive edici',
        '45 saniye – 2 dakika arası. Sıcak ve ikna edici.',
        wakePurpose,
      ),
      const VoiceGroup(
        'Alarm çalarken – enerjik',
        '2 dakikadan sonra. Yüksek enerji, coşkulu, gülümseyerek.',
        wakeEnergetic,
      ),
      const VoiceGroup(
        'Uyandığında',
        'Ekrana dokunulunca sırayla: karşılama + (hızlı uyandıysa) övgü + günün cümlesi + (hedef varsa) hatırlatma + rutin başlangıcı.',
        [
          ...awakeOpeners,
          awakeFast,
          ...dayLines,
          awakeReason,
          routineStart,
          welcomeBackLine,
        ],
      ),
      VoiceGroup(
        'Rutin adımları',
        'Her adım için bir kayıt. Net ve yönlendirici; adımlar arasında kısa nefes payı bırak.',
        [for (final s in steps) stepLine(s), hintVoice, hintTouch],
      ),
      const VoiceGroup(
        'Adım geçişleri',
        'Kısa ve neşeli. Övgüden sonra "kalan adım" cümlesi eklenebilir.',
        [...praise, ...remainingLines, ...skipped],
      ),
      const VoiceGroup(
        'Zamanlayıcı ve sesli komut yanıtları',
        'Hareket ve nefes adımlarında; çok kısa.',
        [timerHalf, timerTen, timerDone, pauseAckLine, resumeAckLine],
      ),
      const VoiceGroup(
        'Tekrar uyuma koruması ve erteleme',
        'Uzun süre ses gelmezse. Önce şefkatli, alarm uyarısı kararlı.',
        [...idle, idleAckLine, reRingLine, snoozeMore, snoozeLast],
      ),
      const VoiceGroup(
        'Kapanış',
        'Rutin bitince sırayla: sonuç + seri + kapanış cümlesi. Kutlama tonu.',
        [finalAll, finalSome, finalNone, streakOn, streakNew, ...closers],
      ),
      const VoiceGroup('Tanışma', 'Uygulama ilk açıldığında bir kez.', [
        helloLine,
      ]),
    ];
  }

  // =====================================================================
  // Konuşmalar
  // =====================================================================

  /// Alarm çalarken söylenecek cümle. [level] 1–3 arası.
  Speech wakeCall(int level, MotivationContext c) {
    final pool = switch (level) {
      <= 1 => wakeGentle,
      2 => wakePurpose,
      _ => wakeEnergetic,
    };
    return _speech([_pick('wake$level', pool, c)], c);
  }

  /// Alarmın çalmaya başlamasından bu yana geçen süreye göre seviye.
  static int levelFor(Duration ringingFor) {
    if (ringingFor.inSeconds < 45) return 1;
    if (ringingFor.inSeconds < 120) return 2;
    return 3;
  }

  /// Ekrana dokunulduğu an söylenen karşılama.
  Speech awakeGreeting(
    MotivationContext c, {
    required Duration latency,
    required int stepCount,
  }) {
    final seconds = max(0, latency.inSeconds);
    return _speech(
      [
        _pick('awake', awakeOpeners, c),
        if (seconds <= 60) awakeFast,
        dayLines[c.now.weekday - 1],
        if (awakeReason.usable(c)) awakeReason,
        if (stepCount > 0) routineStart,
      ],
      c,
      {'sn': '$seconds', 'n': '$stepCount'},
    );
  }

  /// Tekrar uyuyup alarmla yeniden uyanan kullanıcıya.
  Speech welcomeBack(MotivationContext c) => _speech([welcomeBackLine], c);

  Speech stepIntro(
    RoutineStep step, {
    required int index,
    required int total,
    required bool voiceCommands,
    MotivationContext? context,
  }) {
    final c = context ?? MotivationContext(now: DateTime.now());
    final line = stepLine(step);
    final SpeechPart part;
    if (clips.contains(line.id)) {
      part = SpeechPart(_fill(line.scriptText, c), clip: line.id);
    } else {
      final ordinal = index == total - 1 ? 'Son adım' : '${index + 1}. adım';
      part = SpeechPart('$ordinal: ${line.text}');
    }
    final parts = [part];
    if (index == 0) {
      parts.add(_part(voiceCommands ? hintVoice : hintTouch, c));
    }
    return Speech(parts);
  }

  Speech stepDone(MotivationContext c, {required int remaining}) => _speech([
    _pick('praise', praise, c),
    if (remaining >= 1 && remaining <= 3) remainingLines[remaining - 1],
  ], c);

  Speech stepSkipped(MotivationContext c) =>
      _speech([_pick('skip', skipped, c)], c);

  Speech timerHalfway() => _fixed(timerHalf);
  Speech timerLastSeconds() => _fixed(timerTen);
  Speech timerFinished() => _fixed(timerDone);
  Speech pauseAck() => _fixed(pauseAckLine);
  Speech resumeAck() => _fixed(resumeAckLine);

  Speech inactivityCheck(MotivationContext c) =>
      _speech([_pick('idle', idle, c)], c);

  Speech idleAck(MotivationContext c) => _speech([idleAckLine], c);

  Speech reRingWarning(MotivationContext c) => _speech([reRingLine], c);

  Speech snoozed(MotivationContext c, int minutes) => _speech(
    [c.snoozesLeft > 0 ? snoozeMore : snoozeLast],
    c,
    {'dk': '$minutes'},
  );

  Speech finale(MotivationContext c, {required int done, required int total}) {
    return _speech(
      [
        if (total > 0 && done == total)
          finalAll
        else if (done > 0)
          finalSome
        else
          finalNone,
        if (c.streak >= 2)
          streakOn
        else if (c.streak == 1 && done > 0)
          streakNew,
        _pick('closer', closers, c),
      ],
      c,
      {'n': '$total', 'done': '$done'},
    );
  }

  Speech hello(MotivationContext c) => _speech([helloLine], c);

  // =====================================================================
  // Yardımcılar
  // =====================================================================

  Speech _fixed(VoiceLine line) =>
      _speech([line], MotivationContext(now: DateTime.now()));

  Speech _speech(
    List<VoiceLine> lines,
    MotivationContext c, [
    Map<String, String> extra = const {},
  ]) => Speech([for (final l in lines) _part(l, c, extra)]);

  SpeechPart _part(
    VoiceLine line,
    MotivationContext c, [
    Map<String, String> extra = const {},
  ]) {
    if (clips.contains(line.id)) {
      return SpeechPart(_fill(line.scriptText, c, extra), clip: line.id);
    }
    return SpeechPart(_fill(line.text, c, extra));
  }

  VoiceLine _pick(String key, List<VoiceLine> pool, MotivationContext c) {
    var candidates = <int>[
      for (var i = 0; i < pool.length; i++)
        if (pool[i].usable(c)) i,
    ];
    // Kayıtlı ses varken, kaydı olan cümleleri tercih et.
    final recorded = candidates
        .where((i) => clips.contains(pool[i].id))
        .toList();
    if (recorded.isNotEmpty) candidates = recorded;
    final last = _lastPick[key];
    final options = candidates.length > 1
        ? candidates.where((i) => i != last).toList()
        : candidates;
    final chosen = options[_random.nextInt(options.length)];
    _lastPick[key] = chosen;
    return pool[chosen];
  }

  static String _fill(
    String text,
    MotivationContext c, [
    Map<String, String> extra = const {},
  ]) {
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
        .replaceAll('{gün}', weekdayLong[c.now.weekday - 1].toLowerCase())
        // Cümle başındaki saat büyük harfle, cümle içindeki küçük harfle.
        .replaceAllMapped(
          RegExp(r'(^|[.!?]\s+)\{saat\}'),
          (m) => '${m[1]}${_capitalize(spokenTime(c.now))}',
        )
        .replaceAll('{saat}', spokenTime(c.now));
    for (final e in extra.entries) {
      out = out.replaceAll('{${e.key}}', e.value);
    }
    out = out
        .replaceAll(RegExp(r'\s+([,.!?])'), r'$1')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return _capitalize(out);
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
