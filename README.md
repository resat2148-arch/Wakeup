# Günaydın Koçu ☀️

Android ve iOS için **sesli uyandırma ve sabah rutini asistanı** (Flutter).

Alarm çaldığında seninle adınla konuşur, bugün seni neyin beklediğini hatırlatır.
**Ekrana dokunduğunda uyandığını anlar** ve sabah rutinini adım adım sesle yaptırır.
Rutinin ortasında tekrar uyursan önce seslenir, cevap gelmezse alarmı yeniden çalar.

## Nasıl çalışır?

```
Alarm çalar ──► Melodik ses + asistan konuşur (giderek daha enerjik)
                │   "Günaydın Reşat. Saat yedi buçuk..."
                │   "Unutma: bugün seni sabah koşusu bekliyor!"
                │   "Beşten geriye sayıyorum..."
                ▼
Ekrana dokunuş = UYANDIM ──► Alarm susar, karşılama konuşması
                ▼
Sabah rutini (her adım sesli anlatılır)
  🛏️ Doğrul → ☀️ Işığa çık → 💧 Su iç → 🚿 Soğuk su → 🤸 1 dk hareket
  → 🧺 Yatağı topla → 🌬️ 30 sn nefes → 🎯 Günün niyeti
  "Yaptım" düğmesi ya da sesli komut: "tamam", "atla", "tekrar", "bekle", "devam"
                │
                ├─ 90 sn etkileşim yok → "Hâlâ benimle misin?"
                │     └─ 30 sn daha yok → alarm yeniden çalar 🔁
                ▼
Bitiş: özet, seri (🔥 kaç gündür), kapanış motivasyonu
```

## Araştırma: İnsanı uyanmaya ne motive eder?

Uygulamadaki her özellik ve her cümle aşağıdaki bulgulara dayanıyor
(`lib/logic/motivation.dart`, `lib/models/routine_step.dart`):

| Bulgu | Uygulamada |
|---|---|
| **Melodik alarmlar** sert "bip" seslerine göre uyku ataletini (sersemliği) anlamlı ölçüde azaltıyor; dikkat hatalarını düşürüyor (RMIT, PLoS One). | Sentezlenmiş iki melodik alarm sesi; ses 25 sn'de yavaşça yükseliyor. |
| **Uyku ataleti** 15 dk–birkaç saat sürebilen geçici bir sis; bunun normal olduğunu bilmek ve hareket etmek geçmesini hızlandırıyor. | "Şu an hissettiğin sersemlik normal, adı uyku ataleti…" |
| **Ertelemek** uyku döngüsünü yeniden başlatıp sersemliği artırıyor. | Erteleme hakkı varsayılan 1 kez; ertelerken nedeni sesle anlatılıyor. |
| **Sabah ışığı** melatonini baskılayıp kortizolü yükseltiyor, uyanıklığı ve ruh halini artırıyor. | Rutinin 2. adımı: perdeyi aç / ışığa çık. |
| **Soğuk suyla yüz yıkama** dalış refleksi ve noradrenalin ile anında uyanıklık sağlıyor. | "Yüzünü soğuk suyla yıka" adımı. |
| **Sevilen / heyecan verici müzik ve hareket** sersemliği azaltıyor. | 1 dakikalık hareket adımı, zamanlayıcılı ve sesli. |
| **Uyanma görevleri** (alarmı kapatmadan önce yapılan basit iş) sabah hedef davranışı tamamlama oranını anlamlı artırıyor (JMIR 2022, squat çalışması). | Alarm sustuktan sonra rutin hemen başlıyor; hareketsizlikte alarm geri geliyor. |
| **Beklenti ve amaç**: güne dair somut bir neden yataktan çıkmayı kolaylaştırır; "uygulama niyeti" (eğer-o zaman planı) alışkanlığı güçlendirir. | Her alarm için "Bu sabah seni ne bekliyor? 🎯" alanı; alarm çalarken hatırlatılıyor. |
| **Telefonda kaydırmak** doğal dopamin düşüşünü bastırıp harekete geçme isteğini zayıflatıyor. | "Telefonda gezinmek yok, her adımda ben yanındayım." |
| **Seri, kimlik ve küçük kazanımlar** alışkanlığı pekiştirir. | 🔥 günlük seri, "Sen sözünü tutan birisin", her adımda övgü. |

**Kaynaklar**
- [Sound of music: How melodic alarms could reduce morning grogginess – RMIT](https://www.rmit.edu.au/news/media-releases-and-expert-comments/2020/feb/melodic-alarms)
- [Alarm tones, music and their elements – PLoS One / PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6986749/)
- [Auditory Countermeasures for Sleep Inertia – PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7445849/)
- [Sleep Inertia: How to Combat Morning Grogginess – Sleep Foundation](https://www.sleepfoundation.org/how-sleep-works/sleep-inertia)
- [Four ways to get out of bed in the morning – The Conversation / RTÉ](https://www.rte.ie/brainstorm/2025/0428/1509786-tips-getting-out-of-bed-in-the-morning-sleep-inertia-psychology/)
- [Using Wake-Up Tasks for Morning Behavior Change – JMIR Formative Research](https://formative.jmir.org/2022/9/e39497)
- [Awakening effects of blue-enriched morning light – Scientific Reports](https://www.nature.com/articles/s41598-018-36791-5)
- [The alerting effects of caffeine, bright light and face washing – Clinical Neurophysiology](https://www.sciencedirect.com/science/article/abs/pii/S1388245703002554)
- [The 17 Surprising Things That Make Getting Out of Bed Easier – Rise Science](https://www.risescience.com/blog/getting-out-of-bed)

## Özellikler

- ⏰ Tekrarlayan / tek seferlik alarmlar (hafta içi, hafta sonu, özel günler)
- 🎵 İki melodik alarm sesi, yavaş yükselen ses, titreşim
- 🗣️ Türkçe metin okuma (cihazın kendi TTS motoru, internet gerekmez); konuşma hızı ve tonu ayarlanabilir
- 👆 Ekranın herhangi bir yerine dokunmak = uyandım
- 🎙️ Eller serbest rutin: "yaptım" dedikçe sonraki adım ("atla", "tekrar", "bekle", "devam", "buradayım" da var)
- 🎤 Kendi seslendirmen: `assets/voice/` klasörüne konan kayıtlar sentetik sesin yerine çalınır
- 📝 Düzenlenebilir rutin: sırala, aç/kapat, yeni adım ekle, zamanlayıcı ver
- 😴 Tekrar uyuma koruması (süre ayarlanabilir)
- 📊 Seri, tamamlanan sabahlar, ortalama uyanma süresi
- 🧪 "Şimdi dene": 10 saniye sonra çalan deneme alarmı

## Eller serbest kullanım

Uyanmak için ekrana bir kez dokunursun. Rutin boyunca telefona dokunman gerekmez:
asistan her adımı anlatır, konuşması biter bitmez dinlemeye geçer ve sen
**"yaptım"** dedikçe bir sonraki adıma geçer.

| Söyle | Ne olur |
|---|---|
| "yaptım", "tamam", "bitti", "sıradaki", "geçelim" | Adım tamamlanır, sonrakine geçilir |
| "atla", "geç", "pas" | Adım atlanır |
| "tekrar", "anlamadım" | Adım yeniden anlatılır |
| "bekle", "dur" / "devam" | Zamanlı adımda süre durur / devam eder |
| "buradayım" (ya da herhangi bir söz) | Uyku korumasının "hâlâ benimle misin?" sorusuna yanıt |

Ayarlar › "Sesli komutlar" açık ve mikrofon izni verilmiş olmalı.

## Kendi sesinle seslendirme

Uygulamanın söylediği her cümlenin sabit bir kimliği var (`lib/logic/motivation.dart`).
`assets/voice/<kimlik>.mp3` dosyası varsa o kayıt çalınır, yoksa sentetik ses okur.

1. Metni üret: `dart run tool/export_voice_script.dart`. Çıktı `voiceover/` klasörüne yazılır:
   `seslendirme_metni.md`, `clips.csv` ve `clips.json`.
2. Her satırı ayrı dosya olarak kaydet; dosya adı tablodaki gibi olsun (`wake_gentle_1.mp3`).
3. Dosyaları `assets/voice/` klasörüne koy ve uygulamayı yeniden derle.

Kayıtlar varken motor kaydı olan cümleleri seçer. Saat, adım sayısı ve yazdığın hedef
gibi değişken bilgiler kayıtlarda yer almaz; bunlar ekranda yazıyla gösterilir.

## Proje yapısı

```
lib/
  main.dart, app.dart          Başlatma, alarm çalınca uyandırma ekranını açma
  logic/                       Platformdan bağımsız, birim testli mantık
    motivation.dart            Motivasyon motoru (araştırmaya dayalı cümleler)
    routine_session.dart       Rutin durum makinesi
    voice_commands.dart        Türkçe sesli komut ayrıştırıcı
    schedule.dart, stats.dart  Sonraki alarm zamanı, seri, istatistik
  models/                      WakeAlarm, RoutineStep, UserSettings, WakeRecord
  services/                    alarm, TTS, konuşma tanıma, izinler, depolama
  screens/                     Tanıtım, ana ekran, alarm/rutin düzenleme, ayarlar,
                               wake_screen.dart (çalıyor → rutin → bitti)
assets/sounds/                 Melodik alarm sesleri (stdlib ile sentezlendi)
test/                          46 birim + widget testi
tool/export_voice_script.dart  Seslendirme metnini üretir (voiceover/)
```

Kullanılan paketler: [`alarm`](https://pub.dev/packages/alarm),
[`flutter_tts`](https://pub.dev/packages/flutter_tts),
[`speech_to_text`](https://pub.dev/packages/speech_to_text),
`shared_preferences`, `permission_handler`, `wakelock_plus`.

## Çalıştırma

```bash
flutter pub get
flutter test          # 46 test
flutter run           # bağlı cihazda (Android veya iOS)
```

- **Android:** minSdk 24. İlk açılışta bildirim ve "tam zamanlı alarm" izni istenir.
  Samsung/Xiaomi gibi cihazlarda ana ekrandaki uyarıdan pil optimizasyonunu kapat.
- **iOS:** Xcode'da imzalama ekibini seç. Arka plan modları (audio, fetch),
  mikrofon/konuşma tanıma açıklamaları ve `AppDelegate` ayarları hazır.
- Türkçe ses yoksa ana ekran uyarır: Ayarlar › Metin okuma çıkışı › Türkçe ses paketini indir.

## Bilinen sınırlamalar

- **iOS:** Apple, üçüncü taraf uygulamaların sistem alarmı gibi çalmasına izin vermez.
  `alarm` eklentisi uygulamayı arka planda sessiz ses oturumuyla canlı tutar;
  kullanıcı uygulamayı yukarı kaydırıp **kapatırsa veya telefon yeniden başlarsa alarm
  yalnızca bildirim olarak gelir**. (Uygulama kapatılınca bunu bildiren bir uyarı gösterilir.)
  Daha sağlam bir çözüm için iOS 26'nın AlarmKit'ine
  ([flutter_alarmkit](https://pub.dev/packages/flutter_alarmkit)) geçiş düşünülebilir.
- Alarm çalarken asistanın sesi alarm melodisinin üzerine konuşur: iOS'ta melodi kısılır
  (duck), Android'de ses odağı istenir; gerçek cihazdaki ses dengesi denenmeli.
- Sesli komutlar cihazın konuşma tanıma servisine bağlıdır; bazı cihazlarda internet gerekebilir.
  Asistan konuşurken mikrofon kapalıdır: "yaptım"ı konuşma bittikten sonra söyle. Bazı Android
  telefonlar dinleme her başladığında kısa bir "bip" sesi çıkarır.
- Uygulama yalnızca Türkçe arayüzle hazırlandı.
