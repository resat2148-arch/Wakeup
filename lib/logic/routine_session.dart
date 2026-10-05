import '../models/routine_step.dart';

enum StepOutcome { pending, done, skipped }

/// Bir sabah rutininin ilerleyişini tutan saf (platformdan bağımsız) durum
/// makinesi. Arayüz ve ses katmanı bunun üzerine kuruludur.
class RoutineSession {
  RoutineSession(List<RoutineStep> steps)
    : steps = List.unmodifiable(steps.where((s) => s.enabled)),
      _outcomes = List.filled(
        steps.where((s) => s.enabled).length,
        StepOutcome.pending,
      );

  final List<RoutineStep> steps;
  final List<StepOutcome> _outcomes;
  int _index = 0;

  int get index => _index;
  int get total => steps.length;
  bool get isFinished => _index >= steps.length;
  RoutineStep? get current => isFinished ? null : steps[_index];
  bool get isLast => _index == steps.length - 1;

  List<StepOutcome> get outcomes => List.unmodifiable(_outcomes);
  int get doneCount => _outcomes.where((o) => o == StepOutcome.done).length;
  int get skippedCount =>
      _outcomes.where((o) => o == StepOutcome.skipped).length;

  /// 0.0 – 1.0 arası ilerleme.
  double get progress => total == 0 ? 1 : _index / total;

  void complete() => _advance(StepOutcome.done);

  void skip() => _advance(StepOutcome.skipped);

  void _advance(StepOutcome outcome) {
    if (isFinished) return;
    _outcomes[_index] = outcome;
    _index++;
  }
}
