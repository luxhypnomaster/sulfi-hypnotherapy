import '../services/alchemist_work_queue.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_controller.dart';
import 'design.dart';
import '../services/alchemist_errors.dart';

class AlchemistSyncScreen extends StatefulWidget {
  const AlchemistSyncScreen({
    super.key,
    required this.controller,
    this.focusName,
  });
  final SessionController controller;
  final String? focusName;
  @override
  State<AlchemistSyncScreen> createState() => _AlchemistSyncScreenState();
}

class _AlchemistSyncScreenState extends State<AlchemistSyncScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.cloudQueue.refresh());
  }

  Future<void> resume(String name) async {
    try {
      await widget.controller.ensurePublicationIdentity();
      final result = await widget.controller.cloudQueue.enqueue(name);
      if (mounted && result.reason == 'RESUME_AFTER_CURRENT_REQUEST') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Продолжение запрошено: ждём завершения текущего запроса.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AlchemistFailure.from(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.controller.policy.clientEdition ||
          widget.controller.catalog.api?.ownerBinding == null
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
                    for (final row
                        in [...queue.rows]..sort(
                          (a, b) => (a['_name'] == widget.focusName ? 0 : 1)
                              .compareTo(
                                b['_name'] == widget.focusName ? 0 : 1,
                              ),
                        ))
                      Builder(
                        builder: (context) {
                          final work = row['_work'] as Map,
                              name = row['_name'] as String,
                              phase = work['phase'];
                          return Card(
                            shape: name == widget.focusName
                                ? const RoundedRectangleBorder(
                                    side: BorderSide(color: transferYellow),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  )
                                : null,
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
                                    '${alchemistWorkLabel(work)} · ${alchemistStageLabel(work['stage'])}',
                                  ),
                                  if (alchemistFileProgress(work)
                                      case final progress?) ...[
                                    LinearProgressIndicator(
                                      value: progress,
                                      color: transferYellow,
                                    ),
                                    Text(
                                      'Текущий файл: ${(progress * 100).floor()}% · принято ${work['bytes']} из ${work['totalBytes']} байт',
                                    ),
                                  ] else if (const [
                                    'running',
                                    'preparing',
                                  ].contains(phase))
                                    const LinearProgressIndicator(
                                      color: transferYellow,
                                    ),
                                  Text(
                                    'Попыток задачи: ${work['attempts'] ?? 0} · сетевых повторов: ${work['networkRetries'] ?? 0}',
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
                                          'queued',
                                          'waiting_auth',
                                          'waiting_network',
                                          'waiting_permission',
                                          'pausing',
                                        ].contains(phase))
                                          TextButton(
                                            onPressed: () => resume(name),
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
