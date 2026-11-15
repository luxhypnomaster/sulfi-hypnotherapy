import 'package:sqflite/sqflite.dart';

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
  String _direction = 'all';
  String _networkPolicy = 'any';
  Future<void> networkPolicy(String value) async {
    await widget.controller.capsules!.database.insert('app_settings', {
      'name': 'transfer_network_policy18',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await widget.controller.applyTransferNetworkPolicy();
    if (mounted) setState(() => _networkPolicy = value);
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.cloudQueue.refresh());
    unawaited(() async {
      final rows = await widget.controller.capsules!.database.query(
        'app_settings',
        where: 'name=?',
        whereArgs: ['transfer_network_policy18'],
      );
      if (mounted && rows.isNotEmpty) {
        setState(() => _networkPolicy = rows.single['value'] as String);
      }
    }());
  }

  Future<void> resume(String name) async {
    try {
      if (!name.startsWith('alchemist_download:') &&
          !name.startsWith('alchemist_read_sync_queue:')) {
        await widget.controller.ensurePublicationIdentity();
      }
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
  Widget build(BuildContext context) => widget.controller.transferOwner == null
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
                      'Передачи продолжаются средствами Android после сворачивания и блокировки. При ограничении ОС, сети или Google-входа задача сохраняется. Пауза — только по вашей кнопке. Исходники сохраняются. Отмена не снимает уже подтверждённую публикацию.',
                    ),
                    DropdownButton<String>(
                      value: _networkPolicy,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'any',
                          child: Text('Передача: любая сеть'),
                        ),
                        DropdownMenuItem(
                          value: 'unmetered',
                          child: Text('Передача: только безлимитная сеть'),
                        ),
                      ],
                      onChanged: (v) => networkPolicy(v!),
                    ),
                    DropdownButton<String>(
                      value: _direction,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Все передачи'),
                        ),
                        DropdownMenuItem(
                          value: 'upload',
                          child: Text('Отправка'),
                        ),
                        DropdownMenuItem(
                          value: 'download',
                          child: Text('Скачивание'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _direction = v!),
                    ),
                    for (final row
                        in [
                          ...queue.rows.where(
                            (r) =>
                                _direction == 'all' ||
                                (r['_work']?['direction'] ?? 'upload') ==
                                    _direction,
                          ),
                        ]..sort(
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
                                        row['download']?['title'] ??
                                        'Передача',
                                  ),
                                  Text(
                                    work['direction'] == 'download'
                                        ? 'Скачивание'
                                        : 'Отправка',
                                  ),
                                  Text(
                                    '${alchemistWorkLabel(work)} · ${alchemistStageLabel(work['stage'])}',
                                  ),
                                  if (work['bytes'] is num &&
                                      work['totalBytes'] is num)
                                    Text(
                                      '${work['bytes']} / ${work['totalBytes']} байт',
                                    ),
                                  if (work['lastProgressAtMs'] is int)
                                    Text(
                                      'Последний прогресс: ${DateTime.fromMillisecondsSinceEpoch(work['lastProgressAtMs']).toLocal()}',
                                    ),
                                  if (work['performance'] is Map)
                                    Text(
                                      'Измеренные RPC: ${(work['performance']['byStage'] as Map).entries.where((e) => e.key.toString().endsWith(':complete') && !e.key.toString().startsWith('media.localHash:')).fold<int>(0, (n, e) => n + (e.value['count'] as int))} · ${work['performance']['confirmedBytesThisRun']} подтверждённых байт за этот запуск',
                                    ),
                                  if (alchemistFileProgress(work)
                                      case final progress?) ...[
                                    LinearProgressIndicator(
                                      value: progress,
                                      color: transferYellow,
                                    ),
                                    Text(
                                      'Подтверждённые байты: ${(progress * 100).floor()}% · принято ${work['bytes']} из ${work['totalBytes']} байт',
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
                                          'retry_scheduled',
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
