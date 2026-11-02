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
  late final _original = widget.controller.draft.plan.steps.firstWhere(
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
    final steps = widget.controller.draft.plan.steps;
    final index = steps.indexWhere((s) => s.id == widget.stepId);
    if (previous) {
      for (var i = index - 1; i >= 0; i--) {
        if (steps[i].kind == StepKind.audio) return steps[i];
      }
    } else {
      for (var i = index; i < steps.length; i++) {
        if (steps[i].kind == StepKind.audio) return steps[i];
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Закрыть редактор паузы',
          onPressed: _close,
          icon: const Icon(Icons.close),
        ),
        title: const Text('Настройка паузы'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: _model,
              builder: (context, _) {
                final c = widget.controller;
                final plan = c.draft.plan;
                final delta =
                    (_model.totalSeconds - _original.delayBeforeSeconds) * 1000;
                final groupMs =
                    plan.steps
                        .where((s) => s.groupId == _original.groupId)
                        .fold(0, (n, s) => n + s.estimatedMs) +
                    delta;
                final previous = _neighbor(true), next = _neighbor(false);
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 10, 8, 0),
                      child: Text(
                        'Пауза перед проигрыванием трека.\nПроведите пальцем по боковым колёсикам.',
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return SizedBox(
                          height: width * 1.25,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: Image.asset(
                                    'assets/art/pocket_watch.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: width * .22,
                                top: width * .59,
                                width: width * .56,
                                height: width * .17,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: TextButton(
                                      key: const Key('pause-time-input'),
                                      onPressed: _saving ? null : _manual,
                                      child: Text(
                                        _model.label,
                                        style: const TextStyle(
                                          fontSize: 51,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                          color: Color(0xFFFFE8A0),
                                          shadows: [
                                            Shadow(
                                              color: Color(0xFFFFA600),
                                              blurRadius: 15,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: width * .085,
                                top: width * .355,
                                width: width * .25,
                                height: width * .34,
                                child: MechanicalWheel(
                                  label: 'Минуты',
                                  value: '${_model.minutes}',
                                  onDetent: _model.turnMinutes,
                                ),
                              ),
                              Positioned(
                                right: width * .085,
                                top: width * .355,
                                width: width * .25,
                                height: width * .34,
                                child: MechanicalWheel(
                                  label: 'Секунды',
                                  value: '${_model.seconds}',
                                  onDetent: _model.turnSeconds,
                                ),
                              ),
                              if (textScale <= 1.4)
                                Positioned(
                                  left: width * .28,
                                  top: width * .79,
                                  width: width * .44,
                                  child: const Center(
                                    child: Text(
                                      'минуты : секунды',
                                      style: TextStyle(
                                        color: antiqueGold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: _saving ? null : _manual,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Ввести минуты и секунды'),
                      ),
                    ),
                    NeonPanel(
                      color: antiqueGold,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Шаблон: ${c.baseTemplate?.name ?? c.draft.baseTemplateName ?? 'Текущая конфигурация'}',
                            style: const TextStyle(color: antiqueGold),
                          ),
                          const SizedBox(height: 6),
                          Text('Раздел: ${plan.groupName(_original.groupId)}'),
                          const SizedBox(height: 6),
                          Text(
                            'Перед треком ${plan.steps.indexWhere((s) => s.id == widget.stepId) + 1}: ${c.asset(_original.audioAssetId)?.title ?? _original.title}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Divider(),
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Трек: ${_original.durationMs == null ? 'до остановки' : formatDuration(_original.durationMs!)}',
                              ),
                              Text('Раздел: ${formatDuration(groupMs)}'),
                              Text(
                                '${plan.estimated ? 'Оценка' : 'Всего'}: ${formatDuration(plan.totalMs + delta)}',
                                style: const TextStyle(
                                  color: neonLime,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Изменение: ${delta < 0 ? '−' : '+'}${formatDuration(delta.abs())}',
                            key: const Key('pause-delta'),
                            style: const TextStyle(color: neonLime),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        NeonButton(
                          label: 'Обнулить',
                          icon: Icons.restart_alt,
                          onPressed: _saving ? null : _model.reset,
                          compact: true,
                        ),
                        NeonButton(
                          label: _saving ? 'Сохранение…' : 'Применить',
                          icon: Icons.check,
                          onPressed: _saving ? null : _apply,
                          primary: true,
                          compact: true,
                        ),
                        NeonButton(
                          label: previous == null
                              ? 'Предыдущего аудио нет'
                              : 'Прослушать предыдущий трек',
                          icon: Icons.skip_previous,
                          onPressed: previous == null
                              ? null
                              : () => _preview(previous),
                          compact: true,
                        ),
                        NeonButton(
                          label: next == null
                              ? 'Следующего аудио нет'
                              : 'Прослушать следующий трек',
                          icon: Icons.skip_next,
                          onPressed: next == null ? null : () => _preview(next),
                          compact: true,
                        ),
                      ],
                    ),
                    if (previous != null || next != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'До паузы: ${previous?.title ?? 'нет'}\nПосле паузы: ${next?.title ?? 'нет аудио'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    PreviewBar(player: widget.player, library: c.library),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class MechanicalWheel extends StatefulWidget {
  const MechanicalWheel({
    super.key,
    required this.label,
    required this.value,
    required this.onDetent,
  });
  final String label, value;
  final bool Function(int ticks) onDetent;
  @override
  State<MechanicalWheel> createState() => _MechanicalWheelState();
}

class _MechanicalWheelState extends State<MechanicalWheel> {
  double _movement = 0, _turns = 0;
  void _tick(int direction) {
    if (widget.onDetent(direction)) {
      setState(() => _turns += direction / 24);
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value: widget.value,
    increasedValue:
        '${widget.label == 'Секунды' ? ((int.tryParse(widget.value) ?? 0) + 5) % 60 : ((int.tryParse(widget.value) ?? 0) + 1).clamp(0, 99)}',
    decreasedValue:
        '${widget.label == 'Секунды' ? ((int.tryParse(widget.value) ?? 0) - 5) % 60 : ((int.tryParse(widget.value) ?? 0) - 1).clamp(0, 99)}',
    onIncrease: () => _tick(1),
    onDecrease: () => _tick(-1),
    child: GestureDetector(
      key: Key('wheel-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _movement = 0,
      onPanUpdate: (d) {
        _movement += -d.delta.dy + d.delta.dx * .6;
        while (_movement.abs() >= 14) {
          final direction = _movement > 0 ? 1 : -1;
          _movement -= direction * 14;
          _tick(direction);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedRotation(
              turns: _turns,
              duration: const Duration(milliseconds: 70),
              child: CustomPaint(painter: const _WheelTicks()),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFFFFD979),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WheelTicks extends CustomPainter {
  const _WheelTicks();
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * .42;
    final p = Paint()
      ..color = const Color(0xFFFFD260).withValues(alpha: .4)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * .82,
        c + Offset(math.cos(a), math.sin(a)) * r,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelTicks oldDelegate) => false;
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
