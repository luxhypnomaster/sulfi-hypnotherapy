import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../models/local_dates.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'session_actions.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _busy = false;
  Future<void> _action(String action, SessionRun run) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showActionError(context, () async {
      if (action == 'repeat') {
        if (!await warnMissingPlanAudio(
          context,
          widget.controller,
          run.snapshot.plan,
        )) {
          return;
        }
        if (!mounted) return;
        if (widget.controller.draft.modified &&
            !await confirmAction(
              context,
              'Повторить конфигурацию сессии?',
              'Текущие дорожки и паузы будут заменены снимком из истории. Сама история не изменится.',
              confirm: 'Повторить',
            )) {
          return;
        }
        await widget.controller.useRun(run);
        if (mounted) Navigator.pop(context, run);
      }
      if (action == 'template') {
        if (!mounted) return;
        await saveTemplateDialog(
          context,
          widget.controller,
          plan: run.snapshot.plan,
          initialName: run.name,
        );
      }
      if (action == 'rename') {
        if (!mounted) return;
        final result = await askDetails(
          context,
          title: 'Название и заметка',
          name: run.name,
          description: run.notes,
          descriptionLabel: 'Заметка',
        );
        if (result != null) {
          await widget.controller.repository.editRun(
            run.id,
            name: result.name,
            notes: result.description,
          );
        }
      }
      if (action == 'delete' &&
          mounted &&
          await confirmAction(
            context,
            'Удалить запись истории?',
            'Аудиофайлы и шаблоны останутся на устройстве.',
            confirm: 'Удалить',
          )) {
        await widget.controller.repository.deleteRun(run.id);
      }
      await widget.controller.reload();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final runs = widget.controller.runs;
      return LeatherScaffold(
        title: 'История',
        child: runs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'История появится после нажатия «Начать трансформацию». Прослушивание отдельных треков сюда не записывается.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: runs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = runs[i];
                  return NeonPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '№${r.displayNumber} · ${historicalDateLabel(r.startedAt, r.startedUtcOffsetMinutes, legacyLabel: r.name)}',
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '${r.status.label} · ${formatDuration(r.elapsedMs)}${r.snapshot.topicText.isEmpty ? '' : ' · ${r.snapshot.topicText}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: neonLime, fontSize: 11),
                      ),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _RunDetails(
                            controller: widget.controller,
                            run: r,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (s) => unawaited(_action(s, r)),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'repeat',
                            child: Text('Повторить сессию'),
                          ),
                          const PopupMenuItem(
                            value: 'template',
                            child: Text('Создать шаблон из сессии'),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Название и заметка'),
                          ),
                          if (!r.active)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить из истории'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}

class _RunDetails extends StatefulWidget {
  const _RunDetails({required this.controller, required this.run});
  final SessionController controller;
  final SessionRun run;
  @override
  State<_RunDetails> createState() => _RunDetailsState();
}

class _RunDetailsState extends State<_RunDetails> {
  late final _events = widget.controller.repository.events(widget.run.id);
  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: 'Сессия №${widget.run.displayNumber}',
    child: FutureBuilder(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Не удалось прочитать события. Вернитесь и повторите попытку.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data!;
        final r = widget.run;
        final plan = r.snapshot.plan;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(r.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              '${r.status.label}\nНачало: ${historicalDateLabel(r.startedAt, r.startedUtcOffsetMinutes, legacyLabel: r.name)}\n${r.endEstimated ? 'Последнее сохранение (точное время остановки неизвестно)' : 'Окончание'}: ${r.endedAt == null ? '—' : formatLocalDate(r.endedAt!)}\n${r.endEstimated ? 'Сохранённая' : 'Фактическая'} длительность: ${formatDuration(r.elapsedMs)}',
            ),
            const SizedBox(height: 12),
            Text(
              'Источник: ${r.snapshot.baseTemplateName ?? 'Текущая конфигурация'}${r.snapshot.baseTemplateVersion == null ? '' : ' · версия ${r.snapshot.baseTemplateVersion}'}',
            ),
            if (r.snapshot.topicText.isNotEmpty)
              Text('Тема: ${r.snapshot.topicText}'),
            if (r.notes.isNotEmpty) Text('Заметка: ${r.notes}'),
            const SizedBox(height: 18),
            const Text(
              'Сохранённая последовательность',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final step in plan.allSteps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${plan.allSteps.indexOf(step) + 1}. ${step.title}\nПауза до: ${formatDuration(step.delayBeforeSeconds * 1000)} · элемент: ${step.durationMs == null ? 'до остановки' : formatDuration(step.durationMs!)}\n${!plan.steps.any((s) => s.id == step.id)
                      ? 'Выключен в плане запуска'
                      : r.skippedStepIds.contains(step.id)
                      ? 'Пропущен при выходе'
                      : _stepStatus(events, plan.steps.indexWhere((s) => s.id == step.id))}',
                ),
              ),
            const Divider(),
            const Text(
              'Фактические события',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final event in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_eventLabel(event['eventType'] as String)),
                subtitle: Text(
                  '${historicalDateLabel(DateTime.parse(event['timestamp'] as String), r.startedUtcOffsetMinutes)} · элемент ${(event['stepIndex'] as int) + 1} · позиция ${formatDuration(event['playheadMs'] as int)}',
                ),
              ),
          ],
        );
      },
    ),
  );
  String _stepStatus(List<Map<String, dynamic>> events, int index) {
    final kinds = events
        .where((e) => e['stepIndex'] == index)
        .map((e) => e['eventType']);
    if (kinds.contains('block_completed')) return 'Выполнен';
    if (kinds.contains('work_completed_early')) return 'Завершён пользователем';
    if (kinds.contains('block_skipped')) return 'Пропущен пользователем';
    if (kinds.contains('block_started')) return 'Начат · не завершён';
    if (kinds.contains('delay_started')) {
      return 'Началось ожидание перед элементом';
    }
    return 'Не запускался';
  }
}

String _eventLabel(String event) => switch (event) {
  'started' => 'Сессия начата',
  'delay_started' => 'Пауза перед элементом',
  'block_started' => 'Элемент начат',
  'block_completed' => 'Элемент завершён',
  'work_completed_early' => 'Самостоятельная работа завершена пользователем',
  'block_skipped' => 'Элемент пропущен',
  'paused' => 'Пауза',
  'resumed' => 'Продолжение',
  'extended_5min' => 'Самостоятельная работа продлена на 5 минут',
  'exit_requested' => 'Запрошен выход',
  'exit_completed' => 'Выход воспроизведён · досрочное завершение',
  'exit_without_audio' => 'Завершение без завершающего аудио',
  'exit_file_missing' => 'Файл выхода недоступен',
  'completed' => 'Сессия завершена',
  'interrupted' => 'Сессия прервана',
  'process_interrupted' =>
    'Приложение было закрыто · восстановлен последний checkpoint',
  'audio_error' || 'execution_error' => 'Ошибка · звук остановлен',
  _ => event,
};
