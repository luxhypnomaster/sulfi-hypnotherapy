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
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.8,
              colors: [Color(0xFF4A062D), ink],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                  children: [
                    SizedBox(
                      height: (MediaQuery.sizeOf(context).width * .46).clamp(
                        155.0,
                        205.0,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ExcludeSemantics(
                                child: Image.asset(
                                  'assets/art/sulfi_header.png',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.centerRight,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 22,
                            width: 155,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'САМОГИПНОЗ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 2,
                                    color: Color(0xFFEDDBE5),
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                                const SizedBox(height: 6),
                                const Text(
                                  'Ваш внутренний\nнавигатор',
                                  style: TextStyle(fontSize: 14, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    LeatherBoard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Рабочий планшет',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
                              const Icon(
                                Icons.offline_bolt_outlined,
                                color: neonLime,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, box) {
                              final structure = _structureCard(),
                                  card = _sessionCard();
                              if (box.maxWidth < 360 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.25) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    structure,
                                    const SizedBox(height: 12),
                                    card,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: structure),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 5, child: card),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          InkWell(
                            onTap: _busy ? null : _templates,
                            borderRadius: BorderRadius.circular(16),
                            child: NeonPanel(
                              glow: true,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.layers_outlined,
                                    color: neonPink,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'АКТИВНЫЙ ШАБЛОН',
                                          style: TextStyle(
                                            fontSize: 12,
                                            letterSpacing: 1.1,
                                            color: Color(0xFFCE9BB7),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.baseTemplate?.name ??
                                              c.draft.baseTemplateName ??
                                              'Текущая конфигурация',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: neonLime,
                                          ),
                                        ),
                                        if (c
                                                .baseTemplate
                                                ?.description
                                                .isNotEmpty ??
                                            false)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              c.baseTemplate!.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.draft.modified
                                              ? 'Изменён · исходный шаблон сохранён'
                                              : c.baseTemplate == null
                                              ? 'Можно сохранить как новый шаблон'
                                              : 'Исходные настройки',
                                          style: const TextStyle(
                                            color: neonPink,
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
                          const SizedBox(height: 20),
                          NeonButton(
                            label: 'Начать сессию',
                            icon: Icons.play_circle_outline,
                            onPressed: _busy || plan.steps.isEmpty || c.saving
                                ? null
                                : _start,
                            primary: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plan.steps.isEmpty
                                ? 'Добавьте аудио или блок тишины в структуру.'
                                : 'На этом этапе сессия работает в открытом приложении. При блокировке экрана она будет прервана.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC8ADBD),
                            ),
                          ),
                          if (c.saveError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                c.saveError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                          _navigation(),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                c.saving ? Icons.sync : Icons.lock_outline,
                                size: 14,
                                color: antiqueGold,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  c.saving
                                      ? 'Сохранение…'
                                      : c.saveError != null
                                      ? 'Есть несохранённые изменения'
                                      : 'Только на устройстве · конфигурация сохранена',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: antiqueGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
    return NeonPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _busy ? null : () => _run(_structure),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Структура сессии',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_full, size: 17, color: neonPink),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (steps.isEmpty) ...[
            const Text(
              'Здесь появится последовательность треков и пауз.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _busy ? null : () => _run(_structure),
              icon: const Icon(Icons.add),
              label: const Text('Собрать'),
            ),
          ] else ...[
            for (var i = 0; i < steps.length && i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _busy ? null : () => _pause(steps[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: neonLime,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              formatPause(steps[i].delayBeforeSeconds),
                              style: const TextStyle(
                                color: neonLime,
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              '  до трека',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC5A9BC),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _busy ? null : () => _run(_structure),
                      child: Text(
                        '${i + 1}. ${c.asset(steps[i].audioAssetId)?.title ?? steps[i].title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      steps[i].durationMs == null
                          ? 'До остановки'
                          : 'Трек: ${formatDuration(steps[i].durationMs!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBDA5B5),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => _run(_structure),
              child: Text(
                steps.length > 4
                    ? 'Ещё ${steps.length - 4} · Развернуть'
                    : 'Развернуть',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionCard() => NeonPanel(
    padding: const EdgeInsets.all(10),
    color: antiqueGold,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Карточка сессии',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'Следующая №${c.nextNumber}',
          style: const TextStyle(color: neonLime, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const _LiveClock(),
        const SizedBox(height: 12),
        TextField(
          controller: _topic,
          focusNode: _topicFocus,
          minLines: 1,
          maxLines: 3,
          maxLength: 200,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Тема/запрос',
            counterText: '',
            contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          ),
          onChanged: (text) =>
              unawaited(c.setText(topic: text).catchError((Object _) {})),
        ),
        const SizedBox(height: 10),
        Text(
          '${c.draft.plan.estimated ? '≈ ' : ''}${formatDuration(c.draft.plan.totalMs)}',
          style: const TextStyle(
            color: neonLime,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _notes,
          icon: const Icon(Icons.note_alt_outlined, size: 18),
          label: const Text('Заметка', style: TextStyle(fontSize: 12)),
        ),
        if (c.draft.notes.isNotEmpty)
          Text(
            c.draft.notes,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
      ],
    ),
  );
  Widget _navigation() => LayoutBuilder(
    builder: (context, box) {
      final buttons = [
        _nav('Библиотека', Icons.headphones_outlined, _library),
        _nav('Записать свой аудиомодуль', Icons.mic_none, null),
        _nav('Шаблоны', Icons.layers_outlined, _templates),
        _nav('История', Icons.history, _history),
      ];
      if (box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 8),
                Expanded(child: buttons[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buttons[2]),
                const SizedBox(width: 8),
                Expanded(child: buttons[3]),
              ],
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: buttons[i]),
          ],
        ],
      );
    },
  );
  Widget _nav(String label, IconData icon, VoidCallback? callback) =>
      OutlinedButton(
        onPressed: _busy ? null : callback,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
          side: BorderSide(
            color: callback == null
                ? const Color(0xFF604254)
                : neonPink.withValues(alpha: .6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: callback == null ? const Color(0xFF98798A) : neonPink,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFEAD8E2)),
            ),
            if (callback == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Следующий этап',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFFA8899C)),
                ),
              ),
          ],
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
