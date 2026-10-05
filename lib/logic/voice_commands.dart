/// Rutin sırasında kullanıcının sesle verebileceği komutlar.
enum VoiceCommand { done, skip, repeat, pause, resume }

/// Türkçe büyük/küçük harf dönüşümünü doğru yapan sadeleştirme.
String normalizeTurkish(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'I':
        buffer.write('ı');
      case 'İ':
        buffer.write('i');
      default:
        buffer.write(ch.toLowerCase());
    }
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _keywords = <VoiceCommand, List<String>>{
  // Daha belirgin komutlar önce denenir.
  VoiceCommand.skip: ['atla', 'geç', 'sonraki', 'pas', 'istemiyorum'],
  VoiceCommand.repeat: [
    'tekrar',
    'tekrarla',
    'anlamadım',
    'bir daha',
    'ne dedin',
  ],
  VoiceCommand.pause: ['bekle', 'dur', 'durdur', 'bi dakika', 'bir dakika'],
  VoiceCommand.resume: ['devam', 'devam et', 'başla', 'hadi'],
  VoiceCommand.done: [
    'tamam',
    'tamamdır',
    'tamamladım',
    'yaptım',
    'yapdım',
    'bitti',
    'bitirdim',
    'hazırım',
    'hazır',
    'oldu',
    'evet',
    'kalktım',
    'uyandım',
    'içtim',
    'yıkadım',
    'açtım',
    'topladım',
    'ok',
    'okey',
  ],
};

/// Tanınan metni bir komuta çevirir; eşleşme yoksa `null` döner.
VoiceCommand? parseVoiceCommand(String recognized) {
  final text = normalizeTurkish(recognized);
  if (text.isEmpty) return null;
  final words = text.split(' ');
  for (final entry in _keywords.entries) {
    for (final keyword in entry.value) {
      final matches = keyword.contains(' ')
          ? text.contains(keyword)
          : words.contains(keyword);
      if (matches) return entry.key;
    }
  }
  return null;
}
