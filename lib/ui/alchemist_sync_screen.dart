import '../services/alchemist_work_queue.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_controller.dart';
import 'design.dart';

class AlchemistSyncScreen extends StatefulWidget {
  const AlchemistSyncScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<AlchemistSyncScreen> createState() => _AlchemistSyncScreenState();
}

class _AlchemistSyncScreenState extends State<AlchemistSyncScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.cloudQueue.refresh());
  }

  @override
  Widget build(BuildContext context) => !widget.controller.policy.isAuthor
      ? const Scaffold(
          body: Center(child: Text('Авторские возможности недоступны')),
        )
      : LeatherScaffold(
          title: 'Очередь передач',
          child: ListenableBuilder(
            listenable: widget.controller.cloudQueue,
            builder: (context, _) {
              final queue = widget.controller.cloudQueue;
              return RefreshIndicator(
                onRefresh: queue.refresh,
                child: ListView(
                  children: [
                    const Text(
                      'При сворачивании передача ставится на паузу после текущего запроса. Для продолжения откройте приложение и нажмите «Продолжить». Исходники сохраняются. Отмена очереди не снимает уже подтверждённую публикацию: используйте «Снять публикацию» в карточке.',
                    ),
                    for (final row in queue.rows)
                      Builder(
                        builder: (context) {
                          final work = row['_work'] as Map,
                              name = row['_name'] as String,
                              phase = work['phase'];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['card']?['title'] ??
                                        row['entry']?['title'] ??
                                        'Передача',
                                  ),
                                  Text(
                                    '${const {'queued': 'В очереди', 'running': 'Выполняется', 'complete': 'Подтверждено сервером', 'paused': 'Пауза', 'pausing': 'Завершается текущий запрос', 'failed': 'Сбой', 'cancelled': 'Отменено'}[phase] ?? phase} · ${alchemistStageLabel(work['stage'])}',
                                  ),
                                  Text(
                                    '${work['bytes'] ?? 0} / ${work['totalBytes'] ?? 0} байт · попыток задачи ${work['attempts'] ?? 0} · сетевых повторов ${work['networkRetries'] ?? 0}',
                                  ),
                                  if (work['code'] != null)
                                    Text('Код: ${work['code']}'),
                                  if (work['message'] != null)
                                    Text(work['message']),
                                  if (!const [
                                    'complete',
                                    'cancelled',
                                  ].contains(phase))
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (const [
                                          'paused',
                                          'failed',
                                        ].contains(phase))
                                          TextButton(
                                            onPressed: () =>
                                                queue.enqueue(name),
                                            child: const Text('Продолжить'),
                                          )
                                        else
                                          TextButton(
                                            onPressed: () => queue.pause(name),
                                            child: const Text('Пауза'),
                                          ),
                                        TextButton(
                                          onPressed: () =>
                                              queue.pause(name, cancel: true),
                                          child: const Text(
                                            'Отменить отправку',
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (queue.rows.isEmpty)
                      const Text(
                        'Нет задач этого аккаунта. Старые черновики доступны в разделе «Мои публикации».',
                      ),
                  ],
                ),
              );
            },
          ),
        );
}
