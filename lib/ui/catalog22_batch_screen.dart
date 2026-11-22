import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ratings22.dart';
import '../models/session_plan.dart' show newId;
import '../services/session_controller.dart';

/// Metadata-only batches on the existing catalog/jobs contract; never an audio
/// replacement or a second publishing queue. Pending intent survives restart.
class Catalog22BatchScreen extends StatefulWidget {
  const Catalog22BatchScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<Catalog22BatchScreen> createState() => _Catalog22BatchScreenState();
}

class _Catalog22BatchScreenState extends State<Catalog22BatchScreen> {
  final query = TextEditingController(),
      author = TextEditingController(),
      categories = TextEditingController();
  final selected = <String>{};
  List<Map<String, dynamic>> rows = [];
  late final owner = widget.controller.transferOwner;
  String get key => 'catalog22_batch:${digest22(owner)}';
  String action = 'quietEdit',
      status = 'Выберите до 50 материалов. Аудио и история не заменяются.';
  Map<String, dynamic>? pending;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    author.dispose();
    categories.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final db = widget.controller.capsules!.database,
          local = await db.query(
            'app_settings',
            where: 'name=?',
            whereArgs: [key],
          );
      if (local.isNotEmpty) {
        final value = jsonDecode(local.single['value'] as String);
        pending = value['pending'];
        author.text = value['author'] ?? '';
        categories.text = value['categories'] ?? '';
      }
      final data = await widget.controller.project22!.call(
        'project.catalogList',
        {},
      );
      if (mounted && owner == widget.controller.transferOwner) {
        setState(() => rows = List<Map<String, dynamic>>.from(data['records']));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Источник не получен. Сохранённый запрос доступен для повтора.',
        );
      }
    }
  }

  Future<void> persist() async {
    if (owner != widget.controller.transferOwner) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    await widget.controller.capsules!.database.insert('app_settings', {
      'name': key,
      'value': jsonEncode({
        'pending': pending,
        'author': author.text,
        'categories': categories.text,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> submit({bool resume = false}) async {
    if (busy) return;
    if (!resume) {
      if (selected.isEmpty || selected.length > 50) return;
      final changes = [
        for (final row in rows.where((r) => selected.contains(r['contentId'])))
          {
            'contentId': row['contentId'],
            'action': action,
            'expectedRevisionId': row['revisionId'],
            'patch': {
              if (author.text.trim().isNotEmpty)
                'authorDisplayName': author.text.trim(),
              if (categories.text.trim().isNotEmpty)
                'categoryIds': categories.text
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toSet()
                    .toList(),
            },
          },
      ];
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Предпросмотр пакетной правки'),
          content: Text(
            '${changes.length} материалов · $action\n${author.text.trim().isEmpty ? 'Автор сохранён' : 'Автор: ${author.text.trim()}'}\n${categories.text.trim().isEmpty ? 'Категории сохранены' : 'Категории: ${categories.text.trim()}'}\nПубликация и снятие с публикации требуют подтверждения сервера.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Подтвердить правку'),
            ),
          ],
        ),
      );
      if (yes != true) return;
      pending = {'requestId': newId(), 'changes': changes};
      await persist();
    }
    if (pending == null || !mounted) return;
    setState(() => busy = true);
    try {
      final r = widget.controller.project22!,
          job = await r.call('project.catalogBatch', pending!),
          done = await r.call('project.runOperation', {
            'operationId': job['operationId'],
          });
      if (done['state'] != 'SUCCEEDED' ||
          done['receipt']?['outcome'] != 'COMMITTED') {
        throw const FormatException('BATCH_NOT_COMMITTED');
      }
      final result = await r.call('project.operationResult', {
        'operationId': job['operationId'],
      });
      if (result['requestId'] != pending!['requestId'] ||
          digest22(result) != done['receipt']['preparedHash']) {
        throw const FormatException('BATCH_RECEIPT');
      }
      pending = null;
      selected.clear();
      await persist();
      await load();
      if (mounted) {
        setState(
          () => status = 'Пакетная правка подтверждена серверной квитанцией',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Правка не подтверждена. Запрос сохранён; повтор не создаёт новую редакцию.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (owner != widget.controller.transferOwner) {
      return const Scaffold(body: Center(child: Text('Аккаунт изменён')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Управление материалами')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(status),
          TextField(
            key: const Key('catalog22-search'),
            controller: query,
            decoration: const InputDecoration(labelText: 'Поиск материалов'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: author,
            decoration: const InputDecoration(
              labelText: 'Автор (пусто — сохранить прежнего)',
            ),
          ),
          TextField(
            controller: categories,
            decoration: const InputDecoration(
              labelText: 'ID категорий через запятую (пусто — сохранить)',
            ),
          ),
          DropdownButton<String>(
            value: action,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: 'quietEdit',
                child: Text('Изменить описание без повторного анонса'),
              ),
              DropdownMenuItem(value: 'publish', child: Text('Опубликовать')),
              DropdownMenuItem(
                value: 'withdraw',
                child: Text('Снять с публикации'),
              ),
            ],
            onChanged: busy ? null : (v) => setState(() => action = v!),
          ),
          for (final row in rows.where(
            (r) => '${r['title']} ${r['contentId']}'.toLowerCase().contains(
              query.text.toLowerCase(),
            ),
          ))
            CheckboxListTile(
              key: ValueKey('batch22-${row['contentId']}'),
              title: Text(row['title']),
              subtitle: Text('${row['type']} · ${row['state']}'),
              value: selected.contains(row['contentId']),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(row['contentId']);
                      } else {
                        selected.remove(row['contentId']);
                      }
                    }),
            ),
          FilledButton(
            onPressed:
                busy ||
                    selected.isEmpty ||
                    selected.length > 50 ||
                    pending != null
                ? null
                : () => submit(),
            child: const Text('Предпросмотр и применение'),
          ),
          if (pending != null)
            OutlinedButton(
              onPressed: busy ? null : () => submit(resume: true),
              child: const Text('Сверить или повторить сохранённый запрос'),
            ),
        ],
      ),
    );
  }
}
