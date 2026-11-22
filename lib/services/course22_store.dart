import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/ratings22.dart';
import '../models/session_plan.dart';

enum Rubedo22 { gray, red, fuchsia, green }

/// Course is ordered references, not copies of templates/media. All installation
/// is delegated to the existing selective importer/queue by caller.
class Course22Store {
  Course22Store(this.db, {required this.owner});
  final Database db;
  final String? Function() owner;
  String _key(String id) => 'course22:${digest22([owner(), id])}';
  Future<Map<String, dynamic>?> load(String id) async {
    final a = owner(),
        r = await db.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [_key(id)],
        );
    if (a != owner() || r.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(r.single['value'] as String));
  }

  Future<void> installDefinition(Map<String, dynamic> definition) async {
    final refs = definition['programs'];
    if (definition['contentId'] is! String ||
        definition['revisionId'] is! String ||
        refs is! List ||
        refs.isEmpty ||
        refs.length > 200 ||
        refs.any(
          (r) =>
              r['contentId'] is! String ||
              r['revisionId'] is! String ||
              r['sha256'] is! String,
        )) {
      throw const FormatException('COURSE_SCHEMA');
    }
    final a = owner(), old = await load(definition['contentId']);
    if (old != null &&
        old['definition']['revisionId'] != definition['revisionId']) {
      throw const FormatException('COURSE_REVISION_REQUIRES_NEW_RUN');
    }
    final hash = digest22(definition);
    if (old != null && old['hash'] != hash) {
      throw const FormatException('IMMUTABLE_COURSE_CONFLICT');
    }
    await db.transaction((tx) async {
      if (a != owner()) throw const FormatException('ACCOUNT_CHANGED');
      await tx.insert('app_settings', {
        'name': _key(definition['contentId']),
        'value': jsonEncode(
          old ??
              {
                'definition': definition,
                'hash': hash,
                'cursor': 0,
                'completed': <String>[],
              },
        ),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> markDeleted(String programId) => db
      .insert('app_settings', {
        'name': 'official22_deleted:${digest22([owner(), programId])}',
        'value': jsonEncode({'programId': programId, 'deleted': true}),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<bool> mayAutoInstall(
    String programId, {
    required bool userCreated,
  }) async =>
      !userCreated &&
      (await db.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [
          'official22_deleted:${digest22([owner(), programId])}',
        ],
      )).isEmpty;
  Rubedo22 state(
    Map<String, dynamic> course,
    Map<String, Map<String, dynamic>> readiness,
  ) {
    final refs = course['definition']['programs'] as List,
        cursor = course['cursor'] as int;
    if (cursor >= refs.length) return Rubedo22.green;
    final r = readiness[refs[cursor]['contentId']];
    if (r?['entitled'] == true &&
        r?['verified'] == true &&
        r?['revisionId'] == refs[cursor]['revisionId']) {
      return Rubedo22.fuchsia;
    }
    return r?['downloading'] == true ? Rubedo22.red : Rubedo22.gray;
  }

  Map<String, dynamic>? current(
    Map<String, dynamic> course,
    Map<String, Map<String, dynamic>> readiness,
  ) => state(course, readiness) != Rubedo22.fuchsia
      ? null
      : Map<String, dynamic>.from(
          course['definition']['programs'][course['cursor']],
        );
  Future<void> complete(String id, String programId, SessionRun run) async {
    if (run.status != RunStatus.completed) return;
    final a = owner();
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [_key(id)],
      );
      if (rows.isEmpty || a != owner()) {
        throw const FormatException('COURSE_SCOPE');
      }
      final c = Map<String, dynamic>.from(
        jsonDecode(rows.single['value'] as String),
      );
      final refs = c['definition']['programs'] as List,
          cursor = c['cursor'] as int;
      if ((c['completed'] as List).contains(run.id)) return;
      if (cursor >= refs.length ||
          refs[cursor]['contentId'] != programId ||
          run.snapshot.baseTemplateId != programId) {
        throw const FormatException('COURSE_CURSOR_CONFLICT');
      }
      c['cursor'] = cursor + 1;
      c['completed'] = [...c['completed'], run.id];
      await tx.insert('app_settings', {
        'name': _key(id),
        'value': jsonEncode(c),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Dry-run planning never mutates a personal fork or a frozen SessionRun.
  List<Map<String, dynamic>> officialUpdatePlan(
    List<Map<String, dynamic>> installed,
    List<Map<String, dynamic>> current,
  ) => [
    for (final local in installed)
      if (local['origin'] == 'official' && local['userCreated'] != true)
        for (final remote in current)
          if (local['contentId'] == remote['contentId'] &&
              local['revisionId'] != remote['revisionId'])
            {
              'contentId': local['contentId'],
              'from': local['revisionId'],
              'to': remote['revisionId'],
              'requiresVerifiedSelectiveInstall': true,
            },
  ];
}
