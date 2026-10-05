import 'dart:async';
import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic/motivation.dart';
import '../logic/routine_session.dart';
import '../logic/schedule.dart';
import '../logic/voice_commands.dart';
import '../models/routine_step.dart';
import '../models/user_settings.dart';
import '../models/wake_alarm.dart';
import '../models/wake_record.dart';
import '../services/alarm_scheduler.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/sunrise_background.dart';

enum _Phase { ringing, routine, finished }

/// Alarm çaldığında açılan ekran.
///
/// 1. **Çalıyor:** Melodik alarm çalar, asistan belirli aralıklarla giderek
///    daha enerjik motive edici sözler söyler. Ekrana herhangi bir dokunuş
///    kullanıcının uyandığı anlamına gelir.
/// 2. **Rutin:** Asistan her adımı sesli anlatır; kullanıcı "Yaptım"a basar ya
///    da "tamam" der. Uzun süre etkileşim olmazsa önce sorar, sonra alarmı
///    yeniden çalar (tekrar uykuya dalma koruması).
/// 3. **Bitti:** Özet, seri ve kapanış sözleri.
class WakeScreen extends StatefulWidget {
  const WakeScreen({super.key, required this.ringing});

  final AlarmSettings ringing;

  @override
  State<WakeScreen> createState() => _WakeScreenState();
}

class _WakeScreenState extends State<WakeScreen> {
  late Services _s;
  bool _initialized = false;

  late RingPayload _payload;
  WakeAlarm? _alarm;
  late DateTime _firstRingAt;
  DateTime? _awakeAt;

  _Phase _phase = _Phase.ringing;
  DateTime _phaseStartedAt = clock.now();
  DateTime? _lastTalkAt;
  DateTime _now = clock.now();
  Timer? _ticker;

  RoutineSession? _session;
  bool _transitioning = false;
  DateTime _lastTransitionAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _stepToken = 0;
  int _stepRemaining = 0;
  bool _stepTimerRunning = false;
  bool _stepTimerPaused = false;
  bool _halfwaySaid = false;
  bool _lastTenSaid = false;

  bool _speaking = false;
  int _speechToken = 0;
  String _caption = '';

  bool _listeningEnabled = false;
  DateTime? _lastListenStart;

  DateTime _lastInteraction = clock.now();
  DateTime? _inactivityWarnedAt;

  UserSettings get _settings => _s.state.settings;

  int get _snoozesLeft => max(0, _settings.maxSnoozes - _payload.snoozes);

  bool get _isTest => widget.ringing.id == AlarmScheduler.testAlarmId;

  MotivationContext _ctx({int? streak}) => MotivationContext(
    now: clock.now(),
    name: _settings.name,
    reason: _alarm?.reason ?? '',
    streak: streak ?? _s.state.streak,
    snoozesLeft: _snoozesLeft,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _s = AppScope.of(context);
    _payload = RingPayload.decode(widget.ringing.payload);
    _alarm = _s.state.alarmById(widget.ringing.id);
    _firstRingAt = _payload.firstRingAt ?? widget.ringing.dateTime;
    _phaseStartedAt = clock.now();
    _setWakelock(true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _prepareListening();
  }

  /// Rutin boyunca ekranın kararmasını engelle.
  Future<void> _setWakelock(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      debugPrint('Ekran açık tutulamadı: $e');
    }
  }

  Future<void> _prepareListening() async {
    if (!_settings.voiceCommands) return;
    // Sabah izin penceresi açmamak için yalnızca önceden verilmiş izinle dinle.
    if (!await Permission.microphone.isGranted) return;
    final ok = await _s.listener.init();
    if (mounted) setState(() => _listeningEnabled = ok);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _s.voice.stop();
    _s.listener.stop();
    _setWakelock(false);
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Konuşma
  // -----------------------------------------------------------------------

  Future<void> _say(String text) async {
    final token = ++_speechToken;
    await _s.listener.stop();
    if (!mounted) return;
    setState(() {
      _speaking = true;
      _caption = text;
    });
    await _s.voice.say(text);
    if (!mounted || token != _speechToken) return;
    setState(() => _speaking = false);
  }

  // -----------------------------------------------------------------------
  // Zamanlayıcı
  // -----------------------------------------------------------------------

  void _tick() {
    if (!mounted) return;
    final now = clock.now();
    setState(() => _now = now);
    switch (_phase) {
      case _Phase.ringing:
        _tickRinging(now);
      case _Phase.routine:
        _tickRoutine(now);
      case _Phase.finished:
        break;
    }
  }

  void _tickRinging(DateTime now) {
    if (!_settings.talkWhileRinging || _speaking) return;
    final due = _lastTalkAt == null
        ? now.difference(_phaseStartedAt).inSeconds >= 4
        : now.difference(_lastTalkAt!).inSeconds >=
              _settings.talkIntervalSeconds;
    if (due) _talkWake();
  }

  Future<void> _talkWake() async {
    _lastTalkAt = clock.now();
    final level = MotivationEngine.levelFor(
      clock.now().difference(_phaseStartedAt),
    );
    await _say(_s.motivation.wakeCall(level, _ctx()));
    if (_phase == _Phase.ringing) _lastTalkAt = clock.now();
  }

  void _tickRoutine(DateTime now) {
    final step = _session?.current;
    if (step == null || _transitioning) return;

    if (_stepTimerRunning) {
      // Zamanlı adım sürerken uyku koruması bekler.
      _lastInteraction = now;
      if (!_stepTimerPaused) _advanceStepTimer(step);
    } else if (!_speaking) {
      _checkSleepGuard(now);
    }

    if (_listeningEnabled &&
        _phase == _Phase.routine &&
        !_speaking &&
        !_s.listener.isListening &&
        (_lastListenStart == null ||
            now.difference(_lastListenStart!).inSeconds >= 8)) {
      _startListening();
    }
  }

  void _advanceStepTimer(RoutineStep step) {
    setState(() => _stepRemaining--);
    final long = step.durationSeconds >= 30;
    if (long && !_halfwaySaid && _stepRemaining == step.durationSeconds ~/ 2) {
      _halfwaySaid = true;
      _say(_s.motivation.timerHalfway());
    } else if (long && !_lastTenSaid && _stepRemaining == 10) {
      _lastTenSaid = true;
      _say(_s.motivation.timerLastSeconds());
    }
    if (_stepRemaining <= 0) {
      setState(() => _stepTimerRunning = false);
      _completeStep(prefix: _s.motivation.timerFinished());
    }
  }

  void _checkSleepGuard(DateTime now) {
    final guard = _settings.sleepBackGuardSeconds;
    if (guard <= 0) return;
    if (_inactivityWarnedAt == null) {
      if (now.difference(_lastInteraction).inSeconds >= guard) {
        _inactivityWarnedAt = now;
        _say(_s.motivation.inactivityCheck(_ctx()));
      }
    } else if (now.difference(_inactivityWarnedAt!).inSeconds >= 30) {
      _reRing();
    }
  }

  // -----------------------------------------------------------------------
  // Etkileşim
  // -----------------------------------------------------------------------

  void _onInteraction() {
    _lastInteraction = clock.now();
    _inactivityWarnedAt = null;
  }

  Future<void> _onAwake() async {
    if (_phase != _Phase.ringing || _transitioning) return;
    _transitioning = true;
    HapticFeedback.heavyImpact();
    final resuming = _session != null;
    setState(() {
      _phase = _Phase.routine;
      _caption = '';
    });
    _onInteraction();
    _speechToken++;
    await _s.voice.stop();
    try {
      await _s.scheduler.dismiss(_alarm, widget.ringing.id, _settings);
      await _s.state.markRang(widget.ringing.id);
    } catch (e) {
      debugPrint('Alarm durdurulamadı: $e');
    }
    _awakeAt ??= clock.now();
    final session = _session ??= RoutineSession(_s.state.routine);
    _transitioning = false;

    final greeting = resuming
        ? _s.motivation.welcomeBack(_ctx())
        : _s.motivation.awakeGreeting(
            _ctx(),
            latency: _awakeAt!.difference(_firstRingAt),
            stepCount: session.total,
          );
    await _enterStep(prefix: greeting);
  }

  Future<void> _enterStep({String prefix = ''}) async {
    final session = _session;
    if (session == null || _phase != _Phase.routine) return;
    final step = session.current;
    if (step == null) {
      await _finish(prefix: prefix);
      return;
    }
    final token = ++_stepToken;
    setState(() {
      _stepRemaining = step.durationSeconds;
      _stepTimerRunning = false;
      _stepTimerPaused = false;
      _halfwaySaid = false;
      _lastTenSaid = false;
    });
    final intro = _s.motivation.stepIntro(
      step,
      index: session.index,
      total: session.total,
      voiceCommands: _listeningEnabled,
    );
    await _say(prefix.isEmpty ? intro : '$prefix $intro');
    if (!mounted || token != _stepToken || _phase != _Phase.routine) return;
    _onInteraction();
    if (step.timed) setState(() => _stepTimerRunning = true);
  }

  /// Art arda iki dokunuşun iki adımı birden geçmesini önler.
  bool get _recentlyTransitioned =>
      clock.now().difference(_lastTransitionAt).inMilliseconds < 1500;

  Future<void> _completeStep({String? prefix}) async {
    final session = _session;
    if (session == null || session.isFinished || _transitioning) return;
    if (_phase != _Phase.routine || _recentlyTransitioned) return;
    _transitioning = true;
    _lastTransitionAt = clock.now();
    _onInteraction();
    HapticFeedback.lightImpact();
    session.complete();
    _stepToken++;
    setState(() => _stepTimerRunning = false);
    final remaining = session.total - session.index;
    final praise = _s.motivation.stepDone(_ctx(), remaining: remaining);
    _transitioning = false;
    final text = [?prefix, if (!session.isFinished) praise].join(' ');
    await _enterStep(prefix: text);
  }

  Future<void> _skipStep() async {
    final session = _session;
    if (session == null || session.isFinished || _transitioning) return;
    if (_recentlyTransitioned) return;
    _transitioning = true;
    _lastTransitionAt = clock.now();
    _onInteraction();
    session.skip();
    _stepToken++;
    setState(() => _stepTimerRunning = false);
    _transitioning = false;
    await _enterStep(
      prefix: session.isFinished ? '' : _s.motivation.stepSkipped(_ctx()),
    );
  }

  Future<void> _repeatStep() async {
    final session = _session;
    final step = session?.current;
    if (session == null || step == null) return;
    _onInteraction();
    await _say(
      _s.motivation.stepIntro(
        step,
        index: session.index,
        total: session.total,
        voiceCommands: false,
      ),
    );
  }

  void _togglePause() {
    _onInteraction();
    setState(() => _stepTimerPaused = !_stepTimerPaused);
  }

  Future<void> _startListening() async {
    _lastListenStart = clock.now();
    _s.voice.markAudioSessionDirty();
    final token = _stepToken;
    await _s.listener.listenOnce((command) {
      if (!mounted || token != _stepToken || _phase != _Phase.routine) return;
      _onInteraction();
      switch (command) {
        case VoiceCommand.done:
          _completeStep();
        case VoiceCommand.skip:
          _skipStep();
        case VoiceCommand.repeat:
          _repeatStep();
        case VoiceCommand.pause:
          if (_stepTimerRunning && !_stepTimerPaused) _togglePause();
        case VoiceCommand.resume:
          if (_stepTimerRunning && _stepTimerPaused) _togglePause();
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _reRing() async {
    _stepToken++;
    _inactivityWarnedAt = null;
    await _say(_s.motivation.reRingWarning(_ctx()));
    if (!mounted || _phase != _Phase.routine) return;
    setState(() {
      _phase = _Phase.ringing;
      _phaseStartedAt = clock.now();
      _lastTalkAt = clock.now();
      _stepTimerRunning = false;
    });
    try {
      await _s.scheduler.reRing(
        _alarm,
        widget.ringing.id,
        _settings,
        _payload,
        _firstRingAt,
      );
    } catch (e) {
      debugPrint('Alarm yeniden kurulamadı: $e');
    }
  }

  Future<void> _snooze() async {
    if (_snoozesLeft <= 0 || _phase != _Phase.ringing) return;
    final minutes = _settings.snoozeMinutes;
    final ctx = MotivationContext(
      now: clock.now(),
      name: _settings.name,
      snoozesLeft: _snoozesLeft - 1,
    );
    _speechToken++;
    await _s.voice.stop();
    await _s.scheduler.snooze(widget.ringing, minutes);
    setState(() => _phase = _Phase.finished);
    await _say(_s.motivation.snoozed(ctx, minutes));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish({String prefix = ''}) async {
    if (_phase == _Phase.finished) return;
    _stepToken++;
    await _s.listener.stop();
    final session = _session;
    setState(() {
      _phase = _Phase.finished;
      _stepTimerRunning = false;
    });
    final now = clock.now();
    if (!_isTest) {
      await _s.state.addRecord(
        WakeRecord(
          ringAt: _firstRingAt,
          awakeAt: _awakeAt ?? now,
          completedAt: now,
          snoozes: _payload.snoozes,
          stepsDone: session?.doneCount ?? 0,
          stepsTotal: session?.total ?? 0,
        ),
      );
    }
    final finale = _s.motivation.finale(
      _ctx(),
      done: session?.doneCount ?? 0,
      total: session?.total ?? 0,
    );
    await _say(prefix.isEmpty ? finale : '$prefix $finale');
  }

  Future<void> _confirmEndRoutine() async {
    _onInteraction();
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rutini bitir?'),
        content: const Text('Kalan adımlar atlanmış sayılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (end != true) return;
    final session = _session;
    while (session != null && !session.isFinished) {
      session.skip();
    }
    await _finish();
  }

  // -----------------------------------------------------------------------
  // Arayüz
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sunrise = switch (_phase) {
      // Alarm çalarken güneş ufuktan yavaşça doğar.
      _Phase.ringing =>
        0.12 +
            (_now.difference(_phaseStartedAt).inSeconds / 120 * 0.38).clamp(
              0.0,
              0.38,
            ),
      _Phase.routine => 0.5 + 0.5 * (_session?.progress ?? 0),
      _Phase.finished => 1.0,
    };
    return PopScope(
      canPop: _phase == _Phase.finished,
      child: Scaffold(
        body: SunriseBackground(
          progress: sunrise.toDouble(),
          child: SafeArea(
            child: switch (_phase) {
              _Phase.ringing => _buildRinging(context),
              _Phase.routine => Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _onInteraction(),
                child: _buildRoutine(context),
              ),
              _Phase.finished => _buildFinished(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRinging(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reason = _alarm?.reason.trim() ?? '';
    return Stack(
      children: [
        // Ekranın herhangi bir yerine dokunmak = uyandım.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _onAwake(),
          ),
        ),
        IgnorePointer(
          child: _FitOrScroll(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  formatTime(_now.hour, _now.minute),
                  style: text.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                    fontSize: 88,
                  ),
                ),
                Text(
                  _alarm?.label.isNotEmpty == true
                      ? _alarm!.label
                      : 'Günaydın!',
                  style: text.titleLarge?.copyWith(color: Colors.white70),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bugün seni bekleyen: $reason',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(color: Colors.white),
                  ),
                ],
                const Spacer(),
                const _PulsingTapHint(),
                const SizedBox(height: 24),
                _Caption(text: _caption, speaking: _speaking),
                const Spacer(),
              ],
            ),
          ),
        ),
        if (_snoozesLeft > 0 && _session == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: _snooze,
                icon: const Icon(Icons.snooze),
                label: Text(
                  '${_settings.snoozeMinutes} dk ertele ($_snoozesLeft hak)',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoutine(BuildContext context) {
    final session = _session;
    final step = session?.current;
    final text = Theme.of(context).textTheme;
    if (session == null || step == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return _FitOrScroll(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Adım ${session.index + 1} / ${session.total}',
                style: text.titleMedium?.copyWith(color: Colors.white),
              ),
              const Spacer(),
              if (_listeningEnabled)
                Icon(
                  _s.listener.isListening ? Icons.mic : Icons.mic_none,
                  color: _s.listener.isListening ? sunriseGold : Colors.white54,
                ),
              IconButton(
                tooltip: 'Rutini bitir',
                color: Colors.white70,
                onPressed: _confirmEndRoutine,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StepDots(session: session),
          const Spacer(),
          Text(
            step.emoji,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 12),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.instruction,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: Colors.white),
          ),
          if (step.why.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              step.why,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (step.timed) ...[
            const SizedBox(height: 24),
            _StepTimer(
              total: step.durationSeconds,
              remaining: _stepRemaining,
              running: _stepTimerRunning,
              paused: _stepTimerPaused,
              onTogglePause: _togglePause,
            ),
          ],
          const Spacer(),
          _Caption(text: _caption, speaking: _speaking),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: nightIndigo,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: text.titleLarge,
            ),
            onPressed: _completeStep,
            icon: const Icon(Icons.check_circle),
            label: Text(session.isLast ? 'Yaptım, bitir!' : 'Yaptım'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _repeatStep,
                icon: const Icon(Icons.replay),
                label: const Text('Tekrar söyle'),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _skipStep,
                icon: const Icon(Icons.skip_next),
                label: const Text('Atla'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final session = _session;
    final latency = _awakeAt?.difference(_firstRingAt);
    return _FitOrScroll(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Text(
            '🌞',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 88),
          ),
          const SizedBox(height: 12),
          Text(
            session == null ? 'Görüşmek üzere!' : 'Güne hazırsın!',
            textAlign: TextAlign.center,
            style: text.headlineLarge?.copyWith(
              color: nightIndigo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (session != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  icon: Icons.check_circle,
                  label: '${session.doneCount}/${session.total} adım',
                ),
                if (latency != null)
                  _StatChip(
                    icon: Icons.alarm_on,
                    label: '${max(0, latency.inSeconds)} sn’de uyandın',
                  ),
                _StatChip(
                  icon: Icons.local_fire_department,
                  label: '${_s.state.streak} günlük seri',
                ),
              ],
            ),
          const SizedBox(height: 24),
          _Caption(text: _caption, speaking: _speaking, dark: true),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: nightIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: text.titleLarge,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Güne başla'),
          ),
        ],
      ),
    );
  }
}

/// Ekran yeterince büyükse içeriği yayar (Spacer'lar çalışır), küçükse
/// taşmak yerine kaydırılabilir hale getirir.
class _FitOrScroll extends StatelessWidget {
  const _FitOrScroll({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: max(0, constraints.maxHeight - padding.vertical),
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

class _PulsingTapHint extends StatefulWidget {
  const _PulsingTapHint();

  @override
  State<_PulsingTapHint> createState() => _PulsingTapHintState();
}

class _PulsingTapHintState extends State<_PulsingTapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.touch_app, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Uyandıysan ekrana dokun',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Asistanın o an söylediği cümlenin altyazısı.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.speaking,
    this.dark = false,
  });

  final String text;
  final bool speaking;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 48);
    final color = dark ? nightIndigo : Colors.white;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: speaking ? 1 : 0.7,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              speaking ? Icons.record_voice_over : Icons.chat_bubble_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 15, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.session});

  final RoutineSession session;

  @override
  Widget build(BuildContext context) {
    final outcomes = session.outcomes;
    return Row(
      children: [
        for (var i = 0; i < outcomes.length; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: switch (outcomes[i]) {
                  StepOutcome.done => Colors.white,
                  StepOutcome.skipped => Colors.white38,
                  StepOutcome.pending =>
                    i == session.index ? sunriseGold : Colors.white24,
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _StepTimer extends StatelessWidget {
  const _StepTimer({
    required this.total,
    required this.remaining,
    required this.running,
    required this.paused,
    required this.onTogglePause,
  });

  final int total;
  final int remaining;
  final bool running;
  final bool paused;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (total - remaining) / total;
    return Center(
      child: GestureDetector(
        onTap: running ? onTogglePause : null,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value.clamp(0.0, 1.0),
                strokeWidth: 8,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${max(0, remaining)}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      !running
                          ? 'hazırlan'
                          : paused
                          ? 'duraklatıldı'
                          : 'saniye',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: sunriseOrange),
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.85),
      side: BorderSide.none,
    );
  }
}
