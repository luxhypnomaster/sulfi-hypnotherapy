import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/modular_plan.dart';
import '../models/content_revision.dart';
import '../data/content_revision_store.dart';
import '../models/session_plan.dart';
import '../models/audio_asset.dart';
import '../models/diary_entry.dart';
import 'history_attachments.dart';
import 'diary_media_store.dart';
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
    'history_attachments',
    'app_counters',
    'diary_author',
    'diary_public',
    'diary_removed',
    'content_revisions',
  ];
  // Limits are checked BEFORE decompression; file streams avoid loading audio
  // into one Dart Uint8List. 4 GiB is the explicit format limit for this edition.
  static const maxBytes = 4 * 1024 * 1024 * 1024;
  static const maxManifest = 32 * 1024 * 1024;

  /// Startup only, before any transfer. A killed process may leave staged bytes;
  /// committed media live in different directories and are never visited here.
  static Future<void> cleanWorkspace(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entry in dir.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (entry is Directory &&
          (name.startsWith('restore-') || name.startsWith('export-'))) {
        await entry.delete(recursive: true);
      }
      if (entry is File &&
          ((name.startsWith('sulfi-') && name.endsWith('.zip')) ||
              (name.startsWith('sulfi-legacy-') && name.endsWith('.part')))) {
        await entry.delete();
      }
    }
  }

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
  static void _validatePlan(SessionPlan plan) {
    final ids = plan.allSteps.map((s) => s.id).toList();
    if (ids.toSet().length != ids.length || ids.any((id) => id.isEmpty)) {
      throw const FormatException('Некорректные ID шагов');
    }
    for (final s in plan.allSteps) {
      if (s.delayBeforeSeconds < 0 ||
          s.delayBeforeSeconds > 5995 ||
          (s.durationMs ?? 0) < 0 ||
          (s.kind == StepKind.audio && s.audioAssetId == null)) {
        throw const FormatException('Некорректный шаг плана');
      }
    }
  }

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

  Future<File> export({
    String? moduleId,
    String? trackId,
    String? templateId,
  }) async {
    if ([moduleId, trackId, templateId].whereType<String>().length > 1) {
      throw ArgumentError("Выберите один материал");
    }
    await workspace.create(recursive: true);
    final work = await workspace.createTemp('export-');
    final output = File(p.join(workspace.path, 'sulfi-${newId()}.zip'));
    try {
      final records = await _records();
      if (moduleId != null || trackId != null || templateId != null) {
        final selectedModules = <Map<String, dynamic>>[];
        final selectedTemplates = <Map<String, dynamic>>[];
        final ids = <String>{?trackId};
        void audio(Iterable<SessionStep> steps) {
          ids.addAll(steps.map((s) => s.audioAssetId).whereType<String>());
        }

        if (moduleId != null) {
          final row = (records['module_definitions'] as List)
              .where((r) => r['id'] == moduleId)
              .firstOrNull;
          if (row == null) throw const FormatException('Модуль не найден');
          selectedModules.add(Map<String, dynamic>.from(row));
          audio(ModuleDefinition.fromMap(jsonDecode(row['payload'])).items);
        }
        if (templateId != null) {
          final row = (records['session_templates'] as List)
              .where((r) => r['id'] == templateId)
              .firstOrNull;
          if (row == null) throw const FormatException('Шаблон не найден');
          selectedTemplates.add(Map<String, dynamic>.from(row));
          final template = SessionTemplate.fromMap(jsonDecode(row['payload']));
          audio(template.plan.allSteps);
          for (final phase in template.plan.phases ?? <PhaseInstance>[]) {
            for (final child in phase.children.where((c) => c.isModule)) {
              final source = (records['module_definitions'] as List)
                  .where((r) => r['id'] == child.definitionId)
                  .firstOrNull;
              // Embedded copies remain exact snapshots. Never substitute latest
              // for an unavailable old source revision.
              if (source != null) {
                final module = ModuleDefinition.fromMap(
                  jsonDecode(source['payload']),
                );
                if (module.version == child.definitionVersion &&
                    !selectedModules.any((m) => m['id'] == module.id)) {
                  selectedModules.add(Map<String, dynamic>.from(source));
                  audio(module.items);
                }
              }
            }
          }
        }
        final selectedAudio = (records['audio_assets'] as List)
            .where((r) => ids.contains(r['id']))
            .toList();
        if (selectedAudio.length != ids.length) {
          throw const FormatException('Недостающие аудиозависимости');
        }
        for (final table in tables) {
          records[table] = switch (table) {
            'module_definitions' => selectedModules,
            'session_templates' => selectedTemplates,
            'audio_assets' => selectedAudio,
            _ => <dynamic>[],
          };
        }
      }
      final files = <String, Map<String, dynamic>>{};
      Future<String> add(File file, {String? expected}) async {
        if (!await file.exists()) {
          throw const FormatException(
            'Не найден файл для копии. Исходные данные сохранены.',
          );
        }
        final size = await file.length();
        final hash = (await sha256.bind(file.openRead()).first).toString();
        if (expected != null && hash != expected) {
          throw const FormatException(
            'Содержимое файла изменилось. Копия не создана; исходные данные сохранены.',
          );
        }
        if (!files.containsKey(hash)) {
          final retained = files.values.fold<int>(
            0,
            (n, f) => n + (f['bytes'] as int),
          );
          if (size + retained > maxBytes - maxManifest) {
            throw const FormatException('Копия больше лимита 4 ГБ');
          }
          if (availableBytes != null &&
              await availableBytes!() <
                  size * 2 + retained + 16 * 1024 * 1024) {
            throw const FormatException(
              'Недостаточно места для подготовки ZIP. Прежние данные сохранены.',
            );
          }
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
        row['filePath'] = await add(source, expected: row['contentHash']);
        row['contentHash'] = (row['filePath'] as String).substring(10);
      }
      var mediaRoot = diaryDirectory;
      Future<Object?> portable(Object? v) async {
        if (v is List) return Future.wait(v.map(portable));
        if (v is Map) {
          final m = Map<String, dynamic>.from(v);
          for (final key in m.keys.toList()) {
            if (key == 'localPath' && m[key] is String) {
              final file = File(m[key]);
              if (!p.isWithin(mediaRoot.absolute.path, file.absolute.path)) {
                throw const FormatException('Вложение вне хранилища дневника');
              }
              m[key] = await add(file, expected: m['hash']);
            } else {
              m[key] = await portable(m[key]);
            }
          }
          return m;
        }
        return v;
      }

      for (final table in [
        'diary_author',
        'diary_public',
        'history_attachments',
      ]) {
        mediaRoot = table == 'history_attachments'
            ? Directory(p.join(diaryDirectory.parent.path, 'history_media'))
            : diaryDirectory;
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
        'databaseSchema': 9,
        'scope': trackId != null
            ? 'track'
            : templateId != null
            ? 'template'
            : moduleId != null
            ? 'module'
            : 'full',
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
      zip.create(output.path, level: 0);
      try {
        await zip.addDirectory(work, includeDirName: false, followLinks: false);
      } finally {
        await zip.close();
      }
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
    ]) {
      for (final row in records[table] as List) {
        final payload = jsonDecode(row['payload']);
        if (table == 'module_definitions' && payload['archived'] == true) {
          continue;
        }
        scan(payload);
      }
    }
    return ids.toList()..sort();
  }

  Future<CapsulePreview> inspect(
    File zipFile, {
    bool Function()? cancelled,
  }) async {
    await workspace.create(recursive: true);
    final stage = await workspace.createTemp('restore-');
    InputFileStream? input;
    try {
      if (cancelled?.call() ?? false) {
        throw const FormatException('Восстановление отменено');
      }
      input = InputFileStream(zipFile.path);
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
          ![6, 7, 8, 9].contains(manifest['databaseSchema']) ||
          digest(identity) != manifest['id']) {
        throw const FormatException(
          'Неизвестная версия или повреждённый манифест',
        );
      }
      final records = Map<String, dynamic>.from(manifest['records']);
      if (manifest['databaseSchema'] < 9) {
        records.putIfAbsent('content_revisions', () => []);
      }
      if (manifest['databaseSchema'] < 8) {
        records.putIfAbsent('history_attachments', () => []);
      }
      if (records.keys.toSet().difference(tables.toSet()).isNotEmpty ||
          tables.any((t) => records[t] is! List)) {
        throw const FormatException('Некорректные таблицы');
      }
      // Integrity of the original manifest was verified before normalization.
      manifest['records'] = records;
      // This is not publisher authentication or a digital signature.
      // Add the v7 capability flag only in memory; IDs and media are unchanged.
      if (manifest['databaseSchema'] == 6) {
        for (final row in records['audio_assets'] as List) {
          row['authorManaged'] =
              row['origin'] == 'supplied' || row['section'] != 'personal'
              ? 1
              : 0;
        }
      }
      final files = manifest['files'] as List;
      final hashes = <String>{};
      for (final f in files) {
        if (cancelled?.call() ?? false) {
          throw const FormatException('Восстановление отменено');
        }
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
          if (table == 'content_revisions') {
            final revision = ContentRevision.fromMap(
              jsonDecode(row['payload']),
            );
            if (revision.key.token != row['id']) {
              throw const FormatException('Несогласованная ревизия');
            }
            try {
              final payload = revision.payload;
              if (payload['id'] != revision.key.content.id) {
                throw const FormatException('ID ревизии');
              }
              switch (revision.key.content.type) {
                case ContentType.track:
                  final asset = AudioAsset.fromMap({
                    ...payload,
                    'filePath': payload['filePath'] ?? 'unavailable',
                  });
                  if (payload['filePath'] != null &&
                      payload['filePath'] != 'capsule://${asset.contentHash}')
                    throw const FormatException('Путь аудиоревизии');
                  if (asset.contentHash != null &&
                      !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.contentHash!))
                    throw const FormatException('Хеш аудиоревизии');
                  if (asset.durationMs <= 0 ||
                      asset.fileSizeBytes <= 0 ||
                      !{'wav', 'm4a', 'mp3'}.contains(asset.format)) {
                    throw const FormatException('Аудиоревизия');
                  }
                case ContentType.module:
                  final module = ModuleDefinition.fromMap(payload);
                  _validatePlan(SessionPlan(steps: module.items));
                case ContentType.template:
                  _validatePlan(SessionTemplate.fromMap(payload).plan);
              }
            } catch (_) {
              throw const FormatException(
                'Некорректное содержимое сохранённой ревизии',
              );
            }
          }
          if (table == 'module_definitions') {
            final module = ModuleDefinition.fromMap(jsonDecode(row['payload']));
            _validatePlan(SessionPlan(steps: module.items));
            if (module.id != row['id']) {
              throw const FormatException('Несогласованный ID модуля');
            }
          }
          if (table == 'session_templates') {
            final template = SessionTemplate.fromMap(
              jsonDecode(row['payload']),
            );
            _validatePlan(template.plan);
            if (template.id != row['id']) {
              throw const FormatException('Несогласованный ID шаблона');
            }
          }
          if (table == 'current_draft') {
            _validatePlan(
              CurrentSessionDraft.fromMap(jsonDecode(row['payload'])).plan,
            );
            if (row['id'] != 1) {
              throw const FormatException('Некорректная текущая конфигурация');
            }
          }
          if (table == 'session_runs') {
            final run = SessionRun.fromMap(jsonDecode(row['payload']));
            _validatePlan(run.snapshot.plan);
            if (run.id != row['id'] ||
                run.displayNumber != row['displayNumber']) {
              throw const FormatException('Несогласованная история');
            }
          }
          if (table == 'audio_assets') {
            final asset = AudioAsset.fromMap(Map<String, Object?>.from(row));
            if (asset.contentHash == null ||
                row['filePath'] != 'capsule://${asset.contentHash}' ||
                !hashes.contains(asset.contentHash) ||
                asset.durationMs <= 0 ||
                asset.fileSizeBytes !=
                    (await File(p.join(stage.path, asset.contentHash!))
                        .length()) ||
                !{'mp3', 'm4a', 'wav'}.contains(asset.format)) {
              throw const FormatException('Неполное описание аудио');
            }
          }
          if (['diary_author', 'diary_public'].contains(table)) {
            final entry = DiaryEntry.fromMap(jsonDecode(row['payload']));
            if (entry.id != row['id']) {
              throw const FormatException('Несогласованный ID дневника');
            }
            for (final b in entry.blocks) {
              if (b.media?.localPath case final String path) {
                if (!path.startsWith('capsule://') ||
                    !hashes.contains(path.substring(10))) {
                  throw const FormatException(
                    'Непереносимое вложение дневника',
                  );
                }
              }
            }
          }
          if (table == 'history_attachments') {
            final a = HistoryAttachment.fromMap(jsonDecode(row['payload']));
            if (a.id != row['id'] ||
                a.runId != row['runId'] ||
                !(records['session_runs'] as List).any(
                  (r) => r['id'] == a.runId,
                )) {
              throw const FormatException('Несогласованное вложение истории');
            }
            final path = a.block.media?.localPath;
            if (a.block.type == DiaryBlockType.text) {
              throw const FormatException('Ожидается медиа');
            }
            if (path == null ||
                !path.startsWith('capsule://') ||
                !hashes.contains(path.substring(10))) {
              throw const FormatException('Нет файла вложения истории');
            }
          }
          if (table == 'history_attachments') {
            final a = HistoryAttachment.fromMap(jsonDecode(row['payload']));
            final media = a.block.media!;
            final file = File(
              p.join(stage.path, media.localPath!.substring(10)),
            );
            if (media.hash != media.localPath!.substring(10) ||
                await file.length() != media.bytes) {
              throw const FormatException('Размер вложения не совпадает');
            }
            final checker = DiaryMediaStore(
              Directory(p.join(stage.path, 'media-check')),
              pick: (_) async => null,
              probe: library.probe,
            );
            final checked = await checker.importFile(a.block.type, (
              name: 'attachment',
              path: file.path,
            ));
            if (checked.media!.mime != media.mime) {
              throw const FormatException('Тип вложения не совпадает');
            }
            await checker.directory.delete(recursive: true);
          }
          if (table == 'run_events' && jsonDecode(row['payload']) is! Map) {
            throw const FormatException('Некорректное событие');
          }
        }
      }
      final runIds = (records['session_runs'] as List)
          .map((r) => r['id'])
          .toSet();
      if ((records['run_events'] as List).any(
        (r) => !runIds.contains(r['runId']),
      )) {
        throw const FormatException('Событие без снимка сессии');
      }
      var requiredBytes = (records['audio_assets'] as List).fold<int>(
        0,
        (n, r) => n + (r['fileSizeBytes'] as int),
      );
      for (final table in [
        'diary_author',
        'diary_public',
        'history_attachments',
      ]) {
        for (final row in records[table] as List) {
          final blocks = table == 'history_attachments'
              ? [HistoryAttachment.fromMap(jsonDecode(row['payload'])).block]
              : DiaryEntry.fromMap(jsonDecode(row['payload'])).blocks;
          for (final block in blocks) {
            if (block.media?.localPath != null) {
              requiredBytes += block.media!.bytes;
            }
          }
        }
      }
      if (availableBytes != null &&
          await availableBytes!() < requiredBytes + 16 * 1024 * 1024) {
        throw const FormatException(
          'Недостаточно места для всех экземпляров восстановленных файлов',
        );
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
          if (existing != null && !await _matches(table, existing, row)) {
            final payload = row['payload'] == null
                ? null
                : jsonDecode(row['payload']);
            final name =
                row['title'] ??
                payload?['title'] ??
                payload?['name'] ??
                (table == 'current_draft' ? 'Текущий план' : row['id']);
            conflicts.add('$name · ${row['id']}');
          }
        }
      }
      final allPresent = tables
          .where((t) => !['run_events', 'app_counters'].contains(t))
          .every(
            (t) => (records[t] as List).every(
              (r) => (local[t] as List).any((l) => l['id'] == r['id']),
            ),
          );
      return CapsulePreview(
        manifest,
        stage,
        digest(local),
        conflicts,
        imported && allPresent && conflicts.isEmpty,
      );
    } catch (_) {
      await stage.delete(recursive: true);
      rethrow;
    } finally {
      await input?.close();
    }
  }

  static bool _same(String table, Map a, Map b) {
    Map normalized(Map row) {
      final r = Map<String, dynamic>.from(row);
      if (table == 'audio_assets') r.remove('filePath');
      if (table == 'content_revisions') r['payload'] = jsonDecode(r['payload']);
      if (table == 'session_runs') {
        r.remove('displayNumber');
        final payload = Map<String, dynamic>.from(jsonDecode(r['payload']));
        payload.remove('displayNumber');
        if (['running', 'paused', 'exitingEarly'].contains(r['status'])) {
          r['status'] = payload['status'] = 'interrupted';
          payload['endedAt'] =
              payload['lastCheckpointAt'] ?? payload['startedAt'];
          payload['endEstimated'] = true;
        }
        r['payload'] = payload;
      }
      if ((table.startsWith('diary_') || table == 'history_attachments') &&
          r['payload'] is String) {
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

  Future<bool> _matches(String table, Map a, Map b) async {
    if (!_same(table, a, b)) return false;
    Future<bool> intact(String path, String expected) async {
      try {
        final file = File(path);
        return await file.exists() &&
            (await sha256.bind(file.openRead()).first).toString() == expected;
      } catch (_) {
        return false;
      }
    }

    if (table == 'audio_assets') {
      if (p.basename(a['filePath']) != a['filePath']) return false;
      return intact(
        p.join(library.directory.path, a['filePath']),
        b['contentHash'],
      );
    }
    if (table == 'diary_author' ||
        table == 'diary_public' ||
        table == 'history_attachments') {
      Future<bool> walk(Object? local, Object? incoming) async {
        if (incoming is List && local is List) {
          for (var i = 0; i < incoming.length; i++) {
            if (!await walk(local[i], incoming[i])) return false;
          }
        }
        if (incoming is Map && local is Map) {
          for (final k in incoming.keys) {
            if (k == 'localPath' && incoming[k] is String) {
              if (local[k] is! String ||
                  !p.isWithin(
                    (table == 'history_attachments'
                            ? Directory(
                                p.join(
                                  diaryDirectory.parent.path,
                                  'history_media',
                                ),
                              )
                            : diaryDirectory)
                        .absolute
                        .path,
                    p.absolute(local[k]),
                  ) ||
                  !await intact(
                    local[k],
                    (incoming[k] as String).substring(10),
                  )) {
                return false;
              }
            } else if (!await walk(local[k], incoming[k])) {
              return false;
            }
          }
        }
        return true;
      }

      return walk(jsonDecode(a['payload']), jsonDecode(b['payload']));
    }
    return true;
  }

  Future<void> restore(
    CapsulePreview preview, {
    CapsuleConflictChoice choice = CapsuleConflictChoice.cancel,
    Future<void> Function()? beforeCommit,
    bool Function()? cancelled,
  }) async {
    void checkCancelled() {
      if (cancelled?.call() ?? false) {
        throw const FormatException(
          'Восстановление отменено. Прежние данные сохранены.',
        );
      }
    }

    checkCancelled();
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
        checkCancelled();
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
              (await _matches(table, existing, row) ||
                  choice == CapsuleConflictChoice.keepExisting)) {
            skipped[table]!.add(row['id']);
          }
        }
      }
      for (final row in records['audio_assets'] as List) {
        final previous = (local['audio_assets'] as List)
            .where((r) => r['id'] == row['id'])
            .firstOrNull;
        if (previous != null &&
            previous['contentHash'] != row['contentHash'] &&
            choice != CapsuleConflictChoice.keepExisting) {
          throw const FormatException(
            'Изменённые аудиобайты требуют нового ID. Прежние зависимости истории сохранены.',
          );
        }
        if (skipped['audio_assets']!.contains(row['id'])) continue;
        if (!{'mp3', 'm4a', 'wav'}.contains(row['format'])) {
          throw const FormatException('Неизвестный формат аудио');
        }
        row['filePath'] = p.basename(
          await materialize(row['filePath'], library.directory, row['format']),
        );
        final decoded = await library
            .probe(p.join(library.directory.path, row['filePath']))
            .timeout(const Duration(seconds: 30));
        if (decoded == null || decoded.inMilliseconds <= 0) {
          throw const FormatException('Восстановленное аудио не декодируется');
        }
      }
      var mediaDestination = diaryDirectory;
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
              m[k] = await materialize(m[k], mediaDestination, ext);
            } else {
              m[k] = await relocate(m[k]);
            }
          }
          return m;
        }
        return x;
      }

      for (final table in [
        'diary_author',
        'diary_public',
        'history_attachments',
      ]) {
        mediaDestination = table == 'history_attachments'
            ? Directory(p.join(diaryDirectory.parent.path, 'history_media'))
            : diaryDirectory;
        for (final row in records[table] as List) {
          if (!skipped[table]!.contains(row['id'])) {
            row['payload'] = jsonEncode(
              await relocate(jsonDecode(row['payload'])),
            );
          }
        }
      }
      await database.transaction((tx) async {
        checkCancelled();
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
            if (table == 'content_revisions') {
              await ContentRevisionStore(tx)
                  .put(ContentRevision.fromMap(jsonDecode(row['payload'])));
              continue;
            }
            if (const [
                  'audio_assets',
                  'module_definitions',
                  'session_templates',
                ].contains(table) &&
                !skipped[table]!.contains(row['id'])) {
              for (final old in (local[table] as List).where(
                (r) => r['id'] == row['id'],
              )) {
                await ContentRevisionStore.retainRow(
                  tx,
                  table,
                  Map<String, Object?>.from(old),
                );
              }
              await ContentRevisionStore.retainRow(
                tx,
                table,
                Map<String, Object?>.from(row),
              );
            }
            if (table == 'run_events') {
              if (skipped['session_runs']!.contains(row['runId'])) continue;
              final event = Map<String, Object?>.from(row)..remove('id');
              await tx.insert(table, event);
              continue;
            }
            if (table == 'history_attachments' &&
                skipped['session_runs']!.contains(row['runId']) &&
                !(local['session_runs'] as List).any(
                  (r) => r['id'] == row['runId'],
                )) {
              continue;
            }
            if (table == 'app_counters') continue;
            if (skipped[table]!.contains(row['id'])) continue;
            if (!library.policy.isAuthor &&
                const {
                  'audio_assets',
                  'module_definitions',
                  'session_templates',
                }.contains(table)) {
              final existing = await tx.query(
                table,
                where: 'id=?',
                whereArgs: [row['id']],
              );
              if (existing.isNotEmpty) {
                if (table == 'audio_assets') {
                  library.policy.requireAudio(
                    AudioAsset.fromMap(existing.single),
                  );
                } else {
                  final previous = jsonDecode(
                    existing.single['payload'] as String,
                  );
                  library.policy.requireOrigin(
                    previous['origin'] as String? ?? 'personal',
                  );
                }
              }
            }
            if (table == 'session_runs') {
              final occupied = await tx.query(
                'session_runs',
                where: 'displayNumber=? AND id<>?',
                whereArgs: [row['displayNumber'], row['id']],
              );
              if (occupied.isNotEmpty) {
                final number =
                    (Sqflite.firstIntValue(
                          await tx.rawQuery(
                            'SELECT MAX(displayNumber) FROM session_runs',
                          ),
                        ) ??
                        0) +
                    1;
                final payload = jsonDecode(row['payload']);
                payload['displayNumber'] = row['displayNumber'] = number;
                row['payload'] = jsonEncode(payload);
              }
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
            if (table == 'session_runs' &&
                (locked[table] as List).any((r) => r['id'] == row['id'])) {
              await tx.update(
                table,
                Map<String, Object?>.from(row),
                where: 'id=?',
                whereArgs: [row['id']],
              );
              continue;
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
        checkCancelled();
        await tx.insert('capsule_imports', {
          'id': preview.id,
          'importedAt': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }
}
