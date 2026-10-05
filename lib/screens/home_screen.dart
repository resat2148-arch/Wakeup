import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/schedule.dart';
import '../logic/stats.dart';
import '../models/wake_alarm.dart';
import '../services/permissions.dart';
import '../services/services.dart';
import '../theme.dart';
import 'alarm_edit_screen.dart';
import 'routine_edit_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;
  bool _batteryOk = true;

  @override
  void initState() {
    super.initState();
    // Kalan süre yazısını güncel tut.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    Permissions.batteryOptimizationIgnored().then((ok) {
      if (mounted) setState(() => _batteryOk = ok);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _openEditor([WakeAlarm? alarm]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlarmEditScreen(alarm: alarm)),
    );
  }

  Future<void> _testAlarm() async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Permissions.requestAlarmPermissions();
    await services.scheduler.scheduleTest(services.state.settings);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Deneme alarmı 10 saniye sonra çalacak. İstersen ekranı kilitle.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final state = services.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final enabled = state.alarms.where((a) => a.enabled).toList();
        DateTime? next;
        for (final a in enabled) {
          final t = nextOccurrence(a, now);
          if (next == null || t.isBefore(next)) next = t;
        }
        final name = state.settings.name;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Günaydın Koçu'),
            actions: [
              IconButton(
                tooltip: 'Sabah rutini',
                icon: const Icon(Icons.checklist),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineEditScreen(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ayarlar',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_alarm),
            label: const Text('Alarm kur'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _HeroCard(name: name, next: next, now: now),
              const SizedBox(height: 12),
              _StatsRow(
                streak: state.streak,
                completed: completedCount(state.history),
                avgLatency: averageWakeLatency(state.history),
              ),
              if (!services.voice.turkishAvailable) ...[
                const SizedBox(height: 12),
                const _WarningCard(
                  text:
                      'Cihazında Türkçe ses paketi bulunamadı. '
                      'Ayarlar › Metin okuma bölümünden Türkçe sesi indir.',
                ),
              ],
              if (!_batteryOk) ...[
                const SizedBox(height: 12),
                _WarningCard(
                  text: 'Alarmın gecikmemesi için pil optimizasyonunu bu uygulama için kapat.',
                  action: 'Kapat',
                  onAction: () async {
                    await Permissions.requestIgnoreBatteryOptimizations();
                    final ok = await Permissions.batteryOptimizationIgnored();
                    if (mounted) setState(() => _batteryOk = ok);
                  },
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alarmlar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _testAlarm,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Şimdi dene'),
                  ),
                ],
              ),
              if (state.alarms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Henüz alarm yok.\nİlk alarmını kur, yarın sabah birlikte uyanalım!',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final alarm in state.alarms)
                _AlarmTile(
                  alarm: alarm,
                  onTap: () => _openEditor(alarm),
                  onToggle: (v) => state.toggleAlarm(alarm.id, v),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.next, required this.now});

  final String name;
  final DateTime? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hello = now.hour < 12
        ? 'Günaydın'
        : now.hour < 18
        ? 'İyi günler'
        : 'İyi akşamlar';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: dawnGradient(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? '$hello!' : '$hello, $name!',
            style: text.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (next == null)
            Text(
              'Kurulu alarm yok',
              style: text.headlineSmall?.copyWith(color: Colors.white),
            )
          else ...[
            Text(
              formatTime(next!.hour, next!.minute),
              style: text.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${weekdayLong[next!.weekday - 1]} · ${timeUntilText(next!, now)}',
              style: text.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
          if (now.hour >= 20 || now.hour < 2) ...[
            const SizedBox(height: 12),
            Text(
              '💡 Yarın kolay uyanmak için ekranı bırak ve 7–9 saat uyumayı hedefle.',
              style: text.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.completed,
    required this.avgLatency,
  });

  final int streak;
  final int completed;
  final Duration? avgLatency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(emoji: '🔥', value: '$streak', label: 'günlük seri'),
        const SizedBox(width: 8),
        _StatCard(emoji: '✅', value: '$completed', label: 'tamamlanan sabah'),
        const SizedBox(width: 8),
        _StatCard(
          emoji: '⚡',
          value: avgLatency == null ? '–' : '${avgLatency!.inSeconds} sn',
          label: 'ort. uyanma',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({
    required this.alarm,
    required this.onTap,
    required this.onToggle,
  });

  final WakeAlarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = !alarm.enabled;
    final subtitle = [
      repeatSummary(alarm.weekdays),
      if (alarm.label.isNotEmpty) alarm.label,
    ].join(' · ');
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTime(alarm.hour, alarm.minute),
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted ? Theme.of(context).disabledColor : null,
                      ),
                    ),
                    Text(subtitle, style: text.bodyMedium),
                    if (alarm.reason.isNotEmpty)
                      Text(
                        '🎯 ${alarm.reason}',
                        style: text.bodySmall?.copyWith(color: sunriseOrange),
                      ),
                  ],
                ),
              ),
              Switch(value: alarm.enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}
