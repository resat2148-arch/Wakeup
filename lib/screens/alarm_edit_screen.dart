import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../models/wake_alarm.dart';
import '../services/permissions.dart';
import '../services/services.dart';

/// Alarm kurma / düzenleme ekranı.
class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key, this.alarm});

  final WakeAlarm? alarm;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late AlarmSound _sound;
  late final TextEditingController _label;
  late final TextEditingController _reason;

  static const _reasonIdeas = [
    'sıcak bir kahve',
    'sabah sporum',
    'önemli bir toplantı',
    'sevdiklerimle kahvaltı',
    'yeni bir şey öğrenmek',
    'sakin bir kitap saati',
  ];

  bool get _isNew => widget.alarm == null;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _time = a == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay(hour: a.hour, minute: a.minute);
    _weekdays = {
      ...a?.weekdays ?? {1, 2, 3, 4, 5},
    };
    _sound = a?.sound ?? AlarmSound.sunrise;
    _label = TextEditingController(text: a?.label ?? '');
    _reason = TextEditingController(text: a?.reason ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Uyanma saati',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alarm = WakeAlarm(
      id: widget.alarm?.id ?? services.state.newAlarmId(),
      hour: _time.hour,
      minute: _time.minute,
      weekdays: _weekdays,
      enabled: true,
      label: _label.text.trim(),
      reason: _reason.text.trim(),
      sound: _sound,
    );
    await Permissions.requestAlarmPermissions();
    await services.state.saveAlarm(alarm);
    final next = nextOccurrence(alarm, DateTime.now());
    messenger.showSnackBar(
      SnackBar(
        content: Text('Alarm ${timeUntilText(next, DateTime.now())} çalacak.'),
      ),
    );
    navigator.pop();
  }

  Future<void> _delete() async {
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    await services.state.deleteAlarm(widget.alarm!.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni alarm' : 'Alarmı düzenle'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _pickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                formatTime(_time.hour, _time.minute),
                textAlign: TextAlign.center,
                style: text.displayLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          Text(
            'Saati değiştirmek için dokun',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Tekrar', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(weekdayShort[d - 1]),
                  selected: _weekdays.contains(d),
                  onSelected: (on) => setState(() {
                    on ? _weekdays.add(d) : _weekdays.remove(d);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(repeatSummary(_weekdays), style: text.bodySmall),
          const SizedBox(height: 24),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'Bu sabah seni ne bekliyor? 🎯',
              hintText: 'örn. sıcak bir kahve',
              helperText:
                  'Alarm çalarken sana bunu hatırlatacağım. '
                  'Güne dair bir beklenti, kalkmayı kolaylaştırır.',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final idea in _reasonIdeas)
                ActionChip(
                  label: Text(idea),
                  onPressed: () => setState(() => _reason.text = idea),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Alarm adı (isteğe bağlı)',
              hintText: 'örn. İş günü',
            ),
          ),
          const SizedBox(height: 24),
          Text('Alarm sesi', style: text.titleMedium),
          RadioGroup<AlarmSound>(
            groupValue: _sound,
            onChanged: (v) => setState(() => _sound = v ?? _sound),
            child: Column(
              children: [
                for (final sound in AlarmSound.values)
                  RadioListTile<AlarmSound>(
                    contentPadding: EdgeInsets.zero,
                    value: sound,
                    title: Text(sound.title),
                  ),
              ],
            ),
          ),
          Text(
            'İki ses de melodiktir: araştırmalar melodik alarmların '
            'sert "bip" seslerine göre daha az sersemlik yarattığını gösteriyor.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _save,
            icon: const Icon(Icons.alarm),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
