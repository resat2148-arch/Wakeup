import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../logic/voice_commands.dart';

/// Rutin sırasında sesli komutları ("yaptım", "atla", "tekrar"...) dinler.
///
/// Telefon cihazın konuşma tanıma servisini kullanır. Bir dinleme oturumu
/// sessizlikte kendiliğinden kapanır; ekran tarafı oturum kapanınca hemen
/// yenisini başlatır, böylece telefona dokunmadan rutin ilerler.
class CommandListener {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  String? _localeId;

  bool get available => _available;
  bool get isListening => _speech.isListening;

  /// Mikrofon izni önceden verilmişse dinlemeye hazırlanır. Sabah izin
  /// penceresi açmamak için burada izin istenmez.
  Future<bool> prepare() async {
    try {
      if (!await Permission.microphone.isGranted) return false;
    } catch (e) {
      debugPrint('Mikrofon izni okunamadı: $e');
      return false;
    }
    return init();
  }

  Future<bool> init() async {
    if (_available) return true;
    try {
      _available = await _speech.initialize(
        onError: (e) => debugPrint('Konuşma tanıma hatası: ${e.errorMsg}'),
      );
      if (_available) {
        final locales = await _speech.locales();
        final turkish = locales
            .where((l) => l.localeId.toLowerCase().startsWith('tr'))
            .toList();
        _localeId = turkish.isNotEmpty ? turkish.first.localeId : null;
      }
    } catch (e) {
      debugPrint('Konuşma tanıma başlatılamadı: $e');
      _available = false;
    }
    return _available;
  }

  /// Bir komut duyulana ya da oturum kapanana kadar dinler. Komut tanınınca
  /// [onCommand] bir kez çağrılır. [onSpeech] tanınan her sözde çağrılır;
  /// kullanıcının uyanık olduğunu anlamak için kullanılır.
  Future<void> listen(
    void Function(VoiceCommand command) onCommand, {
    VoidCallback? onSpeech,
    Duration listenFor = const Duration(seconds: 60),
  }) async {
    if (!_available) return;
    if (_speech.isListening) await _speech.stop();
    var handled = false;
    try {
      await _speech.listen(
        onResult: (result) {
          if (handled) return;
          if (result.recognizedWords.trim().isNotEmpty) onSpeech?.call();
          final command = parseVoiceCommand(result.recognizedWords);
          if (command != null) {
            handled = true;
            _speech.stop();
            onCommand(command);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          // Kısa komutların daha iyi tanınması için ipucu (iOS 17+).
          contextualPhrases: const [
            'yaptım',
            'tamam',
            'bitti',
            'atla',
            'tekrar',
            'bekle',
            'devam',
            'buradayım',
          ],
        ),
      );
    } catch (e) {
      debugPrint('Dinleme başlatılamadı: $e');
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.cancel();
  }
}
