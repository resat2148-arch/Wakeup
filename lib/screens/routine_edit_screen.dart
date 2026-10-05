import 'package:flutter/material.dart';

import '../models/routine_step.dart';
import '../services/services.dart';

/// Sabah rutininin adımlarını düzenleme: sırala, aç/kapat, ekle, düzenle.
class RoutineEditScreen extends StatelessWidget {
  const RoutineEditScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    List<RoutineStep> steps, [
    int? index,
  ]) async {
    final services = AppScope.of(context);
    final result = await showModalBottomSheet<RoutineStep>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StepEditor(step: index == null ? null : steps[index]),
    );
    if (result == null) return;
    final updated = List.of(steps);
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    await services.state.saveRoutine(updated);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final steps = state.routine;
        final activeCount = steps.where((s) => s.enabled).length;
        final totalSeconds = steps
            .where((s) => s.enabled)
            .fold<int>(0, (sum, s) => sum + (s.timed ? s.durationSeconds : 45));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sabah rutini'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'reset') await state.resetRoutine();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reset', child: Text('Varsayılana dön')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, steps),
            icon: const Icon(Icons.add),
            label: const Text('Adım ekle'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  '$activeCount adım · yaklaşık ${(totalSeconds / 60).ceil()} dakika. '
                  'Sıralamak için basılı tutup sürükle.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: steps.length,
                  onReorderItem: (from, to) {
                    final updated = List.of(steps);
                    updated.insert(to, updated.removeAt(from));
                    state.saveRoutine(updated);
                  },
                  itemBuilder: (context, i) {
                    final step = steps[i];
                    return Dismissible(
                      key: ValueKey(step.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.delete),
                      ),
                      onDismissed: (_) =>
                          state.saveRoutine(List.of(steps)..removeAt(i)),
                      child: ListTile(
                        leading: Text(
                          step.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(step.title),
                        subtitle: Text(
                          step.timed
                              ? '${step.durationSeconds} sn zamanlayıcı'
                              : 'Sen "yaptım" deyince geçilir',
                        ),
                        onTap: () => _edit(context, steps, i),
                        trailing: Switch(
                          value: step.enabled,
                          onChanged: (v) {
                            final updated = List.of(steps);
                            updated[i] = step.copyWith(enabled: v);
                            state.saveRoutine(updated);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepEditor extends StatefulWidget {
  const _StepEditor({this.step});

  final RoutineStep? step;

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late final TextEditingController _emoji;
  late final TextEditingController _title;
  late final TextEditingController _instruction;
  late final TextEditingController _why;
  late int _duration;

  static const _durations = [0, 15, 30, 60, 90, 120, 180, 300];

  @override
  void initState() {
    super.initState();
    final s = widget.step;
    _emoji = TextEditingController(text: s?.emoji ?? '⭐');
    _title = TextEditingController(text: s?.title ?? '');
    _instruction = TextEditingController(text: s?.instruction ?? '');
    _why = TextEditingController(text: s?.why ?? '');
    _duration = s?.durationSeconds ?? 0;
    if (!_durations.contains(_duration)) _duration = 0;
  }

  @override
  void dispose() {
    _emoji.dispose();
    _title.dispose();
    _instruction.dispose();
    _why.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final instruction = _instruction.text.trim();
    Navigator.pop(
      context,
      RoutineStep(
        id:
            widget.step?.id ??
            'custom_${DateTime.now().millisecondsSinceEpoch}',
        emoji: _emoji.text.trim().isEmpty ? '⭐' : _emoji.text.trim(),
        title: title,
        instruction: instruction.isEmpty ? '$title zamanı.' : instruction,
        why: _why.text.trim(),
        durationSeconds: _duration,
        enabled: widget.step?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.step == null ? 'Yeni adım' : 'Adımı düzenle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _emoji,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(labelText: 'Simge'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Başlık'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instruction,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Sesli yönerge',
                hintText: 'Asistanın bu adımda söyleyeceği cümle',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _why,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Neden? (isteğe bağlı)',
                hintText: 'Motivasyon için kısa bir gerekçe',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Zamanlayıcı'),
              items: [
                for (final d in _durations)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      overflow: TextOverflow.ellipsis,
                      d == 0
                          ? 'Yok – "yaptım" deyince geç'
                          : d < 60
                          ? '$d saniye'
                          : '${d ~/ 60} dakika${d % 60 == 0 ? '' : ' ${d % 60} sn'}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _duration = v ?? 0),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }
}
