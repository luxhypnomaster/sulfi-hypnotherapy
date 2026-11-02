import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../services/session_engine.dart';
import 'design.dart';
import 'session_actions.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.engine});
  final SessionEngine engine;
  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with WidgetsBindingObserver {
  bool _allowPop = false;
  SessionEngine get e => widget.engine;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(e.interrupt().catchError((Object _) {}));
    }
  }

  Future<void> _back() async {
    if (e.active) {
      if (!await confirmAction(
        context,
        'Прервать сессию?',
        'Звук остановится. Фактический прогресс останется в истории.',
        confirm: 'Прервать',
      )) {
        return;
      }
      await e.interrupt();
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (p, _) {
      if (!p) unawaited(_back());
    },
    child: ListenableBuilder(
      listenable: e,
      builder: (context, _) {
        final r = e.run!, s = e.step;
        final progress = e.phaseDurationMs == null || e.phaseDurationMs == 0
            ? null
            : (e.phasePositionMs / e.phaseDurationMs!).clamp(0.0, 1.0);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('Сессия №${r.displayNumber}'),
            actions: [
              TextButton(
                onPressed: _back,
                child: Text(e.active ? 'Прервать' : 'Закрыть'),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      r.snapshot.topicText.isEmpty
                          ? 'Время для себя'
                          : r.snapshot.topicText,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    NeonPanel(
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            e.active
                                ? '${r.stepIndex + 1} / ${r.snapshot.plan.steps.length} · ${r.status.label}'
                                : r.status.label,
                            style: const TextStyle(color: neonLime),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            !e.active
                                ? 'Сессия остановлена'
                                : r.phase == 'delay'
                                ? 'Пауза перед треком'
                                : s?.title ?? '',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (e.active && r.phase == 'delay')
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('Далее: ${s?.title ?? ''}'),
                            ),
                          const SizedBox(height: 20),
                          if (e.active)
                            Text(
                              e.remainingMs == null
                                  ? 'До вашего завершения'
                                  : formatDuration(e.remainingMs!),
                              style: const TextStyle(
                                fontSize: 38,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (e.active)
                            LinearProgressIndicator(value: progress),
                          const SizedBox(height: 12),
                          Text(
                            'Прошло: ${formatDuration(e.active ? e.elapsedMs : r.elapsedMs)}',
                          ),
                        ],
                      ),
                    ),
                    if (e.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          e.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (e.active) ...[
                      const SizedBox(height: 24),
                      NeonButton(
                        label: e.paused ? 'Продолжить' : 'Пауза',
                        icon: e.paused ? Icons.play_arrow : Icons.pause,
                        onPressed: e.busy
                            ? null
                            : () => showActionError(
                                context,
                                e.paused ? e.resume : e.pause,
                              ),
                      ),
                      const SizedBox(height: 12),
                      if (s?.kind == StepKind.freeWork && r.phase == 'work')
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            NeonButton(
                              label: '+5 минут',
                              icon: Icons.more_time,
                              onPressed: e.busy
                                  ? null
                                  : () => showActionError(context, e.extend),
                            ),
                            NeonButton(
                              label: 'Завершить работу',
                              icon: Icons.skip_next,
                              onPressed: e.busy
                                  ? null
                                  : () => showActionError(context, e.next),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: e.busy
                              ? null
                              : () => showActionError(context, e.next),
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Следующий блок'),
                        ),
                      const SizedBox(height: 28),
                      NeonButton(
                        label: 'Завершить и выйти',
                        icon: Icons.exit_to_app,
                        onPressed: () => showActionError(context, e.exit),
                        primary: true,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Сессия работает в открытом приложении. При блокировке экрана или уходе в фон она будет прервана.',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Почувствуйте опору под ногами и спиной. Сделайте несколько спокойных вдохов. Осмотритесь, назовите несколько предметов вокруг и возвращайтесь к делам в своём темпе.',
                      ),
                      const SizedBox(height: 24),
                      NeonButton(
                        label: 'Вернуться на главную',
                        icon: Icons.home_outlined,
                        onPressed: _back,
                        primary: true,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Фактические события сохранены в истории. Пользовательские заметки не являются оценкой терапевтического результата.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
