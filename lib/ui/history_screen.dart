import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../models/local_dates.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'session_actions.dart';
import 'history_detail_screen.dart';
import '../services/preview_player.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    this.selectedRunId,
    this.player,
  });
  final String? selectedRunId;
  final PreviewPlayer? player;
  final SessionController controller;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.selectedRunId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(widget.selectedRunId!);
      });
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryDetailScreen(
          controller: widget.controller,
          runId: id,
          player: widget.player,
          onRepeat: (r) async {
            final start = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Повторить сессию?'),
                content: const Text(
                  'Можно подготовить конфигурацию или сразу начать новый сеанс. Исходная история сохранится.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Подготовить'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Начать повтор'),
                  ),
                ],
              ),
            );
            if (start == null || !mounted) return;
            Navigator.pop(context);
            await _action('repeat', r, start: start);
          },
        ),
      ),
    );
    await widget.controller.repository.acknowledgeHistory(id);
    await widget.controller.reload();
  }

  Future<void> _action(
    String action,
    SessionRun run, {
    bool start = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showActionError(context, () async {
      if (action == 'repeat') {
        final issues = await widget.controller.replayIssues(run);
        if (!mounted) return;
        var rebuild = false;
        if (issues.isNotEmpty) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Точный повтор недоступен'),
              content: SingleChildScrollView(child: Text(issues.join('\n'))),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Закрыть'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Пересобрать сессию'),
                ),
              ],
            ),
          );
          if (result != true || !mounted) return;
          rebuild = true;
        }
        if (widget.controller.draft.modified &&
            !await confirmAction(
              context,
              'Повторить конфигурацию сессии?',
              'Текущие дорожки и паузы будут заменены снимком из истории. Сама история не изменится.',
              confirm: 'Повторить',
            )) {
          return;
        }
        await widget.controller.useRun(run, rebuild: rebuild);
        if (mounted) Navigator.pop(context, start && !rebuild ? run : null);
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
        final attachments =
            await widget.controller.historyAttachments?.list(run.id) ?? [];
        if (attachments.any((a) => a.id == widget.player?.current?.id)) {
          await widget.player?.stop();
        }
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
                    color: r.id == widget.selectedRunId ? neonLime : neonPink,
                    child: ListTile(
                      key: ValueKey('history-${r.id}'),
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
                      onTap: () => _open(r.id),
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
