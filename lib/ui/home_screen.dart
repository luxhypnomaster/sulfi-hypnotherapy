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
import 'preview_bar.dart';
import 'run_screen.dart';
import 'session_actions.dart';
import 'structure_screen.dart';
import 'templates_screen.dart';

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
      if (_engine?.active ?? false) {
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
        builder: (_) => StructureScreen(controller: c, player: widget.player),
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
          player: widget.player,
          allowSelection: true,
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
    final repeat = await Navigator.push<SessionRun>(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(controller: c)),
    );
    await c.reload();
    if (repeat != null && mounted) await _structure();
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
    final engine = SessionEngine(
      controller: c,
      transport: widget.transportFactory?.call() ?? JustAudioSessionTransport(),
    );
    _engine = engine;
    try {
      await engine.start();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => RunScreen(engine: engine)),
      );
    } finally {
      await engine.close();
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
      final plan = c.draft.plan;
      final heroHeight = (MediaQuery.sizeOf(context).height * .18).clamp(
        112.0,
        180.0,
      );
      return Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NeonButton(
                      label: 'Начать сессию',
                      icon: Icons.play_circle_filled,
                      onPressed: _busy || plan.steps.isEmpty || c.saving
                          ? null
                          : _start,
                      primary: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.steps.isEmpty
                          ? 'Добавьте первый трек через «Библиотеку».'
                          : 'Оставьте приложение открытым: в фоне сессия прервётся.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC8ADBD),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _navigation(),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: LayoutBuilder(
                builder: (context, viewport) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    SizedBox(
                      height: heroHeight,
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
                          Positioned(
                            left: 22,
                            top: 20,
                            width: 150,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'САМОГИПНОЗ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const Text(
                                  'Sulfi',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: neonPink,
                                    shadows: [
                                      Shadow(color: neonPink, blurRadius: 12),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ваш внутренний\nнавигатор',
                                  style: TextStyle(fontSize: 12, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (viewport.maxHeight - heroHeight).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: LeatherBoard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LayoutBuilder(
                                  builder: (context, box) {
                                    if (box.maxWidth < 300 ||
                                        MediaQuery.textScalerOf(context)
                                                .scale(1) >
                                            1.3) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _structureCard(),
                                          const Divider(color: antiqueGold),
                                          _sessionCard(),
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: _structureCard(),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 205,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          color: antiqueGold.withValues(
                                            alpha: .4,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: _sessionCard(),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              key: const Key('active-template'),
                              onTap: _busy ? null : _templates,
                              borderRadius: BorderRadius.circular(11),
                              child: NeonPanel(
                                glow: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      color: neonPink,
                                      size: 31,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.draft.modified
                                                ? 'АКТИВНЫЙ ШАБЛОН · ИЗМЕНЁН'
                                                : 'АКТИВНЫЙ ШАБЛОН',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              letterSpacing: .7,
                                              color: Color(0xFFCE9BB7),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            c.baseTemplate?.name ??
                                                c.draft.baseTemplateName ??
                                                'Текущая конфигурация',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w800,
                                              color: neonLime,
                                            ),
                                          ),
                                          if (c
                                                  .baseTemplate
                                                  ?.description
                                                  .isNotEmpty ??
                                              false)
                                            Text(
                                              c.baseTemplate!.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: neonPink,
                                    ),
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
                    PreviewBar(player: widget.player, library: c.library),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _structureCard() {
    final steps = c.draft.plan.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _busy ? null : () => _run(_structure),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Структура сессии',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${steps.length} блоков · развернуть',
                        style: const TextStyle(fontSize: 10, color: neonPink),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_full, size: 16, color: neonPink),
              ],
            ),
          ),
        ),
        if (steps.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Добавьте аудио и соберите последовательность.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _run(_structure),
            icon: const Icon(Icons.add),
            label: const Text('Собрать'),
          ),
        ] else ...[
          const Text(
            'Пауза → трек',
            style: TextStyle(fontSize: 10, color: antiqueGold),
          ),
          for (var i = 0; i < steps.length && i < 3; i++)
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Пауза перед блоком ${i + 1}',
                  child: InkWell(
                    onTap: _busy ? null : () => _pause(steps[i]),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatPause(steps[i].delayBeforeSeconds),
                        style: const TextStyle(
                          color: neonLime,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _busy ? null : () => _run(_structure),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${c.asset(steps[i].audioAssetId)?.title ?? steps[i].title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          steps[i].durationMs == null
                              ? 'До остановки'
                              : formatDuration(steps[i].durationMs!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFBDA5B5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _sessionCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Сессия №${c.nextNumber}',
        style: const TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          color: neonLime,
        ),
      ),
      const SizedBox(height: 5),
      const _LiveClock(),
      const SizedBox(height: 10),
      TextField(
        controller: _topic,
        focusNode: _topicFocus,
        minLines: 1,
        maxLines: 2,
        maxLength: 200,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          labelText: 'Тема/запрос',
          labelStyle: TextStyle(fontSize: 12),
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onChanged: (text) =>
            unawaited(c.setText(topic: text).catchError((Object _) {})),
      ),
      const SizedBox(height: 7),
      Text(
        'Итого: ${c.draft.plan.estimated ? '≈ ' : ''}${formatDuration(c.draft.plan.totalMs)}',
        style: const TextStyle(
          color: neonLime,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        onPressed: _busy ? null : _notes,
        icon: const Icon(Icons.note_alt_outlined, size: 17),
        label: const Text('Заметка', style: TextStyle(fontSize: 12)),
      ),
      if (c.draft.notes.isNotEmpty)
        Text(
          c.draft.notes,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFFC8ADBD)),
        ),
    ],
  );

  Widget _navigation() => LayoutBuilder(
    builder: (context, box) {
      final buttons = [
        _nav('Библиотека', Icons.headphones_outlined, _library),
        _nav('Записать', Icons.mic_none, null),
        _nav('Шаблоны', Icons.layers_outlined, _templates),
        _nav('История', Icons.history, _history),
      ];
      if (box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final button in buttons)
              SizedBox(width: (box.maxWidth - 6) / 2, child: button),
          ],
        );
      }
      return Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: buttons[i]),
          ],
        ],
      );
    },
  );
  Widget _nav(String label, IconData icon, VoidCallback? callback) => Tooltip(
    message: callback == null
        ? 'Записать свой аудиомодуль · следующий этап'
        : label,
    child: OutlinedButton(
      onPressed: _busy ? null : callback,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFF210E1A),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        side: BorderSide(
          color: callback == null
              ? const Color(0xFF604254)
              : neonPink.withValues(alpha: .6),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 25,
            color: callback == null ? const Color(0xFF98798A) : neonPink,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFFEAD8E2)),
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
      '${formatLocalDate(d)}:${d.second.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
