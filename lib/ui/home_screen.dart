import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../services/preview_player.dart';
import '../services/session_controller.dart';
import '../services/session_engine.dart';
import '../services/session_transport.dart';
import 'design.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'pause_editor.dart';
import 'run_screen.dart';
import 'session_actions.dart';
import 'modular_structure_screen.dart';
import '../models/modular_plan.dart';
import '../models/local_dates.dart';
import '../services/session_audio_handler.dart';
import 'booking.dart';
import 'templates_screen.dart';
import 'diary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.player,
    this.transportFactory,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final SessionTransport Function()? transportFactory;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final _topic = TextEditingController(text: c.draft.topicText);
  final _topicFocus = FocusNode();
  bool _busy = false;
  SessionEngine? _engine;
  SessionController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_sync);
  }

  void _sync() {
    if (!_topicFocus.hasFocus && _topic.text != c.draft.topicText) {
      _topic.text = c.draft.topicText;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_sync);
    _topic.dispose();
    _topicFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.player.stop());
      if (sessionAudioHandler == null && (_engine?.active ?? false)) {
        unawaited(_engine!.interrupt().catchError((Object _) {}));
      }
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    _topicFocus.unfocus();
    await showActionError(context, f);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _structure() async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ModularStructureScreen(controller: c, player: widget.player),
      ),
    );
    await c.reload();
  }

  Future<void> _library() => _run(() async {
    await c.flush();
    await widget.player.stop();
    if (!mounted) return;
    final chosen = await Navigator.push<AudioAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          library: c.library,
          controller: c,
          player: widget.player,
          allowSelection: false,
          onReset: () async {
            await c.library.reset();
            await c.reload();
          },
        ),
      ),
    );
    await c.reload();
    if (chosen != null) {
      await c.addAudio(chosen);
      if (mounted) await _structure();
    }
  });
  Future<void> _templates() => _run(() async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatesScreen(controller: c, player: widget.player),
      ),
    );
    await c.reload();
  });
  Future<void> _history() => _run(() async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<SessionRun>(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(controller: c)),
    );
    await c.reload();
    // Repeat only replaces the draft; return to the main screen without autoplay.
  });
  Future<void> _notes() => _run(() async {
    final details = await askDetails(
      context,
      title: 'Тема и заметка',
      name: c.draft.topicText.isEmpty ? 'Моя сессия' : c.draft.topicText,
      description: c.draft.notes,
      nameLabel: 'Тема/запрос',
      descriptionLabel: 'Заметка',
    );
    if (details != null) {
      await c.setText(topic: details.name, notes: details.description);
    }
  });
  Future<void> _start() => _run(() async {
    await widget.player.stop();
    final engine = sessionAudioHandler != null
        ? await sessionAudioHandler!.startSession()
        : SessionEngine(
            controller: c,
            transport:
                widget.transportFactory?.call() ?? JustAudioSessionTransport(),
          );
    _engine = engine;
    try {
      if (sessionAudioHandler == null) await engine.start();
      if (!mounted) return;
      final finishedId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => RunScreen(engine: engine)),
      );
      await c.reload();
      if (finishedId != null && mounted) {
        await Navigator.push<SessionRun>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HistoryScreen(controller: c, selectedRunId: finishedId),
          ),
        );
      }
    } finally {
      if (sessionAudioHandler?.engine != engine) await engine.close();
      _engine = null;
      await c.reload();
    }
  });
  Future<void> _pause(SessionStep step) => _run(() async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PauseEditor(controller: c, stepId: step.id, player: widget.player),
      ),
    );
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final plan = modularize(c.draft.plan);
      final phases = plan.phases!
          .where(
            (p) =>
                p.enabled &&
                p.children.any(
                  (child) => child.enabled && child.items.any((s) => s.enabled),
                ),
          )
          .toList();
      return Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeonButton(
                  label: 'НАЧАТЬ ТРАНСФОРМАЦИЮ',
                  fitLabel: true,
                  icon: Icons.play_circle_filled,
                  onPressed: _busy || plan.steps.isEmpty || c.saving
                      ? null
                      : _start,
                  primary: true,
                  compact: true,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _nav(BookingConfig.label, null, () => showBooking(context)),
                    _nav('Библиотека', Icons.headphones_outlined, _library),
                    _nav('Шаблоны', Icons.layers_outlined, _templates),
                    _nav('История', Icons.history, _history),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (MediaQuery.sizeOf(context).height >= 650 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .16).clamp(
                    95.0,
                    160.0,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: Image.asset(
                            'assets/art/sulfi_header.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 16,
                        top: 15,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'САМОГИПНОЗ',
                              style: TextStyle(fontSize: 10, letterSpacing: 2),
                            ),
                            Text(
                              'Сульфи',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                color: neonPink,
                              ),
                            ),
                            Text(
                              'Ваш внутренний\nнавигатор',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: LeatherBoard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.diary != null)
                        ListenableBuilder(
                          listenable: c.diary!,
                          builder: (context, _) {
                            final latest = c.diary!.published.firstOrNull;
                            return InkWell(
                              key: const Key('home-diary'),
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => latest == null
                                      ? DiaryScreen(diary: c.diary!)
                                      : DiaryReader(entry: latest),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_stories_outlined,
                                    color: neonPink,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      latest?.message ?? 'Дневник Сульфи',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: neonPink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Оглавление дневника',
                                    onPressed: () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DiaryScreen(diary: c.diary!),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            'Сессия №${c.nextNumber}',
                            style: const TextStyle(
                              color: neonLime,
                              fontSize: 12,
                            ),
                          ),
                          const _LiveClock(),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _notes,
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: Text(
                          c.draft.topicText.isEmpty
                              ? 'Тема / запрос и заметка'
                              : c.draft.topicText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _busy ? null : () => _run(_structure),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Структура сессии',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Открыть конструктор',
                            onPressed: _busy ? null : () => _run(_structure),
                            icon: const Icon(
                              Icons.open_in_full,
                              color: neonPink,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${phases.length} фаз · ${phases.expand((p) => p.children).where((c) => c.enabled && c.isModule).length} модулей · ${plan.steps.where((s) => s.kind == StepKind.audio).length} треков · ${plan.steps.where((s) => s.kind != StepKind.audio).length} интервалов · ${formatDurationWords(plan.totalMs)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: antiqueGold,
                        ),
                      ),
                      Expanded(
                        child: phases.isEmpty
                            ? Center(
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(_structure),
                                  child: const Text(
                                    'Добавьте фазу и свои аудиотреки\nОткрыть конструктор',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: phases.length,
                                itemBuilder: (context, i) {
                                  final p = phases[i];
                                  return ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    key: PageStorageKey("home-${p.id}"),
                                    initiallyExpanded: true,
                                    title: Text(
                                      'Фаза: ${p.title}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    children: [
                                      for (final child in p.children.where(
                                        (c) => c.enabled,
                                      ))
                                        if (child.isModule)
                                          ExpansionTile(
                                            key: PageStorageKey(
                                              'home-module-${child.id}',
                                            ),
                                            initiallyExpanded: true,
                                            tilePadding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            title: Text(
                                              'Модуль: ${child.title}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            children: [
                                              for (final step
                                                  in child.items.where(
                                                    (s) => s.enabled,
                                                  ))
                                                _track(step),
                                            ],
                                          )
                                        else
                                          for (final step in child.items.where(
                                            (s) => s.enabled,
                                          ))
                                            _track(step),
                                    ],
                                  );
                                },
                              ),
                      ),
                      InkWell(
                        key: const Key('active-template'),
                        onTap: _busy ? null : _templates,
                        child: NeonPanel(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Image.asset('assets/brand/spiral.png', width: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.baseTemplate?.name ??
                                          c.draft.baseTemplateName ??
                                          'Черновик без шаблона',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: neonLime,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      c.baseTemplate == null
                                          ? 'Выбрать или сохранить шаблон'
                                          : c.draft.modified
                                          ? 'Изменён'
                                          : 'Исходные настройки',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: neonPink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: neonPink),
                            ],
                          ),
                        ),
                      ),
                      if (c.saveError != null)
                        Text(
                          c.saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _track(SessionStep s) => Row(
    children: [
      TextButton(
        onPressed: _busy ? null : () => _pause(s),
        child: Text(
          formatPause(s.delayBeforeSeconds),
          style: const TextStyle(color: neonLime, fontSize: 12),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _run(_structure),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (s.description.isNotEmpty)
                Text(
                  s.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: antiqueGold),
                ),
            ],
          ),
        ),
      ),
      Text(
        s.durationMs == null ? '≈' : formatDuration(s.durationMs!),
        style: const TextStyle(fontSize: 11),
      ),
      IconButton(
        tooltip: 'Прослушать ${s.title}',
        icon: const Icon(Icons.play_circle_outline, color: neonPink),
        onPressed: s.kind != StepKind.audio
            ? null
            : () => _run(() async {
                final a = c.asset(s.audioAssetId);
                if (a != null) {
                  await widget.player.toggle(a, c.library.fileFor(a));
                }
              }),
      ),
    ],
  );
  Widget _nav(String label, IconData? icon, VoidCallback callback) => Expanded(
    child: TextButton(
      onPressed: _busy ? null : callback,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon == null
              ? Image.asset('assets/brand/spiral.png', width: 30, height: 30)
              : Icon(icon, color: neonPink),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();
  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now();
    return Text(
      localDateLabel(d),
      style: const TextStyle(
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
