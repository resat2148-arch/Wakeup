import 'package:flutter/material.dart';

import '../services/permissions.dart';
import '../services/services.dart';
import '../theme.dart';

/// İlk açılışta: isim, nasıl çalıştığı ve izinler.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  bool _voiceCommands = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    final services = AppScope.of(context);
    await Permissions.requestAlarmPermissions();
    var voice = _voiceCommands;
    if (voice) voice = await Permissions.requestVoicePermissions();
    final name = _nameController.text.trim();
    await services.state.saveSettings(
      services.state.settings.copyWith(
        name: name,
        voiceCommands: voice,
        onboarded: true,
      ),
    );
    await services.voice.say(
      name.isEmpty
          ? 'Merhaba! Ben senin sabah koçunum. Her sabah seni uyandırıp güne birlikte başlayacağız.'
          : 'Merhaba $name! Ben senin sabah koçunum. Her sabah seni uyandırıp güne birlikte başlayacağız.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: dawnGradient(0.35)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Text(
                '🌅',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text(
                'Günaydın Koçu',
                textAlign: TextAlign.center,
                style: text.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seni sesli uyandıran, motive eden ve sabah rutinini birlikte yaptıran asistan.',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 28),
              const _HowItWorks(),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Sana nasıl hitap edeyim?',
                          hintText: 'Adın',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _voiceCommands,
                        onChanged: (v) => setState(() => _voiceCommands = v),
                        title: const Text('Sesli komutlar'),
                        subtitle: const Text(
                          'Rutin sırasında "tamam", "atla", "tekrar" diyerek ilerle. Mikrofon izni gerekir.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: nightIndigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saving ? null : _start,
                child: Text(_saving ? 'Hazırlanıyor…' : 'Başlayalım'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        '⏰',
        'Melodik alarm',
        'Sert bip sesleri yerine yavaşça yükselen melodiler – daha az sersemlik.',
      ),
      (
        '🗣️',
        'Seninle konuşur',
        'Alarm çalarken seni adınla çağırır, bugün seni neyin beklediğini hatırlatır.',
      ),
      (
        '👆',
        'Dokun = uyandım',
        'Ekrana dokunduğunda uyandığını anlar ve sabah rutinine geçer.',
      ),
      (
        '✅',
        'Rutini yaptırır',
        'Işık, su, soğuk su, hareket… Her adımı sesle anlatır ve cesaretlendirir.',
      ),
      (
        '😴',
        'Tekrar uyumana izin vermez',
        'Uzun süre ses çıkmazsa sorar, cevap yoksa alarmı yeniden çalar.',
      ),
    ];
    return Column(
      children: [
        for (final (emoji, title, body) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(body, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
