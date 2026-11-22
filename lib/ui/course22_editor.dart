import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart' show newId;
import '../models/ratings22.dart';
import '../services/session_controller.dart';

class Course22Drafts extends StatefulWidget {
  const Course22Drafts({super.key, required this.controller});
  final SessionController controller;
  @override
  State<Course22Drafts> createState() => _Course22DraftsState();
}

class _Course22DraftsState extends State<Course22Drafts> {
  List<Map<String, dynamic>> drafts = [];
  String get prefix =>
      'course22_draft:${digest22(widget.controller.transferOwner)}:';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = prefix,
        rows = await widget.controller.capsules!.database.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['$p%'],
        );
    if (mounted && p == prefix) {
      setState(
        () => drafts = rows
            .map(
              (r) =>
                  Map<String, dynamic>.from(jsonDecode(r['value'] as String)),
            )
            .toList(),
      );
    }
  }

  Future<void> open([String? id]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Course22Editor(controller: widget.controller, contentId: id),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Курсы')),
    body: ListView(
      children: [
        FilledButton(
          onPressed: () => open(),
          child: const Text('Создать курс'),
        ),
        for (final d in drafts)
          ListTile(
            title: Text(d['title']),
            subtitle: Text('${(d['programRefs'] as List).length} программ'),
            onTap: () => open(d['contentId']),
          ),
      ],
    ),
  );
}

class Course22Editor extends StatefulWidget {
  const Course22Editor({super.key, required this.controller, this.contentId});
  final SessionController controller;
  final String? contentId;
  @override
  State<Course22Editor> createState() => _Course22EditorState();
}

class _Course22EditorState extends State<Course22Editor> {
  final title = TextEditingController(), description = TextEditingController();
  late final id = widget.contentId ?? newId();
  late final owner = widget.controller.transferOwner;
  String? expectedRevision, requestId, confirmedDigest, pendingDigest;
  List<Map<String, dynamic>> refs = [], programs = [];
  String status = 'Черновик хранится отдельно от опубликованного курса.';
  bool busy = false;
  String get key => 'course22_draft:${digest22(owner)}:$id';
  Map<String, dynamic> value() => {
    'contentId': id,
    'title': title.text.trim(),
    'description': description.text.trim(),
    'programRefs': refs,
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final rows = await widget.controller.capsules!.database.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [key],
      );
      if (rows.isNotEmpty) {
        final d = jsonDecode(rows.single['value'] as String);
        title.text = d['title'];
        description.text = d['description'];
        refs = List<Map<String, dynamic>>.from(d['programRefs']);
        expectedRevision = d['expectedRevision'];
        requestId = d['requestId'];
        pendingDigest = d['pendingDigest'];
        confirmedDigest = d['confirmedDigest'];
      }
      final r = await widget.controller.project22!.call(
        'project.catalogList',
        {},
      );
      programs = (r['records'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (p) =>
                p['type'] == 'template' &&
                p['state'] == 'published' &&
                p['public'] == true,
          )
          .toList();
      if (mounted && owner == widget.controller.transferOwner) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Список программ не обновлён. Локальный черновик сохранён.',
        );
      }
    }
  }

  Future<void> save() async {
    if (owner != widget.controller.transferOwner) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    await widget.controller.capsules!.database.insert('app_settings', {
      'name': key,
      'value': jsonEncode({
        ...value(),
        'expectedRevision': expectedRevision,
        'requestId': requestId,
        'pendingDigest': pendingDigest,
        'confirmedDigest': confirmedDigest,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (mounted) setState(() => status = 'Черновик сохранён');
  }

  Future<void> publish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (title.text.trim().isEmpty || refs.isEmpty) {
        throw const FormatException('COURSE_INCOMPLETE');
      }
      final d = digest22(value());
      if (d == confirmedDigest) {
        setState(() => status = 'Эта редакция уже подтверждена сервером');
        return;
      }
      if (pendingDigest != d) {
        requestId = newId();
        pendingDigest = d;
      }
      await save();
      final r = widget.controller.project22!,
          job = await r.call('project.catalogBatch', {
            'requestId': requestId,
            'changes': [
              {
                'contentId': id,
                'type': 'course',
                'action': 'publish',
                'expectedRevisionId': expectedRevision,
                'patch': {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                },
                'programRefs': refs,
              },
            ],
          });
      final done = await r.call('project.runOperation', {
        'operationId': job['operationId'],
      });
      if (done['state'] != 'SUCCEEDED' ||
          done['receipt']?['outcome'] != 'COMMITTED') {
        throw const FormatException('NOT_COMMITTED');
      }
      final receipt = await r.call('project.operationResult', {
        'operationId': job['operationId'],
      });
      if (digest22(receipt) != done['receipt']['preparedHash'] ||
          receipt['requestId'] != requestId) {
        throw const FormatException('RECEIPT_HASH');
      }
      expectedRevision = (receipt['changed'] as List).singleWhere(
        (r) => r['contentId'] == id,
      )['revisionId'];
      confirmedDigest = d;
      await save();
      if (mounted) {
        setState(
          () => status =
              'Опубликовано: подтверждены редакция и квитанция сервера',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Публикация не подтверждена. Черновик и запрос сохранены для повтора.',
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
      appBar: AppBar(title: const Text('Редактор курса')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('course22-title'),
            controller: title,
            decoration: const InputDecoration(labelText: 'Название курса'),
          ),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          DropdownButton<String>(
            hint: const Text('Добавить программу'),
            isExpanded: true,
            items: [
              for (final p in programs.where(
                (p) => !refs.any((r) => r['contentId'] == p['contentId']),
              ))
                DropdownMenuItem(
                  value: p['contentId'],
                  child: Text(p['title']),
                ),
            ],
            onChanged: busy
                ? null
                : (id) {
                    final p = programs.singleWhere((p) => p['contentId'] == id);
                    setState(
                      () => refs.add({
                        'contentId': p['contentId'],
                        'revisionId': p['revisionId'],
                        'sha256': p['sha256'],
                      }),
                    );
                  },
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: refs.length,
            onReorderItem: (a, b) => setState(() {
              final p = refs.removeAt(a);
              refs.insert(b, p);
            }),
            itemBuilder: (_, i) => ListTile(
              key: ValueKey(refs[i]['contentId']),
              title: Text(
                programs
                        .where((p) => p['contentId'] == refs[i]['contentId'])
                        .firstOrNull?['title'] ??
                    refs[i]['contentId'],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: busy ? null : () => setState(() => refs.removeAt(i)),
              ),
            ),
          ),
          Text(status, key: const Key('course22-status')),
          OutlinedButton(
            onPressed: busy ? null : save,
            child: const Text('Сохранить черновик'),
          ),
          FilledButton(
            onPressed: busy ? null : publish,
            child: const Text('Опубликовать курс'),
          ),
        ],
      ),
    );
  }
}
