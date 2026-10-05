import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../logic/voice_commands.dart';

/// Rutin sırasında kısa sesli komutları ("tamam", "atla"...) dinler.
class CommandListener {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  String? _localeId;

  bool get available => _available;
  bool get isListening => _speech.isListening;

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

  /// Bir komut duyulana ya da süre dolana kadar dinler. Komut tanınınca
  /// [onCommand] bir kez çağrılır.
  Future<void> listenOnce(
    void Function(VoiceCommand command) onCommand, {
    Duration listenFor = const Duration(seconds: 20),
  }) async {
    if (!_available) return;
    if (_speech.isListening) await _speech.stop();
    var handled = false;
    try {
      await _speech.listen(
        onResult: (result) {
          if (handled) return;
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
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
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
