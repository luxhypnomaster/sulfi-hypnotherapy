import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/history_facts.dart';
import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../models/local_dates.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'session_actions.dart';
import 'modular_structure_screen.dart';
import 'history_attachment_panel.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    super.key,
    required this.controller,
    required this.runId,
    this.player,
    required this.onRepeat,
  });
  final SessionController controller;
  final String runId;
  final PreviewPlayer? player;
  final Future<void> Function(SessionRun run) onRepeat;
  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  SessionRun? run;
  List<Map<String, dynamic>>? events;
  final note = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await widget.controller.repository.history();
      final found = runs.where((r) => r.id == widget.runId).firstOrNull;
      final journal = await widget.controller.repository.events(widget.runId);
      if (!mounted) return;
      setState(() {
        run = found;
        events = journal;
        note.text = found?.notes ?? '';
        error = found == null ? 'Запись истории не найдена' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось прочитать историю. Вернитесь и повторите.',
        );
      }
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    await showActionError(context, action);
    if (mounted) setState(() => busy = false);
  }

  Future<void> _editor() async {
    final c = widget.controller;
    if (c.draft.modified &&
        !await confirmAction(
          context,
          'Открыть архив в редакторе?',
          'При применении он заменит текущую конфигурацию. История и шаблоны останутся прежними.',
          confirm: 'Открыть',
        )) {
      return;
    }
    final editor = await c.beginEditing();
    try {
      await editor.useRun(run!, rebuild: true);
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ModularStructureScreen(
            controller: editor,
            player: widget.player!,
          ),
        ),
      );
      await c.reload();
    } finally {
      editor.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: run == null ? 'История сессии' : 'История · №${run!.displayNumber}',
    child: error != null
        ? Center(child: Text(error!))
        : run == null || events == null
        ? const Center(child: CircularProgressIndicator())
        : _content(),
  );
  Widget _content() {
    final r = run!, plan = r.snapshot.plan;
    final facts = HistoryFacts(r, events!);
    final tracks = plan.steps.where((s) => s.kind == StepKind.audio).toList();
    final phases = plan.phases?.where((p) => p.enabled).toList();
    final completedPhases = phases
        ?.where(
          (p) =>
              facts.group(p.children.expand((c) => c.items)) ==
              StepFact.completed,
        )
        .length;

    return SingleChildScrollView(
      key: const Key('history-detail-scroll'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonPanel(
            color: antiqueGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  r.status.label,
                  style: const TextStyle(color: antiqueGold),
                ),
                Text(
                  'Начало: ${historicalDateLabel(r.startedAt, r.startedUtcOffsetMinutes, legacyLabel: r.name)}',
                ),
                Text(
                  '${r.endEstimated ? 'Последнее сохранение (время остановки неизвестно)' : 'Окончание'}: ${r.endedAt == null ? 'Нет данных' : historicalDateLabel(r.endedAt!, r.startedUtcOffsetMinutes)}',
                ),
                Text(
                  '${r.endEstimated ? 'Сохранённая' : 'Фактическая'} длительность: ${formatDuration(r.elapsedMs)}',
                ),
                Text(
                  'Источник: ${r.snapshot.baseTemplateName ?? 'Текущая конфигурация'}${r.snapshot.baseTemplateVersion == null ? '' : ' · версия ${r.snapshot.baseTemplateVersion}'}',
                ),
                Text(
                  'Подтверждено выполненных элементов: ${facts.completed} из ${plan.steps.length}',
                ),
                Text(
                  'Треки: ${tracks.where((s) => facts.step(s) == StepFact.completed).length}/${tracks.length} · Фазы: ${phases == null ? 'Нет данных' : '$completedPhases/${phases.length}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (r.snapshot.topicText.isNotEmpty)
                  Text('Тема: ${r.snapshot.topicText}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NeonPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Заметка о сессии',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextField(
                  key: const Key('history-note'),
                  controller: note,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'Можно оставить пустой',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => _action(() async {
                            await widget.controller.repository.editRun(
                              r.id,
                              notes: note.text,
                            );
                            await widget.controller.reload();
                            if (mounted) {
                              setState(
                                () => run = SessionRun.fromMap({
                                  ...r.toMap(),
                                  'userNotes': note.text,
                                }),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Заметка сохранена'),
                                ),
                              );
                            }
                          }),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Сохранить заметку'),
                  ),
                ),
                if (r.snapshot.baseTemplateId != null ||
                    r.snapshot.baseTemplateName != null)
                  Text(
                    'Описание исходного шаблона: ${r.snapshot.baseTemplateDescription == null
                        ? 'Нет данных'
                        : r.snapshot.baseTemplateDescription!.isEmpty
                        ? 'Не задано'
                        : r.snapshot.baseTemplateDescription}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.controller.historyAttachments != null &&
              widget.player != null)
            HistoryAttachmentPanel(
              controller: widget.controller,
              runId: r.id,
              player: widget.player!,
            ),
          const Text(
            'План и ход сессии',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: neonLime,
            ),
          ),
          const Text(
            'Зелёный — выполнено · красный — прерывание/ошибка · серый — нет подтверждения',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (plan.phases != null) ...[
            for (var i = 0; i < plan.phases!.length; i++)
              _phase(plan.phases![i], i + 1, facts),
          ] else ...[
            for (final s in plan.allSteps) _step(s, facts),
          ],
          const SizedBox(height: 16),
          NeonButton(
            key: const Key('history-repeat'),
            label: 'Повторить сессию',
            icon: Icons.replay,
            primary: true,
            onPressed: busy ? null : () => _action(() => widget.onRepeat(r)),
          ),
          const SizedBox(height: 10),
          NeonButton(
            key: const Key('history-open-editor'),
            label: 'Открыть в редакторе',
            icon: Icons.edit_outlined,
            onPressed: busy || widget.player == null
                ? null
                : () => _action(_editor),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _color(StepFact fact) => switch (fact) {
    StepFact.completed => Colors.lightGreenAccent,
    StepFact.interrupted => Colors.redAccent,
    _ => Colors.grey.shade400,
  };
  IconData _icon(StepFact fact) => switch (fact) {
    StepFact.completed => Icons.check_circle_outline,
    StepFact.interrupted => Icons.error_outline,
    StepFact.skipped => Icons.skip_next,
    StepFact.started => Icons.timelapse,
    _ => Icons.radio_button_unchecked,
  };
  String _label(StepFact fact) => switch (fact) {
    StepFact.completed => 'Выполнен',
    StepFact.interrupted => 'Прерывание / ошибка',
    StepFact.skipped => 'Пропуск подтверждён',
    StepFact.started => 'Начат · завершение не подтверждено',
    StepFact.disabled => 'Выключен в плане запуска',
    StepFact.unknown => 'Нет подтверждения выполнения',
  };
  Widget _phase(PhaseInstance p, int index, HistoryFacts facts) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: NeonPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _icon(facts.group(p.children.expand((c) => c.items))),
                color: _color(facts.group(p.children.expand((c) => c.items))),
                size: 21,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$index. ${p.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          for (final c in p.children)
            if (!c.isModule) ...[
              for (final s in c.items) _step(s, facts),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: NeonPanel(
                  padding: const EdgeInsets.all(7),
                  color: antiqueGold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        key: ValueKey('history-module-header-${c.id}'),
                        children: [
                          Icon(
                            facts.group(c.items) == StepFact.completed
                                ? Icons.check_circle_outline
                                : facts.group(c.items) == StepFact.interrupted
                                ? Icons.error_outline
                                : Icons.layers_outlined,
                            color: _color(facts.group(c.items)),
                            size: 19,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final s in c.items) _step(s, facts),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
  Widget _step(SessionStep s, HistoryFacts facts) {
    final fact = facts.step(s), color = _color(facts.step(s));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.delayBeforeSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(left: 27, top: 3),
            child: Text(
              'Пауза перед: ${formatPause(s.delayBeforeSeconds)}',
              style: const TextStyle(fontSize: 11, color: antiqueGold),
            ),
          ),
        Padding(
          key: ValueKey('history-step-${s.id}'),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.kind == StepKind.silence)
                SizedBox(
                  width: 25,
                  height: 25,
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned(
                          left: -27,
                          top: -53,
                          width: 80,
                          height: 142.22,
                          child: Image.asset(
                            'assets/pause/approved.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Icon(_icon(fact), size: 21, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: TextStyle(color: color, fontSize: 13)),
                    Text(
                      _label(fact),
                      style: TextStyle(color: color, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                s.durationMs == null
                    ? 'До остановки'
                    : formatDuration(s.durationMs!),
                style: TextStyle(color: color, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
