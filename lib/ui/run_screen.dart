import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/session_plan.dart';
import '../models/audio_asset.dart';
import '../models/session_timeline.dart';
import '../services/session_engine.dart';
import 'design.dart';
import 'player_art.dart';
import 'session_actions.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.engine});
  final SessionEngine engine;
  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  SessionEngine get e => widget.engine;
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};
  final Map<String, bool> _expanded = {};
  final Set<String> _completedGroups = {};
  String? _expandedForStep;
  void _syncExpansion() {
    final done = e.run!.completedStepIds.toSet();
    final timeline = e.timeline;
    for (final phase in timeline.phases) {
      for (final id in [
        phase.id,
        ...phase.children.where((c) => c.isModule).map((c) => c.id),
      ]) {
        final entries = timeline.entries
            .where((x) => x.phase.id == id || x.child.id == id)
            .toList();
        final completed =
            entries.isNotEmpty &&
            entries.every((x) => done.contains(x.step.id));
        if (completed && _completedGroups.add(id)) _expanded[id] = false;
        if (!completed) _completedGroups.remove(id);
      }
    }
    if (_expandedForStep != e.step?.id) {
      _expandedForStep = e.step?.id;
      final current = e.currentEntry;
      if (current != null && e.active) {
        _expanded[current.phase.id] = true;
        _expanded[current.child.id] = true;
      }
    }
  }

  Timer? _dateTimer;
  String? _lastItem;
  double? _scrubMs;
  bool _historyQueued = false;
  @override
  void initState() {
    super.initState();
    e.addListener(_checkEnd);
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _checkEnd() {
    if (e.active ||
        _historyQueued ||
        _ending ||
        !mounted ||
        !Navigator.canPop(context) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _historyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await e.flush();
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context, e.run!.id);
    });
  }

  bool _allowPop = false, _ending = false;
  @override
  void dispose() {
    e.removeListener(_checkEnd);
    _dateTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_ending || !mounted) return;
    if (!e.active) {
      _close();
      return;
    }
    _ending = true;
    try {
      final exit = await e.hasAvailableExit();
      if (!mounted) return;
      final route = DialogRoute<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Закончить сеанс?'),
          content: Text(
            exit
                ? 'Можно перейти к выходу или остановить сессию сейчас. Фактические события останутся в истории.'
                : 'Доступный выходной трек не настроен. Можно остановиться сейчас. Почувствуйте опору и спокойно осмотритесь.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            if (exit && !e.exiting)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'exit'),
                child: const Text('Перейти к выходу'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'stop'),
              child: const Text('Закончить сейчас'),
            ),
          ],
        ),
      );
      final action = await Navigator.of(context).push(route);
      await route.completed;
      if (!mounted || action == null) return;
      await showActionError(context, action == 'exit' ? e.exit : e.interrupt);
    } finally {
      _ending = false;
      _checkEnd();
    }
  }

  void _close() {
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _details() async {
    final entry = e.currentEntry;
    final route = DialogRoute<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сессия'),
        content: SingleChildScrollView(
          child: Text(
            '№${e.run!.displayNumber} · ${e.run!.status.label}\nШаблон: ${e.run!.snapshot.baseTemplateName ?? 'Без шаблона'}\nФаза: ${entry?.phase.title ?? '—'}\nМодуль: ${entry?.moduleId == null ? 'Отдельный элемент' : entry!.child.title}\nЭлемент: ${e.step?.title ?? '—'}\n${e.step?.durationMs == null ? 'Длительность не задана: пауза завершается вручную.\n' : ''}План при старте: ${formatDuration(e.run!.snapshot.plan.totalMs)}\nВыполнено: ${e.run!.completedStepIds.length} · пропущено: ${e.run!.skippedStepIds.length}',
          ),
        ),
        actions: [
          if (e.canFinishPause) ...[
            if (e.step?.kind == StepKind.freeWork)
              TextButton(
                onPressed: e.step?.durationMs == null
                    ? null
                    : () => Navigator.pop(ctx, 'extend'),
                child: const Text('+5 минут'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'finish'),
              child: const Text('Завершить паузу'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    final action = await Navigator.of(context).push(route);
    await route.completed;
    _checkEnd();
    if (!mounted || action == null) return;
    await showActionError(
      context,
      action == 'extend' ? e.extend : e.finishWork,
    );
  }

  void _scrollToCurrent() {
    final id = e.step?.id;
    if (_lastItem == id) return;
    _lastItem = id;
    _scrubMs = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _rowKeys[id]?.currentContext;
      if (!mounted || target == null) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: .45,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (p, _) {
      if (!p) unawaited(_finish());
    },
    child: ListenableBuilder(
      listenable: e,
      builder: (context, _) {
        _syncExpansion();
        _scrollToCurrent();
        final run = e.run!, f = e.forecast;
        final title = run.snapshot.topicText.trim().isNotEmpty
            ? run.snapshot.topicText
            : run.snapshot.baseTemplateName ?? 'Сессия самогипноза';
        return Scaffold(
          backgroundColor: const Color(0xff050004),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final landscape = box.maxWidth > box.maxHeight * 1.3;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(
                        run,
                        f,
                        title,
                        landscape: landscape,
                        compact:
                            box.maxHeight < 660 &&
                            MediaQuery.textScalerOf(context).scale(1) > 1.3,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, body) {
                            final compact = body.maxHeight < 490;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: landscape ? 5 : 7,
                                  child: _scale(),
                                ),
                                const SizedBox(width: 5),
                                if (landscape) ...[
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        Expanded(child: _watch()),
                                        _info(compact: true),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Expanded(
                                  flex: landscape ? 5 : 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _date(),
                                      const SizedBox(height: 3),
                                      _totals(f),
                                      const SizedBox(height: 4),
                                      if (!landscape) Flexible(child: _watch()),
                                      if (!landscape) _info(compact: compact),
                                      if (!landscape) const SizedBox(height: 6),
                                      _navigation(
                                        height: landscape ? 30 : 48,
                                        compact:
                                            box.maxWidth < 390 ||
                                            MediaQuery.textScalerOf(context)
                                                    .scale(1) >
                                                1.3,
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: landscape ? 44 : 52,
                                        child: FilledButton.icon(
                                          key: const Key('finish-session'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: neonLime,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          onPressed: e.busy
                                              ? null
                                              : (e.active ? _finish : _close),
                                          icon: Icon(
                                            e.active
                                                ? Icons.stop
                                                : Icons.home_outlined,
                                            size: 20,
                                          ),
                                          label: Text(
                                            e.active
                                                ? 'Закончить сеанс'
                                                : 'На главную',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (e.error != null)
                        Text(
                          e.error!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _header(
    SessionRun run,
    SessionForecast f,
    String title, {
    required bool landscape,
    required bool compact,
  }) {
    final heading = Row(
      children: [
        Expanded(
          child: Text(
            'Сессия №${run.displayNumber} · $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Подробности сессии',
          onPressed: _details,
          icon: const Icon(Icons.info_outline, color: neonPink),
        ),
      ],
    );
    return heading;
  }

  Widget _date() {
    final now = DateTime.now();
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    String two(int n) => n.toString().padLeft(2, '0');
    return Text(
      '${days[now.weekday - 1]}, ${two(now.day)}.${two(now.month)}.${now.year} · ${two(now.hour)}:${two(now.minute)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 10, color: antiqueGold),
    );
  }

  Widget _totals(SessionForecast f) => Container(
    key: const Key('session-totals'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: neonPink.withValues(alpha: .7)),
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        colors: [Color(0xff230019), Color(0xff090005)],
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            for (final pair in [
              ('Прошло', f.elapsedMs),
              ('Осталось', f.remainingMs),
              ('Всего', f.totalMs),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(
                      pair.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pair.$2 == null ? '≈ —' : formatDuration(pair.$2!),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 17,
                          color: antiqueGold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );

  String _duration(List<TimelineEntry> entries) {
    if (entries.isEmpty) return '—';
    if (entries.any((x) => x.step.durationMs == null)) return '≈ —';
    return formatDuration(
      entries.fold<int>(0, (sum, x) => sum + x.step.estimatedMs),
    );
  }

  Widget _scale() {
    final timeline = e.timeline, current = e.currentEntry;
    final done = e.run!.completedStepIds.toSet(),
        skipped = e.run!.skippedStepIds.toSet();
    Widget row(
      String title,
      List<TimelineEntry> entries, {
      required bool isPhase,
      bool active = false,
      Key? key,
      VoidCallback? onTap,
    }) {
      final completed =
          entries.isNotEmpty && entries.every((x) => done.contains(x.step.id));
      final omit =
          entries.isNotEmpty &&
          entries.every((x) => skipped.contains(x.step.id));
      final partial = entries.any(
        (x) => done.contains(x.step.id) || skipped.contains(x.step.id),
      );
      final label = active
          ? (e.paused ? 'Пауза' : 'Сейчас')
          : completed
          ? 'Выполнено'
          : omit
          ? 'Пропущено'
          : partial
          ? 'Частично'
          : 'Впереди';
      final color = active
          ? neonPink
          : completed
          ? const Color(0xffa6ed49)
          : antiqueGold;
      return Semantics(
        label: '$title. $label',
        button: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            key: key,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
            decoration: BoxDecoration(
              color: active ? const Color(0xff4a002c) : Colors.transparent,
              border: isPhase
                  ? Border(
                      bottom: BorderSide(color: color.withValues(alpha: .4)),
                    )
                  : null,
              borderRadius: isPhase ? null : BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  active
                      ? Icons.play_circle
                      : completed
                      ? Icons.check_circle
                      : omit
                      ? Icons.skip_next
                      : Icons.circle_outlined,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isPhase ? 10 : 9,
                      height: 1.15,
                      color: color,
                      fontWeight: isPhase ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  _duration(entries),
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final flaskWidth = (box.maxHeight * 190 / 1517).clamp(32.0, 44.0);
        return Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: flaskWidth,
              child: Semantics(
                label: e.forecast.liquidFraction == null
                    ? 'Уровень: время уточняется'
                    : 'Остаток раствора ${(e.forecast.liquidFraction! * 100).round()} процентов',
                child: PlayerArt(
                  flask: true,
                  liquid: e.forecast.liquidFraction ?? 1,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: flaskWidth * .015,
              width: flaskWidth * .86,
              height: box.maxHeight * 145 / 1517 + 4,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/player/snake_front.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned.fill(
              left: flaskWidth * .98,
              child: SingleChildScrollView(
                controller: _scroll,
                key: const Key('phase-scale'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final phase in timeline.phases) ...[
                      row(
                        'Фаза ${timeline.phases.indexOf(phase) + 1}. ${phase.title}',
                        timeline.entries
                            .where((x) => x.phase.id == phase.id)
                            .toList(),
                        isPhase: true,
                        key: ValueKey('player-phase-${phase.id}'),
                        onTap: () => setState(
                          () => _expanded[phase.id] =
                              !(_expanded[phase.id] ?? true),
                        ),
                        active: e.active && current?.phase.id == phase.id,
                      ),
                      if (_expanded[phase.id] ?? true)
                        for (final child in phase.children.where(
                          (c) =>
                              c.enabled &&
                              timeline.entries.any((x) => x.child.id == c.id),
                        )) ...[
                          if (child.isModule)
                            row(
                              child.title,
                              timeline.entries
                                  .where((x) => x.child.id == child.id)
                                  .toList(),
                              isPhase: false,
                              key: ValueKey('player-module-${child.id}'),
                              onTap: () => setState(
                                () => _expanded[child.id] =
                                    !(_expanded[child.id] ?? true),
                              ),
                            ),
                          if (!child.isModule || (_expanded[child.id] ?? true))
                            for (final entry in timeline.entries.where(
                              (x) => x.child.id == child.id,
                            ))
                              row(
                                entry.step.kind == StepKind.audio
                                    ? entry.step.title
                                    : 'Пауза',
                                [entry],
                                isPhase: false,
                                key: _rowKeys.putIfAbsent(
                                  entry.step.id,
                                  GlobalKey.new,
                                ),
                                active: current?.step.id == entry.step.id,
                              ),
                        ],
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: flaskWidth * .13,
              bottom: box.maxHeight * .025,
              width: flaskWidth * .67,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  e.forecast.progress == null
                      ? '≈'
                      : '${(e.forecast.progress! * 100).round()}%',
                  key: const Key('flask-percent'),
                  style: const TextStyle(
                    color: antiqueGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 3,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _watch() => LayoutBuilder(
    builder: (context, box) {
      if (!e.active) {
        return Center(
          child: Text(
            e.run!.status.label,
            style: const TextStyle(color: antiqueGold),
          ),
        );
      }
      final duration = e.phaseDurationMs;
      final position = (_scrubMs ?? e.phasePositionMs.toDouble()).clamp(
        0.0,
        (duration ?? 0x7fffffff).toDouble(),
      );
      final fraction = duration == null || duration == 0
          ? 0.0
          : position / duration;
      final width = math.min(
        box.maxWidth,
        math.max(144.0, box.maxHeight * 470 / 595),
      );
      final height = math.min(box.maxHeight, width * 595 / 470);
      final buttonSize = 48.0;
      Future<void> commit() async {
        final value = _scrubMs;
        if (value == null || !e.canSeek || e.busy) return;
        await showActionError(
          context,
          () => e.seek(Duration(milliseconds: value.round())),
        );
        if (mounted) setState(() => _scrubMs = null);
      }

      bool update(Offset point) {
        if (!e.canSeek || e.busy || duration == null) return false;
        final delta = point - Offset(width * 221.5 / 470, height * 318.5 / 595);
        final radius = width * 164 / 470;
        if (delta.distance < radius * .73 || delta.distance > radius * 1.2) {
          return false;
        }
        final angle =
            (math.atan2(delta.dy, delta.dx) + math.pi / 2) % (math.pi * 2);
        setState(() => _scrubMs = angle / (math.pi * 2) * duration);
        return true;
      }

      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(child: PlayerArt(flask: false)),
              Positioned.fill(
                child: Semantics(
                  label: 'Круговая перемотка трека',
                  value: formatDuration(position.round()),
                  increasedValue: formatDuration(
                    math.min(duration ?? 0, position.round() + 5000),
                  ),
                  decreasedValue: formatDuration(
                    math.max(0, position.round() - 5000),
                  ),
                  onIncrease: e.canSeek
                      ? () => e.seek(
                          Duration(milliseconds: (position + 5000).round()),
                        )
                      : null,
                  onDecrease: e.canSeek
                      ? () => e.seek(
                          Duration(
                            milliseconds: math.max(0, position - 5000).round(),
                          ),
                        )
                      : null,
                  child: GestureDetector(
                    key: e.canSeek
                        ? const Key('track-seek')
                        : const Key('interval-ring'),
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) {
                      if (update(d.localPosition)) unawaited(commit());
                    },
                    onPanStart: (d) => update(d.localPosition),
                    onPanUpdate: (d) => update(d.localPosition),
                    onPanEnd: (_) => unawaited(commit()),
                    child: CustomPaint(
                      painter: WatchProgress(fraction, e.canSeek),
                    ),
                  ),
                ),
              ),
              if (height >= 100)
                Positioned(
                  left: width * .12,
                  right: width * .17,
                  top: math.max(height * .72, height * .48 + buttonSize),
                  key: const Key('watch-time'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatDuration(position.round())} / ${duration == null ? '≈' : formatDuration(duration)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: width * .1,
                right: width * .16,
                top: (height * .48).clamp(
                  0.0,
                  math.max(0.0, height - buttonSize),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: IconButton.filled(
                        key: const Key('watch-play-pause'),
                        tooltip: e.paused
                            ? 'Продолжить сессию'
                            : 'Пауза сессии',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF3A0026),
                          foregroundColor: neonPink,
                          side: const BorderSide(color: neonPink),
                        ),
                        onPressed: !e.active || e.busy
                            ? null
                            : () => showActionError(
                                context,
                                e.paused ? e.resume : e.pause,
                              ),
                        icon: Icon(
                          e.paused ? Icons.play_arrow : Icons.pause,
                          size: buttonSize * .55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _info({required bool compact}) {
    final entry = e.currentEntry;
    final entries = e.timeline.entries;
    final fields = [
      (
        'Шаблон: ${e.run!.snapshot.baseTemplateName ?? 'Без шаблона'}',
        _duration(entries),
      ),
      (
        'Фаза: ${entry?.phase.title ?? '—'}',
        _duration(entries.where((x) => x.phase.id == entry?.phase.id).toList()),
      ),
      (
        'Модуль: ${entry?.moduleId == null ? 'Отдельный элемент' : entry!.child.title}',
        _duration(entries.where((x) => x.child.id == entry?.child.id).toList()),
      ),
      (
        'Трек: ${e.step?.kind == StepKind.audio ? e.step?.title ?? '—' : 'Пауза'}',
        _duration(entry == null ? [] : [entry]),
      ),
    ];
    return Container(
      key: const Key('player-context'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff1c0012),
        border: Border.all(color: neonPink),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: compact ? 86 : 112,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          field.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        field.$2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: antiqueGold,
                        ),
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

  Widget _navigation({required bool compact, double height = 48}) => Column(
    key: const Key('player-navigation'),
    children: [
      for (final unit in NavigationUnit.values)
        Padding(
          padding: EdgeInsets.only(
            bottom: unit == NavigationUnit.phase ? 0 : 5,
          ),
          child: Row(
            children: [
              for (final forward in [false, true]) ...[
                if (forward) const SizedBox(width: 5),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final noun = switch (unit) {
                        NavigationUnit.track => 'трек',
                        NavigationUnit.module => 'модуль',
                        NavigationUnit.phase => 'фаза',
                      };
                      final prefix = unit == NavigationUnit.phase
                          ? (forward ? 'Следующая' : 'Предыдущая')
                          : (forward ? 'Следующий' : 'Предыдущий');
                      final label = '$prefix $noun';
                      final target = e.navigationTarget(unit, forward);
                      final between =
                          target == null || unit != NavigationUnit.track
                          ? 0
                          : e.timeline.entries
                                .where(
                                  (entry) =>
                                      entry.step.kind != StepKind.audio &&
                                      (forward
                                          ? entry.index >= e.run!.stepIndex &&
                                                entry.index < target
                                          : entry.index > target &&
                                                entry.index <=
                                                    e.run!.stepIndex),
                                )
                                .length;
                      final hint = between == 0
                          ? label
                          : '$label. Между позициями $between интервалов; переход будет отмечен в истории.';
                      return SizedBox(
                        height: height,
                        child: Tooltip(
                          message: hint,
                          child: OutlinedButton(
                            key: ValueKey(
                              'nav-${unit.name}-${forward ? 'next' : 'previous'}',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              foregroundColor: neonPink,
                              backgroundColor: const Color(0xff200016),
                              disabledForegroundColor: const Color(0xff66555f),
                              side: BorderSide(
                                color: e.navigationTarget(unit, forward) == null
                                    ? const Color(0xff49313e)
                                    : neonPink,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                e.busy ||
                                    e.navigationTarget(unit, forward) == null
                                ? null
                                : () => showActionError(
                                    context,
                                    () => e.navigate(unit, forward),
                                  ),
                            child: Semantics(
                              label: hint,
                              button: true,
                              child: ExcludeSemantics(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$prefix\n$noun',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

class WatchProgress extends CustomPainter {
  WatchProgress(this.fraction, this.seekable);
  final double fraction;
  final bool seekable;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 221.5 / 470, size.height * 318.5 / 595);
    final radius = size.width * 164 / 470;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = neonPink.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      Paint()
        ..color = seekable ? neonPink : antiqueGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final angle = fraction * math.pi * 2 - math.pi / 2;
    canvas.drawCircle(
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
      4,
      Paint()..color = neonPink,
    );
  }

  @override
  bool shouldRepaint(WatchProgress old) =>
      fraction != old.fraction || seekable != old.seekable;
}
