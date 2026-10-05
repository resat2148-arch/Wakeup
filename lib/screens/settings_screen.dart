import 'package:flutter/material.dart';

import '../logic/motivation.dart';
import '../models/user_settings.dart';
import '../services/permissions.dart';
import '../services/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text = AppScope.of(context).state.settings.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _update(UserSettings settings) async {
    final services = AppScope.of(context);
    await services.state.saveSettings(settings);
    await services.voice.configure(
      rate: settings.speechRate,
      pitch: settings.pitch,
    );
  }

  Future<void> _testVoice(UserSettings settings) async {
    final services = AppScope.of(context);
    await services.voice.configure(
      rate: settings.speechRate,
      pitch: settings.pitch,
    );
    await services.voice.say(
      services.motivation.wakeCall(
        2,
        MotivationContext(
          now: DateTime.now(),
          name: settings.name,
          streak: services.state.streak,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.state,
      builder: (context, _) {
        final s = services.state.settings;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Ayarlar')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Adın',
                    prefixIcon: Icon(Icons.person),
                  ),
                  onSubmitted: (v) => _update(s.copyWith(name: v.trim())),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    if (_name.text.trim() != s.name) {
                      _update(s.copyWith(name: _name.text.trim()));
                    }
                  },
                ),
              ),
              _Section('Ses'),
              ListTile(
                title: const Text('Konuşma hızı'),
                subtitle: Slider(
                  value: s.speechRate,
                  min: 0.3,
                  max: 0.7,
                  divisions: 8,
                  label: s.speechRate.toStringAsFixed(2),
                  onChanged: (v) => _update(s.copyWith(speechRate: v)),
                ),
              ),
              ListTile(
                title: const Text('Ses tonu'),
                subtitle: Slider(
                  value: s.pitch,
                  min: 0.7,
                  max: 1.4,
                  divisions: 7,
                  label: s.pitch.toStringAsFixed(1),
                  onChanged: (v) => _update(s.copyWith(pitch: v)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text('Sesi dene'),
                onTap: () => _testVoice(s),
              ),
              _Section('Uyandırma'),
              SwitchListTile(
                value: s.talkWhileRinging,
                onChanged: (v) => _update(s.copyWith(talkWhileRinging: v)),
                title: const Text('Alarm çalarken konuş'),
                subtitle: const Text(
                  'Adınla çağırır ve motive edici sözler söyler',
                ),
              ),
              _ChoiceTile<int>(
                title: 'Konuşma aralığı',
                value: s.talkIntervalSeconds,
                options: const {
                  15: '15 sn',
                  20: '20 sn',
                  30: '30 sn',
                  45: '45 sn',
                },
                onChanged: (v) => _update(s.copyWith(talkIntervalSeconds: v)),
              ),
              SwitchListTile(
                value: s.vibrate,
                onChanged: (v) => _update(s.copyWith(vibrate: v)),
                title: const Text('Titreşim'),
              ),
              _ChoiceTile<int>(
                title: 'Erteleme hakkı',
                value: s.maxSnoozes,
                options: const {0: 'Yok', 1: '1 kez', 2: '2 kez', 3: '3 kez'},
                onChanged: (v) => _update(s.copyWith(maxSnoozes: v)),
              ),
              _ChoiceTile<int>(
                title: 'Erteleme süresi',
                value: s.snoozeMinutes,
                options: const {3: '3 dk', 5: '5 dk', 9: '9 dk', 10: '10 dk'},
                onChanged: (v) => _update(s.copyWith(snoozeMinutes: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Erteleme uyku döngüsünü yeniden başlatıp sersemliği artırabilir; '
                  'hakkı az tutmanı öneririm.',
                  style: text.bodySmall,
                ),
              ),
              _Section('Rutin'),
              _ChoiceTile<int>(
                title: 'Tekrar uyuma koruması',
                value: s.sleepBackGuardSeconds,
                options: const {
                  0: 'Kapalı',
                  60: '1 dk',
                  90: '1,5 dk',
                  120: '2 dk',
                  180: '3 dk',
                },
                onChanged: (v) => _update(s.copyWith(sleepBackGuardSeconds: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Rutin sırasında bu süre boyunca ekrana dokunmazsan sana seslenirim; '
                  '30 saniye içinde cevap gelmezse alarm yeniden çalar.',
                  style: text.bodySmall,
                ),
              ),
              SwitchListTile(
                value: s.voiceCommands,
                onChanged: (v) async {
                  var enabled = v;
                  if (v) enabled = await Permissions.requestVoicePermissions();
                  await _update(s.copyWith(voiceCommands: enabled));
                },
                title: const Text('Sesli komutlar (eller serbest)'),
                subtitle: const Text(
                  'Rutinde telefona dokunmadan ilerle: "yaptım", "atla", "tekrar", "bekle", "devam", "buradayım"',
                ),
              ),
              _Section('Güvenilirlik'),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Alarm izinlerini kontrol et'),
                onTap: Permissions.requestAlarmPermissions,
              ),
              ListTile(
                leading: const Icon(Icons.battery_saver),
                title: const Text('Pil optimizasyonunu kapat (Android)'),
                subtitle: const Text('Bazı telefonlar alarmı geciktirebilir'),
                onTap: Permissions.requestIgnoreBatteryOptimizations,
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('iPhone kullanıyorsan'),
                subtitle: Text(
                  'Alarmın çalması için uygulamayı arka planda açık bırak '
                  '(yukarı kaydırarak kapatma) ve Sessiz modu / Odak modunu kontrol et.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: options.containsKey(value) ? value : options.keys.first,
        underline: const SizedBox.shrink(),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
