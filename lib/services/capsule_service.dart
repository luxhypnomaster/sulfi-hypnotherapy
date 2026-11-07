import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import 'library_service.dart';

enum CapsuleConflictChoice { cancel, keepExisting, replace }

class CapsulePreview {
  CapsulePreview(
    this.manifest,
    this.staging,
    this.databaseToken,
    this.conflicts,
    this.alreadyImported,
  );
  final Map<String, dynamic> manifest;
  final Directory staging;
  final String databaseToken;
  final List<String> conflicts;
  final bool alreadyImported;
  Map<String, dynamic> get records => manifest['records'];
  String get id => manifest['id'];
  int get bytes =>
      (manifest['files'] as List).fold(0, (n, f) => n + (f['bytes'] as int));
  Map<String, int> get counts => {
    for (final e in records.entries) e.key: (e.value as List).length,
  };
  Future<void> close() async {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

/// One offline format and one transactional importer for full and selective
/// capsules. Neither the source media nor existing destination bytes are changed.
class CapsuleService {
  CapsuleService({
    required this.database,
    required this.library,
    required this.diaryDirectory,
    required this.workspace,
    this.availableBytes,
  });
  final Database database;
  final LibraryService library;
  final Directory diaryDirectory, workspace;
  final Future<int> Function()? availableBytes;
  static const schema = 1;
  static const tables = [
    'audio_assets',
    'module_definitions',
    'session_templates',
    'current_draft',
    'session_runs',
    'run_events',
    'app_counters',
    'diary_author',
    'diary_public',
    'diary_removed',
  ];
  // Limits are checked BEFORE decompression; file streams avoid loading audio
  // into one Dart Uint8List. 4 GiB is the explicit format limit for this edition.
  static const maxBytes = 4 * 1024 * 1024 * 1024;
  static const maxManifest = 32 * 1024 * 1024;
  static String canonical(Object? v) {
    Object? sorted(Object? x) => x is Map
        ? {
            for (final k in x.keys.map((k) => k.toString()).toList()..sort())
              k: sorted(x[k]),
          }
        : x is List
        ? x.map(sorted).toList()
        : x;
    return jsonEncode(sorted(v));
  }

  static String digest(Object? v) =>
      sha256.convert(utf8.encode(canonical(v))).toString();
  Future<Map<String, dynamic>> _records() async {
    final result = <String, dynamic>{};
    await database.transaction((tx) async {
      for (final table in tables) {
        result[table] = (await tx.query(table))
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    });
    return result;
  }

  Future<File> export({String? moduleId}) async {
    await workspace.create(recursive: true);
    final work = await workspace.createTemp('export-');
    final output = File(p.join(workspace.path, 'sulfi-${newId()}.zip'));
    try {
      final records = await _records();
      if (moduleId != null) {
        final modules = (records['module_definitions'] as List)
            .where((r) => r['id'] == moduleId)
            .toList();
        if (modules.length != 1) {
          throw const FormatException('Модуль не найден');
        }
        final definition = ModuleDefinition.fromMap(
          jsonDecode(modules.single['payload']),
        );
        final ids = definition.items
            .map((s) => s.audioAssetId)
            .whereType<String>()
            .toSet();
        for (final table in tables) {
          records[table] = table == 'module_definitions'
              ? modules
              : table == 'audio_assets'
              ? (records[table] as List)
                    .where((r) => ids.contains(r['id']))
                    .toList()
              : [];
        }
      }
      final files = <String, Map<String, dynamic>>{};
      Future<String> add(File file) async {
        if (!await file.exists()) {
          throw const FormatException(
            'Не найден файл для копии. Исходные данные сохранены.',
          );
        }
        final size = await file.length();
        final hash = (await sha256.bind(file.openRead()).first).toString();
        if (!files.containsKey(hash)) {
          final target = File(p.join(work.path, 'blobs', hash));
          await target.parent.create(recursive: true);
          await file.copy(target.path);
          if (await target.length() != size ||
              (await sha256.bind(target.openRead()).first).toString() != hash) {
            throw const FormatException('Файл изменился при создании копии');
          }
          files[hash] = {'path': 'blobs/$hash', 'sha256': hash, 'bytes': size};
        }
        return 'capsule://$hash';
      }

      for (final row in records['audio_assets'] as List) {
        final source = File(p.join(library.directory.path, row['filePath']));
        if (p.basename(row['filePath']) != row['filePath']) {
          throw const FormatException(
            'Внешний путь аудио: сначала восстановите доступ к оригиналу',
          );
        }
        row['filePath'] = await add(source);
        row['contentHash'] = (row['filePath'] as String).substring(10);
      }
      Future<Object?> portable(Object? v) async {
        if (v is List) return Future.wait(v.map(portable));
        if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          for (final key in m.keys.toList()) {
            if (key == 'localPath' && m[key] is String) {
              final file = File(m[key]);
              if (!p.isWithin(
                diaryDirectory.absolute.path,
                file.absolute.path,
              )) {
                throw const FormatException('Вложение вне хранилища дневника');
              }
              m[key] = await add(file);
            } else {
              m[key] = await portable(m[key]);
            }
          }
          return m;
        }
        return v;
      }

      for (final table in ['diary_author', 'diary_public']) {
        for (final row in records[table] as List) {
          row['payload'] = jsonEncode(
            await portable(jsonDecode(row['payload'])),
          );
        }
      }
      final dependencies = _dependencies(records);
      final manifest = <String, dynamic>{
        'format': 'sulfi-capsule',
        'schema': schema,
        'databaseSchema': 6,
        'scope': moduleId == null ? 'full' : 'module',
        'records': records,
        'files': files.values.toList(),
        'dependencies': dependencies,
      };
      manifest['id'] = digest(manifest);
      await File(p.join(work.path, 'manifest.json'))
          .writeAsString(jsonEncode(manifest), flush: true);
      if ((await File(p.join(work.path, 'manifest.json')).length()) >
          maxManifest) {
        throw const FormatException('Слишком большая копия');
      }
      final zip = ZipFileEncoder();
      await zip.zipDirectory(
        work,
        filename: output.path,
        level: 0,
        followLinks: false,
      );
      return output;
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    } finally {
      await work.delete(recursive: true);
    }
  }

  static List<String> _dependencies(Map<String, dynamic> records) {
    final ids = <String>{};
    void scan(Object? v) {
      if (v is List) {
        for (final x in v) {
          scan(x);
        }
      }
      if (v is Map) {
        if (v['audioAssetId'] is String) ids.add(v['audioAssetId']);
        for (final x in v.values) {
          scan(x);
        }
      }
    }

    for (final table in [
      'module_definitions',
      'session_templates',
      'current_draft',
      'session_runs',
    ]) {
      for (final row in records[table] as List) {
        scan(jsonDecode(row['payload']));
      }
    }
    return ids.toList()..sort();
  }

  Future<CapsulePreview> inspect(File zipFile) async {
    await workspace.create(recursive: true);
    final stage = await workspace.createTemp('restore-');
    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var total = 0;
      final names = <String>{};
      for (final f in archive) {
        if (!f.isFile && f.name == 'blobs/' && !f.isSymbolicLink) continue;
        if (f.isSymbolicLink ||
            !f.isFile ||
            !names.add(f.name) ||
            (f.name != 'manifest.json' &&
                !RegExp(r'^blobs/[a-f0-9]{64}$').hasMatch(f.name))) {
          throw const FormatException('Недопустимое содержимое ZIP');
        }
        total += f.size;
        if (f.size < 0 ||
            total > maxBytes ||
            (f.name == 'manifest.json' && f.size > maxManifest)) {
          throw const FormatException('Копия превышает лимит');
        }
      }
      if (availableBytes != null &&
          await availableBytes!() < total * 2 + 16 * 1024 * 1024) {
        throw const FormatException(
          'Недостаточно свободного места для безопасного восстановления',
        );
      }
      final mf = archive.findFile('manifest.json');
      if (mf == null) throw const FormatException('Нет manifest.json');
      final manifest = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(mf.content)),
      );
      final identity = Map<String, dynamic>.from(manifest)..remove('id');
      if (manifest['format'] != 'sulfi-capsule' ||
          manifest['schema'] != schema ||
          manifest['databaseSchema'] != 6 ||
          digest(identity) != manifest['id']) {
        throw const FormatException(
          'Неизвестная версия или повреждённый манифест',
        );
      }
      final records = Map<String, dynamic>.from(manifest['records']);
      if (records.keys.toSet().difference(tables.toSet()).isNotEmpty ||
          tables.any((t) => records[t] is! List)) {
        throw const FormatException('Некорректные таблицы');
      }
      final files = manifest['files'] as List;
      final hashes = <String>{};
      for (final f in files) {
        final hash = f['sha256'] as String;
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
            f['path'] != 'blobs/$hash' ||
            !hashes.add(hash)) {
          throw const FormatException('Некорректное описание файла');
        }
        final entry = archive.findFile(f['path']);
        if (entry == null || entry.size != f['bytes']) {
          throw const FormatException('Файл отсутствует или повреждён');
        }
        final target = File(p.join(stage.path, hash));
        final out = OutputFileStream(target.path);
        try {
          entry.writeContent(out);
        } finally {
          await out.close();
        }
        if (await target.length() != f['bytes'] ||
            (await sha256.bind(target.openRead()).first).toString() != hash) {
          throw const FormatException('Контрольная сумма файла не совпадает');
        }
      }
      if (names.length != hashes.length + 1) {
        throw const FormatException('Лишние файлы в копии');
      }
      final local = await _records();
      final available = {
        ...(local['audio_assets'] as List).map((r) => r['id']),
        ...(records['audio_assets'] as List).map((r) => r['id']),
      };
      final missing = _dependencies(records)
          .where((id) => !available.contains(id))
          .toList();
      if (missing.isNotEmpty) {
        throw FormatException(
          'Недостающие аудиозависимости: ${missing.join(', ')}',
        );
      }
      // Parse model documents and use destination column allowlists before any
      // mutation. Foreign JSON cannot inject SQL columns or absolute paths.
      for (final table in tables) {
        final columns = (await database.rawQuery('PRAGMA table_info($table)'))
            .map((r) => r['name'])
            .toSet();
        final seen = <Object?>{};
        for (final row in records[table] as List) {
          if (row is! Map || row.keys.toSet().difference(columns).isNotEmpty) {
            throw const FormatException('Некорректные поля');
          }
          if (table != 'run_events' &&
              !seen.add(row[table == 'app_counters' ? 'name' : 'id'])) {
            throw const FormatException('Повторяющийся идентификатор');
          }
          if (table == 'module_definitions') {
            ModuleDefinition.fromMap(jsonDecode(row['payload']));
          }
          if (table == 'session_templates') {
            SessionTemplate.fromMap(jsonDecode(row['payload']));
          }
          if (table == 'current_draft') {
            CurrentSessionDraft.fromMap(jsonDecode(row['payload']));
          }
          if (table == 'session_runs') {
            SessionRun.fromMap(jsonDecode(row['payload']));
          }
        }
      }
      final imported = (await database.query(
        'capsule_imports',
        where: 'id=?',
        whereArgs: [manifest['id']],
      )).isNotEmpty;
      final conflicts = <String>[];
      for (final table in tables.where(
        (t) => !['run_events', 'app_counters'].contains(t),
      )) {
        for (final row in records[table] as List) {
          final existing = (local[table] as List)
              .where((r) => r['id'] == row['id'])
              .firstOrNull;
          if (existing != null && !_same(table, existing, row)) {
            conflicts.add('$table · ${row['id']}');
          }
        }
      }
      return CapsulePreview(
        manifest,
        stage,
        digest(local),
        conflicts,
        imported,
      );
    } catch (_) {
      await stage.delete(recursive: true);
      rethrow;
    } finally {
      await input.close();
    }
  }

  static bool _same(String table, Map a, Map b) {
    Map normalized(Map row) {
      final r = Map<String, dynamic>.from(row);
      if (table == 'audio_assets') r.remove('filePath');
      if (table.startsWith('diary_') && r['payload'] is String) {
        Object? clean(Object? x) => x is List
            ? x.map(clean).toList()
            : x is Map
            ? {
                for (final e in x.entries)
                  if (e.key != 'localPath') e.key: clean(e.value),
              }
            : x;
        r['payload'] = clean(jsonDecode(r['payload']));
      }
      return r;
    }

    return canonical(normalized(a)) == canonical(normalized(b));
  }

  Future<void> restore(
    CapsulePreview preview, {
    CapsuleConflictChoice choice = CapsuleConflictChoice.cancel,
    Future<void> Function()? beforeCommit,
  }) async {
    if (preview.alreadyImported) return;
    if (preview.conflicts.isNotEmpty &&
        choice == CapsuleConflictChoice.cancel) {
      throw const FormatException('Восстановление отменено: есть конфликты');
    }
    final created = <File>[];
    try {
      final records =
          jsonDecode(jsonEncode(preview.records)) as Map<String, dynamic>;
      final local = await _records();
      if (digest(local) != preview.databaseToken) {
        throw const FormatException(
          'Данные изменились после проверки. Откройте копию заново.',
        );
      }
      Future<String> materialize(String uri, Directory dir, String ext) async {
        if (!RegExp(r'^capsule://[a-f0-9]{64}$').hasMatch(uri)) {
          throw const FormatException('Непереносимый путь в копии');
        }
        final source = File(p.join(preview.staging.path, uri.substring(10)));
        if (!await source.exists()) {
          throw const FormatException('Не найдено вложение');
        }
        await dir.create(recursive: true);
        final target = File(p.join(dir.path, 'asset_capsule_${newId()}.$ext'));
        created.add(target);
        await source.copy(target.path);
        if ((await sha256.bind(target.openRead()).first).toString() !=
            uri.substring(10)) {
          throw const FormatException('Ошибка записи восстановленного файла');
        }
        return target.path;
      }

      final skipped = <String, Set<Object?>>{};
      for (final table in tables) {
        skipped[table] = {};
        for (final row in records[table] as List) {
          final existing = (local[table] as List)
              .where((r) => r['id'] == row['id'])
              .firstOrNull;
          if (existing != null &&
              (_same(table, existing, row) ||
                  choice == CapsuleConflictChoice.keepExisting)) {
            skipped[table]!.add(row['id']);
          }
        }
      }
      for (final row in records['audio_assets'] as List) {
        if (skipped['audio_assets']!.contains(row['id'])) continue;
        if (!{'mp3', 'm4a', 'wav'}.contains(row['format'])) {
          throw const FormatException('Неизвестный формат аудио');
        }
        row['filePath'] = p.basename(
          await materialize(row['filePath'], library.directory, row['format']),
        );
      }
      Future<Object?> relocate(Object? x) async {
        if (x is List) return Future.wait(x.map(relocate));
        if (x is Map) {
          final m = Map<String, dynamic>.from(x);
          for (final k in m.keys.toList()) {
            if (k == 'localPath' && m[k] is String) {
              final ext = switch (m['mime']) {
                'image/jpeg' => 'jpg',
                'image/png' => 'png',
                'image/webp' => 'webp',
                'audio/mpeg' => 'mp3',
                'audio/wav' => 'wav',
                'audio/mp4' => 'm4a',
                _ => throw const FormatException('Неизвестное вложение'),
              };
              m[k] = await materialize(m[k], diaryDirectory, ext);
            } else {
              m[k] = await relocate(m[k]);
            }
          }
          return m;
        }
        return x;
      }

      for (final table in ['diary_author', 'diary_public']) {
        for (final row in records[table] as List) {
          if (!skipped[table]!.contains(row['id'])) {
            row['payload'] = jsonEncode(
              await relocate(jsonDecode(row['payload'])),
            );
          }
        }
      }
      await database.transaction((tx) async {
        // Detect concurrent writes again under the write transaction.
        final locked = <String, dynamic>{};
        for (final table in tables) {
          locked[table] = await tx.query(table);
        }
        if (digest(locked) != preview.databaseToken) {
          throw const FormatException(
            'Данные изменились; восстановление отменено',
          );
        }
        final active = await tx.query(
          'session_runs',
          where: 'status IN (?,?,?)',
          whereArgs: ['running', 'paused', 'exitingEarly'],
        );
        if (active.isNotEmpty) {
          throw const FormatException('Сначала завершите активную сессию');
        }
        for (final table in tables) {
          for (final row in records[table] as List) {
            if (table == 'run_events') {
              if (skipped['session_runs']!.contains(row['runId'])) continue;
              final event = Map<String, Object?>.from(row)..remove('id');
              await tx.insert(table, event);
              continue;
            }
            if (table == 'app_counters') continue;
            if (skipped[table]!.contains(row['id'])) continue;
            if (table == 'session_runs') {
              if ([
                'running',
                'paused',
                'exitingEarly',
              ].contains(row['status'])) {
                final payload = jsonDecode(row['payload']);
                payload['status'] = row['status'] = 'interrupted';
                payload['endedAt'] =
                    payload['lastCheckpointAt'] ?? payload['startedAt'];
                payload['endEstimated'] = true;
                row['payload'] = jsonEncode(payload);
              }
              await tx.delete(
                'run_events',
                where: 'runId=?',
                whereArgs: [row['id']],
              );
            }
            await tx.insert(
              table,
              Map<String, Object?>.from(row),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        final maxNumber =
            Sqflite.firstIntValue(
              await tx.rawQuery('SELECT MAX(displayNumber) FROM session_runs'),
            ) ??
            0;
        final counters = [
          ...local['app_counters'] as List,
          ...records['app_counters'] as List,
        ];
        final counter = counters.fold<int>(
          maxNumber,
          (n, r) =>
              r['name'] == 'session' && r['value'] > n ? r['value'] as int : n,
        );
        await tx.insert('app_counters', {
          'name': 'session',
          'value': counter,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await beforeCommit?.call();
        await tx.insert('capsule_imports', {
          'id': preview.id,
          'importedAt': DateTime.now().toUtc().toIso8601String(),
        });
      });
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }
}
