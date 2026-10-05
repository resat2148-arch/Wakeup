// Seslendirme metnini uygulamanın cümle kataloğundan üretir.
//
//   dart run tool/export_voice_script.dart
//
// Çıktılar: voiceover/seslendirme_metni.md, voiceover/clips.csv,
// voiceover/clips.json
import 'dart:convert';
import 'dart:io';

import 'package:wakeup_coach/logic/motivation.dart';

String forRecording(String text) => text
    .replaceAll(RegExp(r',\s*\{ad\}'), ' [, adın]')
    .replaceAll(RegExp(r'\{ad\}'), '[adın]');

void main() {
  final groups = MotivationEngine.script();
  final total = groups.fold<int>(0, (n, g) => n + g.lines.length);

  final md = StringBuffer()
    ..writeln('# Günaydın Koçu – Seslendirme Metni')
    ..writeln()
    ..writeln('Toplam $total kayıt. Her satırı ayrı bir dosya olarak kaydet ve')
    ..writeln('dosyaya **tablodaki adı** ver (ör. `wake_gentle_1.mp3`).')
    ..writeln()
    ..writeln(
      '- Biçim: MP3 (ya da M4A/WAV), mono, 44.1 kHz; başta ve sonda en fazla',
    )
    ..writeln('  0,3 sn sessizlik.')
    ..writeln(
      '- `[adın]` yazan yerde adını söyleyebilir ya da o kısmı atlayabilirsin.',
    )
    ..writeln(
      '- Ton notları her bölümün başında. Doğal, sıcak, gülümseyerek konuş.',
    )
    ..writeln(
      '- Kaydı olmayan cümleler cihazın sentetik sesiyle okunur; eksik kalan',
    )
    ..writeln(
      '  sorun olmaz ama sesler karışmasın diye hepsini kaydetmek en iyisi.',
    )
    ..writeln();
  final csv = StringBuffer('dosya,bolum,metin\n');
  final json = <Map<String, Object>>[];

  for (final g in groups) {
    md
      ..writeln('## ${g.title}')
      ..writeln()
      ..writeln('_${g.note}_')
      ..writeln()
      ..writeln('| Dosya | Metin |')
      ..writeln('|---|---|');
    final lines = <Map<String, String>>[];
    for (final l in g.lines) {
      final text = forRecording(l.scriptText);
      md.writeln('| `${l.id}.mp3` | ${text.replaceAll('|', '\\|')} |');
      csv.writeln('${l.id}.mp3,"${g.title}","${text.replaceAll('"', '""')}"');
      lines.add({'id': l.id, 'text': text});
    }
    md.writeln();
    json.add({'title': g.title, 'note': g.note, 'lines': lines});
  }

  File('voiceover/seslendirme_metni.md').writeAsStringSync(md.toString());
  File('voiceover/clips.csv').writeAsStringSync(csv.toString());
  File('voiceover/clips.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln('$total kayıt yazıldı.');
}
