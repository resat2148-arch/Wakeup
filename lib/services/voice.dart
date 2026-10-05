import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Metni Türkçe sese çeviren servis (cihazın kendi TTS motoru).
class VoiceService {
  VoiceService();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _turkishAvailable = true;
  bool _audioSessionDirty = true;

  /// Cihazda Türkçe ses paketi yoksa `false` olur; arayüz uyarı gösterir.
  bool get turkishAvailable => _turkishAvailable;

  Future<void> init({double rate = 0.5, double pitch = 1.0}) async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final available = await _tts.isLanguageAvailable('tr-TR');
      _turkishAvailable = available == true || available == 1;
      await _tts.setLanguage('tr-TR');
      if (!kIsWeb && Platform.isIOS) {
        await _tts.setSharedInstance(true);
      }
      await configure(rate: rate, pitch: pitch);
      _ready = true;
    } catch (e) {
      debugPrint('TTS başlatılamadı: $e');
    }
  }

  Future<void> configure({required double rate, required double pitch}) async {
    await _tts.setSpeechRate(rate.clamp(0.2, 0.9));
    await _tts.setPitch(pitch.clamp(0.6, 1.6));
    await _tts.setVolume(1.0);
  }

  /// Konuşma tanıma iOS ses oturumunu değiştirdiğinde çağrılır; bir sonraki
  /// konuşmadan önce oturum yeniden ayarlanır.
  void markAudioSessionDirty() => _audioSessionDirty = true;

  Future<void> _prepareAudioSession() async {
    if (!_audioSessionDirty || kIsWeb || !Platform.isIOS) return;
    // Alarm sesi çalarken onu kısarak (duck) konuş.
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.duckOthers,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ], IosTextToSpeechAudioMode.spokenAudio);
    _audioSessionDirty = false;
  }

  /// Söyler ve konuşma bitene kadar bekler. Önceki konuşmayı keser.
  Future<void> say(String text) async {
    if (!_ready || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _prepareAudioSession();
      // Android'de `focus: true` ses odağı ister; alarm sesi bu sırada kısılır.
      await _tts.speak(text, focus: !kIsWeb && Platform.isAndroid);
    } catch (e) {
      debugPrint('TTS hatası: $e');
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    await _tts.stop();
  }
}
