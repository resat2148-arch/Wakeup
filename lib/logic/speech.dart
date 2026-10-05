/// Asistanın söylediği bir konuşmanın bir parçası.
///
/// [clip] doluysa bu parça için kaydedilmiş bir ses dosyası vardır ve o
/// çalınır; yoksa [text] cihazın metin okuma motoruyla seslendirilir.
/// [text] her durumda ekranda altyazı olarak gösterilir.
class SpeechPart {
  const SpeechPart(this.text, {this.clip});

  final String text;
  final String? clip;

  @override
  String toString() => clip == null ? text : '[$clip] $text';
}

/// Sırayla seslendirilen parçalardan oluşan konuşma.
class Speech {
  const Speech(this.parts);

  Speech.text(String text) : parts = [SpeechPart(text)];

  static const empty = Speech([]);

  final List<SpeechPart> parts;

  bool get isEmpty => parts.every((p) => p.text.trim().isEmpty);

  /// Altyazı: tüm parçaların metni.
  String get text =>
      parts.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join(' ');

  Speech operator +(Speech other) => Speech([...parts, ...other.parts]);

  @override
  String toString() => text;
}
