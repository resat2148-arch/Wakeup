import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../logic/speech.dart';

/// Asistanın sesi.
///
/// Bir cümlenin kaydı `assets/voice/<kimlik>.mp3` (ya da .m4a/.wav/.ogg)
/// olarak uygulamaya eklenmişse o kayıt çalınır; yoksa metin cihazın Türkçe
/// metin okuma motoruyla seslendirilir.
class VoiceService {
  VoiceService();

  static const voiceAssetDir = 'assets/voice/';
  static const _clipExtensions = {'.mp3', '.m4a', '.aac', '.wav', '.ogg'};

  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _player;
  bool _ready = false;
  bool _turkishAvailable = true;
  bool _audioSessionDirty = true;
  int _token = 0;
  Completer<void>? _clipDone;

  /// Kayıt kimliği → asset yolu ("voice/wake_gentle_1.mp3").
  final Map<String, String> _clips = {};

  /// Cihazda Türkçe ses paketi yoksa `false` olur; arayüz uyarı gösterir.
  bool get turkishAvailable => _turkishAvailable;

  Set<String> get clipIds => _clips.keys.toSet();

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
    await loadClips();
  }

  /// Uygulamaya eklenmiş ses kayıtlarını bulur.
  Future<Set<String>> loadClips() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _clips.clear();
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith(voiceAssetDir)) continue;
        final file = asset.substring(voiceAssetDir.length);
        final dot = file.lastIndexOf('.');
        if (dot <= 0 || !_clipExtensions.contains(file.substring(dot))) {
          continue;
        }
        _clips[file.substring(0, dot)] = asset.substring('assets/'.length);
      }
    } catch (e) {
      debugPrint('Ses kayıtları okunamadı: $e');
    }
    return clipIds;
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
    await _player?.setAudioContext(_clipContext);
    _audioSessionDirty = false;
  }

  static final _clipContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.assistant,
      // Alarm melodisi konuşma sırasında kısılır.
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {
        AVAudioSessionOptions.duckOthers,
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    await player.setAudioContext(_clipContext);
    await player.setReleaseMode(ReleaseMode.stop);
    _player = player;
    return player;
  }

  /// Konuşmayı parça parça seslendirir ve bitene kadar bekler. Önceki
  /// konuşmayı keser.
  Future<void> say(Speech speech) async {
    if (speech.isEmpty) return;
    await stop();
    final token = _token;
    try {
      await _prepareAudioSession();
      for (final part in speech.parts) {
        if (token != _token) return;
        final asset = part.clip == null ? null : _clips[part.clip];
        if (asset != null) {
          await _playClip(asset);
        } else if (part.text.trim().isNotEmpty && _ready) {
          // Android'de `focus: true` ses odağı ister; alarm bu sırada kısılır.
          await _tts.speak(part.text, focus: !kIsWeb && Platform.isAndroid);
        }
      }
    } catch (e) {
      debugPrint('Seslendirme hatası: $e');
    }
  }

  Future<void> sayText(String text) => say(Speech.text(text));

  Future<void> _playClip(String asset) async {
    final player = await _ensurePlayer();
    final done = Completer<void>();
    _clipDone = done;
    final sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.play(AssetSource(asset));
      await done.future.timeout(const Duration(seconds: 45), onTimeout: () {});
    } finally {
      await sub.cancel();
    }
  }

  Future<void> stop() async {
    _token++;
    final pending = _clipDone;
    if (pending != null && !pending.isCompleted) pending.complete();
    try {
      await _player?.stop();
      if (_ready) await _tts.stop();
    } catch (e) {
      debugPrint('Ses durdurulamadı: $e');
    }
  }
}
