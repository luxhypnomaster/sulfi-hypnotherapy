import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import '../services/session_controller.dart';
import 'alchemist_catalog_screen.dart';
import 'design.dart';

class AlchemistSyncScreen extends StatefulWidget {
  const AlchemistSyncScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<AlchemistSyncScreen> createState() => _AlchemistSyncScreenState();
}

class _AlchemistSyncScreenState extends State<AlchemistSyncScreen> {
  final rows = <Map<String, dynamic>>[];
  String? error;
  bool busy = false;
  Database get db => widget.controller.capsules!.database;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_%'],
      );
      final parsed = <Map<String, dynamic>>[];
      for (final row in values) {
        final name = row['name'] as String;
        if (![
          'alchemist_upload:',
          'alchemist_card:',
          'alchemist_diary_queue:',
          'alchemist_read_sync_queue:',
        ].any(name.startsWith)) {
          continue;
        }
        try {
          parsed.add({
            'name': name,
            'value': Map<String, dynamic>.from(
              jsonDecode(row['value'] as String),
            ),
          });
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          rows.clear();
          rows.addAll(parsed);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> flush() async {
    setState(() => busy = true);
    try {
      await widget.controller.diary?.flushCloudQueue();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(Map<String, dynamic> row) async {
    final name = row['name'] as String,
        value = row['value'] as Map<String, dynamic>;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить ожидание отправки?'),
        content: const Text(
          'Черновик и исходные файлы сохранятся. Уже подтверждённые публикации проверяются и снимаются в редакторе.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отменить ожидание'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (name.startsWith('alchemist_upload:')) {
        if (value['sessionId'] != null) {
          await widget.controller.alchemistApi().call('media.abortUpload', {
            'sessionId': value['sessionId'],
          });
        }
        value['state'] = 'cancelled';
        value['requestId'] = newId();
        value.remove('sessionId');
        await db.update(
          'app_settings',
          {'value': jsonEncode(value)},
          where: 'name=?',
          whereArgs: [name],
        );
      } else {
        await db.delete('app_settings', where: 'name=?', whereArgs: [name]);
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !widget.controller.policy.isAuthor
      ? const Scaffold(
          body: Center(child: Text('Авторские возможности недоступны')),
        )
      : LeatherScaffold(
          title: 'Очередь синхронизации',
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              children: [
                TextButton.icon(
                  onPressed: busy ? null : flush,
                  icon: const Icon(Icons.sync),
                  label: const Text('Повторить отправку дневника'),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: neonPink)),
                for (final row in rows)
                  Builder(
                    builder: (context) {
                      final v = row['value'], name = row['name'] as String;
                      final card = name.startsWith('alchemist_card:'),
                          upload = name.startsWith('alchemist_upload:');
                      final status = v['status'] ?? v['state'] ?? 'pending';
                      return ListTile(
                        title: Text(
                          v['card']?['title'] ??
                              v['entry']?['title'] ??
                              (upload ? 'Передача файла' : 'Состояние чтения'),
                        ),
                        subtitle: Text(
                          '${const {'draft': 'Черновик', 'published': 'Опубликовано', 'failed': 'Ошибка — можно повторить', 'paused': 'Пауза', 'pending': 'Ожидает отправки', 'verified': 'Файл проверен сервером', 'localConflict': 'Новые правки — подтвердите публикацию в редакторе', 'cancelled': 'Ожидание отменено'}[status] ?? status}'
                          '${upload ? '\n${v['offset'] ?? 0} / ${v['byteLength'] ?? 0} байт' : ''}${v['error'] == null ? '' : '\n${v['error']}'}',
                        ),
                        onTap: card
                            ? () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CatalogCardEditor(
                                      service: widget.controller.catalog,
                                      draft: Map<String, dynamic>.from(v),
                                    ),
                                  ),
                                );
                                await load();
                              }
                            : null,
                        trailing:
                            busy ||
                                card ||
                                ['verified', 'cancelled'].contains(status)
                            ? null
                            : IconButton(
                                tooltip: 'Отменить ожидание',
                                onPressed: () => cancel(row),
                                icon: const Icon(Icons.close),
                              ),
                      );
                    },
                  ),
                if (rows.isEmpty)
                  const ListTile(title: Text('Нет сохранённых операций')),
              ],
            ),
          ),
        );
}
