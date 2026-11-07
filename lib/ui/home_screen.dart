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
import 'run_screen.dart';
import 'session_actions.dart';
import 'modular_structure_screen.dart';
import '../services/session_audio_handler.dart';
import 'templates_modules_screen.dart';
import 'home_composition.dart';
import '../services/library_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreHistory());
    });
  }

  Future<void> _restoreHistory() async {
    final id = await c.repository.pendingHistory();
    if (!mounted || id == null || _busy) return;
    if (!c.runs.any((r) => r.id == id && !r.active)) {
      await c.repository.acknowledgeHistory(id);
      return;
    }
    await _history(selectedId: id);
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
    await c.flush();
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
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplatesModulesScreen(controller: c, player: widget.player),
      ),
    );
    await c.reload();
  });
  Future<void> _history({String? selectedId}) async {
    SessionRun? repeat;
    await _run(() async {
      if (!mounted) return;
      repeat = await Navigator.push<SessionRun>(
        context,
        MaterialPageRoute(
          builder: (_) => HistoryScreen(
            controller: c,
            player: widget.player,
            selectedRunId: selectedId,
          ),
        ),
      );
      await c.reload();
    });
    if (repeat != null && mounted) await _start();
  }

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
  Future<void> _start() async {
    SessionRun? repeat;
    await _run(() async {
      await widget.player.stop();
      final engine = sessionAudioHandler != null
          ? await sessionAudioHandler!.startSession()
          : SessionEngine(
              controller: c,
              transport:
                  widget.transportFactory?.call() ??
                  JustAudioSessionTransport(),
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
          repeat = await Navigator.push<SessionRun>(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryScreen(
                controller: c,
                player: widget.player,
                selectedRunId: finishedId,
              ),
            ),
          );
        }
      } finally {
        if (sessionAudioHandler?.engine != engine) await engine.close();
        _engine = null;
        await c.reload();
      }
    });
    if (repeat != null && mounted) await _start();
  }

  Future<void> _preview(SessionStep step) => _run(() async {
    if ((_engine?.active ?? false) ||
        (sessionAudioHandler?.engine?.active ?? false)) {
      throw const LibraryException('Сначала завершите активную сессию');
    }
    final asset = c.asset(step.audioAssetId);
    if (asset != null) {
      await widget.player.toggle(asset, c.library.fileFor(asset));
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => HomeComposition(
      player: widget.player,
      controller: c,
      busy: _busy,
      onStructure: () => _run(_structure),
      onTemplates: _templates,
      onLibrary: _library,
      onHistory: _history,
      onNotes: _notes,
      onStart: _busy || c.draft.plan.steps.isEmpty || c.saving ? null : _start,
      onPreview: _preview,
      clock: const _LiveClock(),
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
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 10,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
