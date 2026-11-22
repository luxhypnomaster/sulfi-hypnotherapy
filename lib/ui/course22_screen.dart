import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import '../models/ratings22.dart';
import '../services/course22_store.dart';
import '../services/session_controller.dart';
import '../services/session_engine.dart';
import '../services/session_transport.dart';
import '../services/session_audio_handler.dart';
import 'run_screen.dart';
import 'feedback22_screen.dart';
import 'session_scope.dart';

class Course22Screen extends StatefulWidget {
  const Course22Screen({
    super.key,
    required this.controller,
    required this.contentId,
  });
  final SessionController controller;
  final String contentId;
  @override
  State<Course22Screen> createState() => _Course22ScreenState();
}

class _Course22ScreenState extends State<Course22Screen> {
  SessionController get c => widget.controller;
  late final owner = c.transferOwner;
  late final store = Course22Store(
    c.capsules!.database,
    owner: () => c.transferOwner,
  );
  Map<String, dynamic>? course;
  Map<String, Map<String, dynamic>> access = {}, ready = {};
  String? error;
  bool busy = false;
  String get accessKey =>
      'course22_access:${digest22([owner, widget.contentId])}';
  @override
  void initState() {
    super.initState();
    c.cloudQueue.addListener(changed);
    load();
  }

  @override
  void dispose() {
    c.cloudQueue.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void check() {
    if (owner != c.transferOwner) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      check();
      course = await store.load(widget.contentId);
      try {
        final remote = await c.project22!.call('project.course', {
          'contentId': widget.contentId,
        });
        check();
        await store.installDefinition(
          Map<String, dynamic>.from(remote['definition']),
        );
        access = {
          for (final p in remote['programs'])
            p['contentId']: Map<String, dynamic>.from(p),
        };
        await c.capsules!.database.insert('app_settings', {
          'name': accessKey,
          'value': jsonEncode(access),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        course = await store.load(widget.contentId);
        error = null;
      } catch (_) {
        check();
        final rows = await c.capsules!.database.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [accessKey],
        );
        if (rows.isNotEmpty) {
          access = Map<String, dynamic>.from(
            jsonDecode(rows.single['value'] as String),
          ).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
        }
        error = 'Сервер не обновлён; показана сохранённая копия.';
      }
      await c.reload();
      check();
      ready = {};
      for (final ref in course?['definition']?['programs'] as List? ?? []) {
        final id = ref['contentId'] as String,
            t = c.templates.where((t) => t.id == id).firstOrNull,
            card = access[id]?['card'];
        final receipts = card == null
            ? <Map<String, Object?>>[]
            : await c.capsules!.database.query(
                'app_settings',
                where: 'name=?',
                whereArgs: ['alchemist_installed:${card['catalogItemId']}'],
              );
        var verified =
            t != null &&
            receipts.isNotEmpty &&
            jsonDecode(
                  receipts.single['value'] as String,
                )['immutableRevisionId'] ==
                ref['revisionId'];
        if (t != null) {
          for (final s in t.plan.steps.where((s) => s.kind == StepKind.audio)) {
            final asset = c.asset(s.audioAssetId);
            if (asset == null) {
              verified = false;
              break;
            }
            final file = c.library.fileFor(asset);
            if (asset.contentHash == null ||
                !await file.exists() ||
                (await sha256.bind(file.openRead()).first).toString() !=
                    asset.contentHash) {
              verified = false;
              break;
            }
          }
        }
        check();
        ready[id] = {
          'entitled': access[id]?['entitled'] == true,
          'verified': verified,
          'revisionId': ref['revisionId'],
          'downloading': c.cloudQueue.rows.any(
            (r) =>
                r['download']?['kind'] == 'install' &&
                r['download']['card']['logicalContentId'] == id &&
                [
                  'queued',
                  'running',
                  'preparing',
                ].contains(r['_work']['phase']),
          ),
        };
      }
    } catch (_) {
      course = null;
      ready = {};
      error = 'Готовность курса не подтверждена. Исходные программы и история сохранены.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> download() async {
    if (course == null) return;
    setState(() => busy = true);
    try {
      check();
      for (final ref in (course!['definition']['programs'] as List).skip(
        course!['cursor'] as int,
      )) {
        final id = ref['contentId'] as String;
        if (ready[id]?['verified'] == true) continue;
        if (access[id]?['entitled'] != true ||
            !await store.mayAutoInstall(id, userCreated: false)) {
          break;
        }
        final card = access[id]?['card'];
        if (card == null) break;
        check();
        await c.installInBackground(Map<String, dynamic>.from(card));
        break;
      }
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Установка не подтверждена. Очередь сохранена.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() async {
    check();
    final ref = store.current(course!, ready);
    if (ref == null) return;
    final t = c.templates.where((t) => t.id == ref['contentId']).firstOrNull;
    if (t == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Начать «${t.name}»?'),
        content: const Text(
          'Программа будет загружена в текущую конфигурацию. Состав начатой сессии фиксируется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Начать'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    SessionEngine? engine;
    try {
      check();
      await (SessionScope.maybeOf(context)?.player ?? c.preview)?.stop();
      await c.loadTemplate(t);
      check();
      engine = sessionAudioHandler != null
          ? await sessionAudioHandler!.startSession()
          : SessionEngine(
              controller: c,
              transport: JustAudioSessionTransport(),
            );
      if (sessionAudioHandler == null) await engine.start();
      await store.bindExecution(
        widget.contentId,
        ref['contentId'],
        engine.run!,
      );
      if (!mounted) return;
      await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => RunScreen(engine: engine!)),
      );
      check();
      final run = engine.run;
      if (run != null) {
        await store.complete(widget.contentId, ref['contentId'], run);
        if (mounted &&
            run.status == RunStatus.completed &&
            c.feedback22 != null) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => Feedback22Screen(store: c.feedback22!, run: run),
            ),
          );
        }
      }
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Переход не подтверждён. Курсор не пропускает следующую программу.',
        );
      }
    } finally {
      if (engine != null && sessionAudioHandler?.engine != engine) {
        await engine.close();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review() async {
    check();
    if (course == null || c.feedback22 == null) return;
    final definition = course!['definition'],
        bindings = Map<String, dynamic>.from(course!['bindings'] ?? {}),
        runs = c.runs.where((r) => bindings.containsKey(r.id)).toList();
    if (runs.isEmpty) {
      setState(() => error = 'Отзыв доступен после начала программы курса.');
      return;
    }
    final occurrences = <Map<String, dynamic>>[];
    for (final ref in definition['programs']) {
      final epoch = access[ref['contentId']]?['ratingEpochId'];
      if (epoch is! String) continue;
      for (final run in runs.where(
        (r) => r.snapshot.baseTemplateId == ref['contentId'],
      )) {
        final rows = await c.capsules!.database.query(
          'app_settings',
          where: 'name=?',
          whereArgs: ['playback22:${run.id}'],
        );
        final data = rows.isEmpty
                ? null
                : jsonDecode(rows.single['value'] as String),
            valid = data?['manifestHash'] == bindings[run.id]['manifestHash'];
        final duration = run.snapshot.plan.steps
            .where((s) => s.kind == StepKind.audio)
            .fold<int>(0, (a, s) => a + (s.durationMs ?? 0));
        final intervals = valid
            ? data['intervals'] as Map
            : <String, dynamic>{};
        final played = intervals.values.fold<int>(
          0,
          (n, ranges) =>
              n +
              (ranges as List).fold<int>(
                0,
                (a, r) => a + (r[1] as int) - (r[0] as int),
              ),
        );
        occurrences.add({
          'occurrenceId': run.id,
          'target': {
            'type': 'PROGRAM',
            'contentId': ref['contentId'],
            'revisionId': bindings[run.id]['programRevision'],
            'ratingEpochId': epoch,
          },
          'status': !valid
              ? 'UNKNOWN'
              : played == 0
              ? 'NOT_EXPOSED'
              : played == duration && duration > 0
              ? 'COMPLETED'
              : 'PARTIAL',
          'playedMs': played,
          'durationMs': duration,
        });
      }
    }
    check();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Feedback22Screen(
          store: c.feedback22!,
          run: runs.first,
          recordKey:
              'course:${definition['contentId']}:${definition['revisionId']}',
          title: definition['title'],
          exactTarget: {
            'type': 'COURSE',
            'contentId': definition['contentId'],
            'revisionId': definition['revisionId'],
            'ratingEpochId': definition['ratingEpochId'] ?? 'local-unresolved',
          },
          execution: {
            'executionId':
                'course-${digest22([definition, runs.map((r) => r.id).toList()])}',
            'manifestHash': digest22({
              'course': definition,
              'executions': runs
                  .map((r) => {'id': r.id, 'manifest': r.snapshot.plan.toMap()})
                  .toList(),
            }),
            'partialExecution':
                store.state(course!, ready) != Rubedo22.green ||
                occurrences.any((o) => o['status'] != 'COMPLETED'),
          },
          occurrences: occurrences,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (owner != c.transferOwner) {
      return const Scaffold(body: Center(child: Text('Аккаунт изменён')));
    }
    final state = course == null ? Rubedo22.gray : store.state(course!, ready),
        color = switch (state) {
          Rubedo22.gray => Colors.grey,
          Rubedo22.red => const Color(0xffff2868),
          Rubedo22.fuchsia => const Color(0xffff00aa),
          Rubedo22.green => Colors.greenAccent,
        };
    return Scaffold(
      appBar: AppBar(
        title: Text(course?['definition']?['title'] ?? 'Курс'),
        actions: [
          IconButton(
            tooltip: 'Обновить готовность',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) Text(error!),
          Text(switch (state) {
            Rubedo22.gray => 'Следующая программа не готова',
            Rubedo22.red => 'Следующая программа передаётся или проверяется',
            Rubedo22.fuchsia => 'Следующая программа готова',
            Rubedo22.green => 'Курс завершён',
          }, style: TextStyle(color: color)),
          for (final ref in course?['definition']?['programs'] as List? ?? [])
            ListTile(
              title: Text(
                access[ref['contentId']]?['card']?['card']?['title'] ??
                    ref['contentId'],
              ),
              subtitle: Text(
                'Редакция ${ref['revisionId']} · ${ready[ref['contentId']]?['verified'] == true ? 'файлы проверены' : 'не готово'}',
              ),
            ),
          FilledButton(
            onPressed: busy || state != Rubedo22.fuchsia ? null : start,
            child: const Text('Начать программу'),
          ),
          OutlinedButton(
            onPressed: busy || course == null ? null : download,
            child: const Text('Установить следующую программу'),
          ),
          TextButton(
            onPressed: busy || course == null ? null : review,
            child: const Text('Оценить курс — необязательно'),
          ),
        ],
      ),
    );
  }
}
