import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/content_revision.dart';
import '../data/content_revision_store.dart';
import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import 'capsule_service.dart';

class ResolvedContent {
  ResolvedContent(this.revisions);
  final List<ContentRevision> revisions;
}

/// Exact references only. A second revision of one logical object in one plan is
/// a conflict, never a request to silently choose "latest".
ResolvedContent resolveContent(
  RevisionKey root,
  Iterable<ContentRevision> catalog,
) {
  final byKey = <String, ContentRevision>{};
  for (final r in catalog) {
    if (byKey.containsKey(r.key.token) &&
        byKey[r.key.token]!.key.digest != r.key.digest) {
      throw const FormatException('Конфликт digest каталога');
    }
    byKey[r.key.token] = r;
  }
  final visiting = <String>{}, visited = <String>{};
  final versions = <String, String>{};
  final order = <ContentRevision>[];
  void visit(RevisionKey key) {
    final revision = byKey[key.token];
    if (revision == null || revision.key.digest != key.digest) {
      throw const FormatException('Точная зависимость недоступна');
    }
    if (visiting.contains(key.token)) {
      throw const FormatException('Цикл зависимостей');
    }
    final prior = versions[key.content.token];
    if (prior != null && prior != key.revision) {
      throw const FormatException('Несовместимые ревизии одного материала');
    }
    versions[key.content.token] = key.revision;
    if (visited.contains(key.token)) return;
    visiting.add(key.token);
    for (final dependency in revision.dependencies) {
      visit(dependency);
    }
    visiting.remove(key.token);
    visited.add(key.token);
    order.add(revision);
  }

  visit(root);
  return ResolvedContent(List.unmodifiable(order));
}

class ContentInstallPlan {
  ContentInstallPlan(
    this.closure,
    this.newBytes,
    this.missingDigests, {
    this.stagingBytes = 0,
    this.physicalWriteBytes = 0,
    this.reserveBytes = 16 * 1024 * 1024,
  });
  final ResolvedContent closure;
  final int newBytes;
  final int stagingBytes, physicalWriteBytes, reserveBytes;
  int get requiredFreeBytes => stagingBytes + physicalWriteBytes + reserveBytes;
  final Set<String> missingDigests;
}

enum ContentInstallState {
  planned,
  staging,
  verifying,
  committing,
  installed,
  failed,
  cancelled,
}

/// A user-selected local capsule is the real offline source. Opening it indexes
/// cards without adding anything to the library. No remote availability claims.
class LocalCatalogSource {
  LocalCatalogSource._(this.service, this.preview, this.revisions);
  final CapsuleService service;
  final CapsulePreview preview;
  final List<ContentRevision> revisions;
  static Future<LocalCatalogSource> open(
    CapsuleService service,
    File file,
  ) async {
    final preview = await service.inspect(file);
    try {
      final revisions = indexRecords(preview.records);
      return LocalCatalogSource._(
        service,
        preview,
        List.unmodifiable(revisions),
      );
    } catch (_) {
      await preview.close();
      rethrow;
    }
  }

  /// Same canonical dependency index used by ZIP and author ContentLink picker.
  static List<ContentRevision> indexRecords(Map<String, dynamic> records) {
    final revisions = <ContentRevision>[];
    final tracks = <String, ContentRevision>{},
        modules = <String, ContentRevision>{};
    for (final row in records['audio_assets'] as List) {
      final r = ContentRevision.create(
        ContentKey(ContentType.track, row['id']),
        Map<String, dynamic>.from(row),
        declaredVersion: row['baseRevision'],
      );
      tracks[row['id']] = r;
      revisions.add(r);
    }
    List<RevisionKey> audio(Iterable<SessionStep> steps) =>
        steps.map((s) => s.audioAssetId).whereType<String>().toSet().map((id) {
          final r = tracks[id];
          if (r == null) throw const FormatException('Нет точного аудио');
          return r.key;
        }).toList();
    for (final row in records['module_definitions'] as List) {
      final m = ModuleDefinition.fromMap(jsonDecode(row['payload']));
      final r = ContentRevision.create(
        ContentKey(ContentType.module, m.id),
        m.toMap(),
        dependencies: audio(m.items),
        parent: m.parentRevision,
        declaredVersion: m.version,
      );
      modules[m.id] = r;
      revisions.add(r);
    }
    for (final row in records['session_templates'] as List) {
      final t = SessionTemplate.fromMap(jsonDecode(row['payload']));
      final dependencies = <String, RevisionKey>{
        for (final k in audio(t.plan.allSteps)) k.token: k,
      };
      for (final phase in t.plan.phases ?? <PhaseInstance>[]) {
        for (final child in phase.children) {
          final m = modules[child.definitionId];
          if (m != null && m.declaredVersion == child.definitionVersion) {
            dependencies[m.key.token] = m.key;
          }
        }
      }
      revisions.add(
        ContentRevision.create(
          ContentKey(ContentType.template, t.id),
          t.toMap(),
          dependencies: dependencies.values.toList(),
          parent: t.parentRevision,
          declaredVersion: t.version,
        ),
      );
    }
    return List.unmodifiable(revisions);
  }

  static Future<List<ContentRevision>> currentIndex(
    CapsuleService service,
  ) async {
    final records = <String, dynamic>{};
    for (final table in [
      'audio_assets',
      'module_definitions',
      'session_templates',
    ]) {
      records[table] = (await service.database.query(table))
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    for (final row in records['audio_assets'] as List) {
      if (row['contentHash'] == null) {
        throw const FormatException(
          'Для точной ссылки требуется проверенный SHA аудио',
        );
      }
      row['filePath'] = 'capsule://${row['contentHash']}';
    }
    return indexRecords(records);
  }

  Future<void> close() => preview.close();

  static String table(ContentType type) => switch (type) {
    ContentType.track => 'audio_assets',
    ContentType.module => 'module_definitions',
    ContentType.template => 'session_templates',
  };
  Future<bool> installed(ContentRevision r) => installedRevision(service, r);
  static Future<bool> installedRevision(
    CapsuleService service,
    ContentRevision r, {
    Set<String>? visiting,
  }) async {
    visiting ??= <String>{};
    if (!visiting.add(r.key.token)) return false;
    for (final key in r.dependencies) {
      final dependency = await ContentRevisionStore(service.database).get(key);
      if (dependency == null ||
          !await installedRevision(
            service,
            dependency,
            visiting: {...visiting},
          )) {
        return false;
      }
    }
    final rows = await service.database.query(
      table(r.key.content.type),
      where: 'id=?',
      whereArgs: [r.key.content.id],
    );
    if (rows.isEmpty) return false;
    final payload = r.key.content.type == ContentType.track
        ? Map<String, dynamic>.from(rows.single)
        : Map<String, dynamic>.from(
            jsonDecode(rows.single['payload'] as String),
          );
    if (r.key.content.type == ContentType.track) {
      final name = payload['filePath'];
      if (name is! String || p.basename(name) != name) return false;
      final file = File(p.join(service.library.directory.path, name));
      if (!await file.exists() ||
          await file.length() != r.payload['fileSizeBytes'] ||
          (await sha256.bind(file.openRead()).first).toString() !=
              r.payload['contentHash']) {
        return false;
      }
      payload['filePath'] = 'capsule://${payload['contentHash']}';
    }
    return canonicalContent(payload) == canonicalContent(r.payload);
  }

  Future<ContentInstallPlan> plan(RevisionKey root) async {
    final closure = resolveContent(root, revisions);
    final missing = <String>{};
    final sizes = <String, int>{};
    final availableHashes = <String>{};
    for (final asset in await service.library.repository.list()) {
      try {
        final file = service.library.fileFor(asset);
        if (!await file.exists()) continue;
        final hash = (await sha256.bind(file.openRead()).first).toString();
        if (asset.contentHash == null || asset.contentHash == hash) {
          availableHashes.add(hash);
        }
      } catch (_) {
        /* Unreadable/corrupt files cannot count as reusable. */
      }
    }
    var physicalWriteBytes = 0;
    for (final r in closure.revisions.where(
      (r) => r.key.content.type == ContentType.track,
    )) {
      final hash = r.payload['contentHash'] as String;
      sizes[hash] = r.payload['fileSizeBytes'];
      if (!availableHashes.contains(hash)) missing.add(hash);
      if (!await installed(r)) {
        physicalWriteBytes += r.payload['fileSizeBytes'] as int;
      }
    }
    return ContentInstallPlan(
      closure,
      missing.fold<int>(0, (n, h) => n + sizes[h]!),
      Set.unmodifiable(missing),
      stagingBytes: sizes.values.fold<int>(0, (n, size) => n + size) * 2,
      physicalWriteBytes: physicalWriteBytes,
    );
  }

  Future<void> install(
    ContentInstallPlan plan, {
    bool Function()? cancelled,
    void Function(ContentInstallState)? onState,
    Future<void> Function()? beforeCommit,
  }) async {
    void check() {
      if (cancelled?.call() ?? false) {
        throw const FormatException('Установка отменена');
      }
    }

    File? zipFile;
    CapsulePreview? staged;
    try {
      onState?.call(ContentInstallState.planned);
      check();
      // Fresh resolution prevents callers from fabricating a dependency closure.
      final actual = resolveContent(plan.closure.revisions.last.key, revisions);
      final records = <String, dynamic>{
        for (final t in CapsuleService.tables) t: <dynamic>[],
      };
      final hashes = <String>{};
      for (final r in actual.revisions) {
        final t = table(r.key.content.type);
        records[t].add(
          r.key.content.type == ContentType.track
              ? Map<String, dynamic>.from(r.payload)
              : {'id': r.key.content.id, 'payload': jsonEncode(r.payload)},
        );
        records['content_revisions'].add({
          'id': r.key.token,
          'payload': jsonEncode(r.toMap()),
        });
        if (r.key.content.type == ContentType.track) {
          hashes.add(r.payload['contentHash'] as String);
        }
      }
      final files = (preview.manifest['files'] as List)
          .where((f) => hashes.contains(f['sha256']))
          .toList();
      final manifest = <String, dynamic>{
        'format': 'sulfi-capsule',
        'schema': CapsuleService.schema,
        'databaseSchema': 9,
        'scope': 'catalog-selection',
        'records': records,
        'files': files,
        'dependencies':
            actual.revisions
                .where((r) => r.key.content.type == ContentType.track)
                .map((r) => r.key.content.id)
                .toList()
              ..sort(),
      };
      manifest['id'] = CapsuleService.digest(manifest);
      onState?.call(ContentInstallState.staging);
      check();
      final freshPlan = await this.plan(actual.revisions.last.key);
      final required = freshPlan.requiredFreeBytes;
      if (service.availableBytes != null &&
          await service.availableBytes!() < required) {
        throw const FormatException(
          'Недостаточно места. Установка не началась.',
        );
      }
      final stage = await service.workspace.createTemp('export-');
      try {
        await File(p.join(stage.path, 'manifest.json'))
            .writeAsString(jsonEncode(manifest));
        for (final f in files) {
          check();
          final target = File(p.join(stage.path, f['path']));
          await target.parent.create(recursive: true);
          await File(p.join(preview.staging.path, f['sha256']))
              .copy(target.path);
        }
        zipFile = File(p.join(service.workspace.path, 'sulfi-${newId()}.zip'));
        final encoder = ZipFileEncoder();
        encoder.create(zipFile.path, level: 0);
        try {
          await encoder.addDirectory(
            stage,
            includeDirName: false,
            followLinks: false,
          );
        } finally {
          await encoder.close();
        }
      } finally {
        await stage.delete(recursive: true);
      }
      onState?.call(ContentInstallState.verifying);
      check();
      staged = await service.inspect(zipFile, cancelled: cancelled);
      onState?.call(ContentInstallState.committing);
      check();
      // Default conflict cancellation is intentional. Exact existing revisions
      // stay playable; installing never overwrites a different logical version.
      await service.restore(
        staged,
        cancelled: cancelled,
        beforeCommit: beforeCommit,
      );
      for (final r in actual.revisions) {
        if (!await installed(r)) {
          throw StateError('Установленный материал не прошёл проверку');
        }
      }
      onState?.call(ContentInstallState.installed);
    } catch (_) {
      onState?.call(
        cancelled?.call() == true
            ? ContentInstallState.cancelled
            : ContentInstallState.failed,
      );
      rethrow;
    } finally {
      await staged?.close();
      if (zipFile != null && await zipFile.exists()) await zipFile.delete();
    }
  }
}
