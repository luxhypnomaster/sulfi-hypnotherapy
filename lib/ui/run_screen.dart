import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session_plan.dart';
import '../models/audio_asset.dart';
import '../models/session_timeline.dart';
import '../models/local_dates.dart';
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
  String? _lastItem;
  double? _scrubMs;
  bool _allowPop = false, _ending = false;
  @override
  void dispose() {
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
          title: const Text('Завершить сессию?'),
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
              child: const Text('Прервать сейчас'),
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
    }
  }

  void _close() {
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _details() => showDialog<void>(
    context: context,
    builder: (ctx) {
      final entry = e.currentEntry;
      return AlertDialog(
        title: const Text('Сессия'),
        content: SingleChildScrollView(
          child: Text(
            '№${e.run!.displayNumber} · ${e.run!.status.label}\n'
            'Шаблон: ${e.run!.snapshot.baseTemplateName ?? 'Без шаблона'}\n'
            'Фаза: ${entry?.phase.title ?? '—'}\n'
            'Модуль: ${entry?.moduleId == null ? 'Отдельный элемент' : entry!.child.title}\n'
            'Элемент: ${e.step?.title ?? '—'}\n'
            '${e.step?.kind == StepKind.freeWork && e.step?.durationMs == null ? 'Длительность не задана: работа завершается вручную.\n' : ''}'
            'План при старте: ${formatDuration(e.run!.snapshot.plan.totalMs)}\n'
            'Выполнено: ${e.run!.completedStepIds.length} · пропущено: ${e.run!.skippedStepIds.length}',
          ),
        ),
        actions: [
          if (e.active &&
              e.run!.phase == 'work' &&
              e.step?.kind == StepKind.freeWork) ...[
            TextButton(
              onPressed: e.step?.durationMs == null
                  ? null
                  : () async {
                      await showActionError(context, e.extend);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('+5 минут'),
            ),
            TextButton(
              onPressed: () async {
                await showActionError(context, e.finishWork);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Завершить работу'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
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
                                  flex: landscape ? 5 : 5,
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
                                      if (!landscape) Expanded(child: _watch()),
                                      if (!landscape && body.maxHeight >= 380)
                                        _info(compact: compact),
                                      if (!landscape) const SizedBox(height: 6),
                                      _navigation(
                                        compact:
                                            box.maxWidth < 390 ||
                                            MediaQuery.textScalerOf(context)
                                                    .scale(1) >
                                                1.3,
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 52,
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
                                                ? 'Завершить сессию'
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
    final date = Text(
      historicalDateLabel(
        run.startedAt,
        run.startedUtcOffsetMinutes,
        legacyLabel: run.name,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: antiqueGold),
    );
    final slogan = Text(
      'Время трансформации',
      maxLines: landscape || compact ? 1 : null,
      style: TextStyle(
        color: neonPink,
        fontSize: landscape ? 14 : 20,
        fontWeight: FontWeight.w800,
      ),
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, slogan, date],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _totals(f)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        if (compact)
          SizedBox(
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: slogan,
            ),
          )
        else
          slogan,
        date,
        _totals(f),
      ],
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
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: f.progress ?? 0,
                minHeight: 5,
                color: neonPink,
                backgroundColor: const Color(0xff42112d),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              f.progress == null ? '≈' : '${(f.progress! * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );

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
        excludeSemantics: true,
        child: Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          decoration: BoxDecoration(
            color: active ? const Color(0xff4a002c) : Colors.transparent,
            border: isPhase
                ? Border(bottom: BorderSide(color: color.withValues(alpha: .4)))
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
                size: 14,
                color: color,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  title,
                  maxLines: isPhase ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isPhase ? 13 : 12,
                    color: color,
                    fontWeight: isPhase ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 32,
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
        Positioned.fill(
          left: 30,
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
                    active: e.active && current?.phase.id == phase.id,
                  ),
                  for (final child in phase.children.where(
                    (c) =>
                        c.enabled &&
                        timeline.entries.any((x) => x.child.id == c.id),
                  )) ...[
                    if (child.isModule)
                      row(
                        'Модуль: ${child.title}',
                        timeline.entries
                            .where((x) => x.child.id == child.id)
                            .toList(),
                        isPhase: false,
                      ),
                    if (e.active && current?.phase.id == phase.id)
                      for (final entry in timeline.entries.where(
                        (x) => x.child.id == child.id,
                      ))
                        row(
                          '${entry.step.kind == StepKind.audio ? '' : '${entry.step.kind.label}: '}${entry.step.title}',
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
      ],
    );
  }

  Widget _watch() => LayoutBuilder(
    builder: (context, box) {
      final step = e.step;
      final type = e.run!.phase == 'delay'
          ? 'Пауза перед элементом'
          : step?.kind.label ?? '';
      final label = !e.active
          ? e.run!.status.label
          : e.run!.phase == 'delay'
          ? type
          : step?.title ?? type;
      final duration = e.phaseDurationMs;
      final position = e.phasePositionMs.clamp(0, duration ?? 0x7fffffff);
      final compact =
          box.maxHeight < 250 ||
          box.maxWidth < 184 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final title = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: antiqueGold),
      );
      final time = Text(
        '${formatDuration(position)} / ${duration == null ? '≈' : formatDuration(duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
      final play = SizedBox(
        width: 48,
        height: 48,
        child: IconButton.filled(
          key: const Key('watch-play-pause'),
          tooltip: e.paused ? 'Продолжить сессию' : 'Пауза сессии',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xff3a0026),
            foregroundColor: neonPink,
            side: const BorderSide(color: neonPink),
          ),
          icon: Icon(e.paused ? Icons.play_arrow : Icons.pause, size: 28),
          onPressed: e.busy
              ? null
              : () => showActionError(context, e.paused ? e.resume : e.pause),
        ),
      );
      final seek = SizedBox(
        height: 44,
        child: e.canSeek
            ? Slider(
                key: const Key('track-seek'),
                min: 0,
                max: duration!.toDouble(),
                value: (_scrubMs ?? position.toDouble()).clamp(
                  0,
                  duration.toDouble(),
                ),
                semanticFormatterCallback: (v) => formatDuration(v.round()),
                onChanged: e.busy ? null : (v) => setState(() => _scrubMs = v),
                onChangeEnd: (v) async {
                  await showActionError(
                    context,
                    () => e.seek(Duration(milliseconds: v.round())),
                  );
                  if (mounted) setState(() => _scrubMs = null);
                },
              )
            : Center(
                child: Text(
                  '$type · без перемотки',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
      );
      if (compact) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (e.active)
              Row(
                children: [
                  play,
                  const SizedBox(width: 4),
                  Expanded(child: Column(children: [title, time])),
                ],
              )
            else
              title,
            if (e.active) seek,
          ],
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: 470 / 595,
          child: LayoutBuilder(
            builder: (context, inner) => Stack(
              children: [
                const Positioned.fill(child: PlayerArt(flask: false)),
                Positioned.fill(
                  left: inner.maxWidth * .15,
                  right: inner.maxWidth * .17,
                  top: inner.maxHeight * .43,
                  bottom: inner.maxHeight * .02,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      title,
                      if (e.active) ...[time, play, seek],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _info({required bool compact}) {
    final entry = e.currentEntry;
    final fields = [
      if (!compact)
        'Шаблон: ${e.run!.snapshot.baseTemplateName ?? 'Без шаблона'}',
      'Фаза: ${entry?.phase.title ?? '—'}',
      'Модуль: ${entry?.moduleId == null ? 'Отдельный элемент' : entry!.child.title}',
      if (!compact) 'Трек: ${e.step?.title ?? '—'}',
    ];
    return Container(
      key: const Key('player-context'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff1c0012),
        border: Border.all(color: neonPink),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in fields)
            Text(
              s,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _navigation({required bool compact}) => Column(
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
                        height: 48,
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
                                child: Text(
                                  compact
                                      ? '${forward ? '→' : '←'} $noun'
                                      : '$prefix\n$noun',
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
