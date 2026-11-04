import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../services/pause_edit_model.dart';
import '../services/preview_player.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'preview_bar.dart';
import 'pause_clock_art.dart';
export 'mechanical_wheel.dart' show MechanicalWheel;

class PauseEditor extends StatefulWidget {
  const PauseEditor({
    super.key,
    required this.controller,
    required this.stepId,
    required this.player,
  });
  final SessionController controller;
  final String stepId;
  final PreviewPlayer player;
  @override
  State<PauseEditor> createState() => _PauseEditorState();
}

class _PauseEditorState extends State<PauseEditor> {
  late final _original = widget.controller.draft.plan.allSteps.firstWhere(
    (s) => s.id == widget.stepId,
  );
  late final _model = PauseEditModel(_original.delayBeforeSeconds);
  bool _saving = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(widget.player.stop));
  }

  @override
  void dispose() {
    _model.dispose();
    unawaited(Future.microtask(widget.player.stop));
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving) return;
    if (_model.totalSeconds != _original.delayBeforeSeconds &&
        !await confirmAction(
          context,
          'Закрыть без применения?',
          'Изменённая пауза не будет сохранена.',
          confirm: 'Не сохранять',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await widget.controller.setDelay(widget.stepId, _model.totalSeconds);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить паузу. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manual() async {
    final result = await showDialog<({int minutes, int seconds})>(
      context: context,
      builder: (_) =>
          _TimeInput(minutes: _model.minutes, seconds: _model.seconds),
    );
    if (result != null) _model.manual(result.minutes, result.seconds);
  }

  SessionStep? _neighbor(bool previous) {
    final steps = widget.controller.draft.plan.allSteps;
    final effective = widget.controller.draft.plan.steps
        .map((s) => s.id)
        .toSet();
    final index = steps.indexWhere((s) => s.id == widget.stepId);
    if (previous) {
      for (var i = index - 1; i >= 0; i--) {
        if (steps[i].kind == StepKind.audio &&
            effective.contains(steps[i].id)) {
          return steps[i];
        }
      }
    } else {
      for (var i = index; i < steps.length; i++) {
        if (steps[i].kind == StepKind.audio &&
            effective.contains(steps[i].id)) {
          return steps[i];
        }
      }
    }
    return null;
  }

  Future<void> _preview(SessionStep step) async {
    try {
      final a = widget.controller.asset(step.audioAssetId);
      if (a == null) throw const FormatException();
      await widget.player.toggle(a, widget.controller.library.fileFor(a));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аудиофайл недоступен. Замените его в структуре.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: _model,
              builder: (context, _) {
                final c = widget.controller;
                final plan = c.draft.plan;
                final delta = plan.steps.any((s) => s.id == widget.stepId)
                    ? (_model.totalSeconds - _original.delayBeforeSeconds) *
                          1000
                    : 0;
                final groupMs =
                    plan.steps
                        .where((s) => s.groupId == _original.groupId)
                        .fold(0, (n, s) => n + s.estimatedMs) +
                    delta;
                final previous = _neighbor(true), next = _neighbor(false);
                final contextPanel = NeonPanel(
                  color: antiqueGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Шаблон: ${c.baseTemplate?.name ?? c.draft.baseTemplateName ?? 'Не выбран'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: neonLime),
                      ),
                      Text(
                        'Фаза: ${plan.groupName(_original.groupId)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: neonPink),
                      ),
                      Text(
                        'Перед треком ${plan.allSteps.indexWhere((s) => s.id == widget.stepId) + 1}: ${c.asset(_original.audioAssetId)?.title ?? _original.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
                final totals = NeonPanel(
                  glow: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _stat(
                          'Трек',
                          _original.durationMs == null
                              ? 'Без срока'
                              : formatDuration(_original.durationMs!),
                        ),
                      ),
                      Expanded(child: _stat('Фаза', formatDuration(groupMs))),
                      Expanded(
                        child: _stat(
                          plan.estimated ? '≈ Всего' : 'Всего',
                          formatDuration(plan.totalMs + delta),
                          color: neonLime,
                        ),
                      ),
                    ],
                  ),
                );
                final difference =
                    'Изменение: ${delta < 0 ? '−' : '+'}${formatDuration(delta.abs())}';
                void details() => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Пауза перед треком'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Шаблон: ${c.baseTemplate?.name ?? c.draft.baseTemplateName ?? 'Не выбран'}',
                          ),
                          Text('Фаза: ${plan.groupName(_original.groupId)}'),
                          Text(
                            'Модуль: ${plan.phases?.expand((p) => p.children).where((c) => c.items.any((s) => s.id == widget.stepId)).firstOrNull?.title ?? 'Отдельный трек'}',
                          ),
                          Text(
                            'Перед треком: ${c.asset(_original.audioAssetId)?.title ?? _original.title}',
                          ),
                          Text(
                            'Длительность трека: ${_original.durationMs == null ? 'до остановки' : formatDuration(_original.durationMs!)}',
                          ),
                          Text(
                            'Длительность раздела: ${formatDuration(groupMs)}',
                          ),
                          Text(
                            'Длительность сессии: ${formatDuration(plan.totalMs + delta)}',
                          ),
                          Text(difference),
                          const SizedBox(height: 8),
                          const Text(
                            'Левое колесо: минуты. Правое: секунды с шагом 5. Двигайте палец вверх или вниз. Значение сохранится после «Применить».',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Понятно'),
                      ),
                    ],
                  ),
                );
                return LayoutBuilder(
                  builder: (context, page) {
                    final compact =
                        page.maxHeight < 740 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Закрыть редактор паузы',
                                onPressed: _close,
                                icon: const Icon(Icons.close),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Настройка паузы',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Ввести минуты и секунды',
                                onPressed: _saving ? null : _manual,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: antiqueGold,
                                ),
                              ),
                            ],
                          ),
                          if (compact)
                            InkWell(
                              onTap: details,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Пауза перед: ${c.asset(_original.audioAssetId)?.title ?? _original.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Вся сессия: ${formatDuration(plan.totalMs + delta)} · $difference',
                                          key: const Key('pause-delta'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: neonLime,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    height: 48,
                                    width: 32,
                                    child: Icon(
                                      Icons.info_outline,
                                      color: antiqueGold,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, box) {
                                      final w = math.min(
                                        box.maxWidth,
                                        box.maxHeight / 1.305,
                                      );
                                      return Center(
                                        child: SizedBox(
                                          width: w,
                                          height: w * 1.305,
                                          child: ApprovedPauseClock(
                                            minutes: _model.minutes,
                                            seconds: _model.seconds,
                                            secondStep: 5,
                                            onMinutes: _model.turnMinutes,
                                            onSeconds: _model.turnSeconds,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: 48,
                                  child: TextButton(
                                    key: const Key('pause-time-input'),
                                    onPressed: _saving ? null : _manual,
                                    child: Text(
                                      _model.label,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        color: Color(0xFFFFE8A0),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!compact) totals,
                              ],
                            ),
                          ),
                          if (!compact) contextPanel,
                          if (!compact)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    difference,
                                    key: const Key('pause-delta'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: neonLime,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Сведения о паузе',
                                  onPressed: details,
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: antiqueGold,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          _buttons(
                            previous,
                            next,
                            twoRows:
                                MediaQuery.textScalerOf(context).scale(1) >
                                    1.3 ||
                                page.maxWidth < 350,
                          ),
                          const SizedBox(height: 6),
                          PreviewBar(
                            player: widget.player,
                            library: c.library,
                            idleAsset: c.asset(next?.audioAssetId),
                            compact: true,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buttons(
    SessionStep? previous,
    SessionStep? next, {
    required bool twoRows,
  }) {
    Widget clear() => NeonButton(
      label: 'Обнулить',
      icon: Icons.restart_alt,
      onPressed: _saving ? null : _model.reset,
      compact: true,
      stacked: !twoRows,
      fitLabel: twoRows,
    );
    Widget apply() => NeonButton(
      label: _saving ? 'Сохранение…' : 'Применить',
      icon: Icons.check,
      onPressed: _saving ? null : _apply,
      primary: true,
      compact: true,
      stacked: !twoRows,
      fitLabel: twoRows,
    );
    Widget neighbor(SessionStep? step, bool before) => Tooltip(
      message: step == null
          ? (before ? 'Предыдущего аудио нет' : 'Следующего аудио нет')
          : 'Прослушать ${before ? 'предыдущий' : 'следующий'} трек: ${step.title}',
      child: NeonButton(
        label: before ? 'До паузы' : 'После паузы',
        icon: before ? Icons.skip_previous : Icons.skip_next,
        onPressed: step == null ? null : () => _preview(step),
        compact: true,
        stacked: !twoRows,
        fitLabel: twoRows,
      ),
    );
    Widget row(List<Widget> children) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
    return twoRows
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row([clear(), apply()]),
              const SizedBox(height: 5),
              row([neighbor(previous, true), neighbor(next, false)]),
            ],
          )
        : row([
            clear(),
            neighbor(previous, true),
            neighbor(next, false),
            apply(),
          ]);
  }

  Widget _stat(
    String label,
    String value, {
    Color color = const Color(0xFFFFE9F5),
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}

class _TimeInput extends StatefulWidget {
  const _TimeInput({required this.minutes, required this.seconds});
  final int minutes, seconds;
  @override
  State<_TimeInput> createState() => _TimeInputState();
}

class _TimeInputState extends State<_TimeInput> {
  late final _minutes = TextEditingController(text: '${widget.minutes}');
  late final _seconds = TextEditingController(text: '${widget.seconds}');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entered = int.tryParse(_seconds.text);
    final normalized = entered == null
        ? null
        : ((entered / 5).round() * 5).clamp(0, 55);
    return AlertDialog(
      title: const Text('Пауза перед треком'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Минуты (0–99)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n > 99 ? 'От 0 до 99 минут' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seconds,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Секунды (0–59)'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n > 59 ? 'От 0 до 59 секунд' : null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Шаг — 5 секунд. ${entered != null && entered != normalized ? 'Будет установлено: $normalized сек.' : 'Минуты не изменяются.'}',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, (
                minutes: int.parse(_minutes.text),
                seconds: int.parse(_seconds.text),
              ));
            }
          },
          child: const Text('Установить'),
        ),
      ],
    );
  }
}
