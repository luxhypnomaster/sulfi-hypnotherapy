// EXPERIMENTAL: imported only by fixture tests. No application startup hook.
// Never migrates its source DB. All writes target a newly created disposable copy.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sulfi_hypnotherapy/data/content_revision_store.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';

const _tables = [
  'audio_assets',
  'content_revisions',
  'current_draft',
  'session_runs',
  'session_templates',
  'module_definitions',
];
Future<String> _hash(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();
Future<Map<String, dynamic>> _rows(Database db) async => {
  for (final table in _tables) table: await db.query(table, orderBy: 'rowid'),
};

class G3Plan {
  G3Plan(
    this.fingerprint,
    this.revisions,
    this.files,
    this.refs,
    this.blockers,
    this.heads,
  );
  final String fingerprint;
  final Map<String, ContentRevision> revisions;
  final Map<String, String> files;
  final List<Map<String, dynamic>> refs;
  final List<String> blockers;
  final Map<String, ContentRevision> heads;
  Map<String, dynamic> get summary => {
    'fingerprint': fingerprint,
    'revisions': revisions.length,
    'verifiedBlobs': files.length,
    'pinnedReferences': refs.length,
    'blockers': blockers,
    'writesToSource': 0,
  };
}

class G3Research {
  static Future<G3Plan> inventory(Database source, Directory audio) async {
    final rows = await _rows(source),
        files = <String, String>{},
        names = <String, String>{},
        blockers = <String>[];
    await for (final f in audio.list(followLinks: false)) {
      if (f is File && p.basename(f.path).startsWith('asset_')) {
        final h = await _hash(f);
        files.putIfAbsent(h, () => f.path);
        names[p.basename(f.path)] = h;
      }
    }
    final revisions = <String, ContentRevision>{},
        heads = <String, ContentRevision>{};
    ContentRevision? add(Map<String, dynamic> raw) {
      final m = Map<String, dynamic>.from(raw),
          name = m['filePath'],
          claimed = m['contentHash'];
      final actual = name is String && p.basename(name) == name
          ? names[name]
          : claimed;
      if (actual == null ||
          !files.containsKey(actual) ||
          claimed != null && claimed != actual) {
        blockers.add('UNVERIFIED_AUDIO_BYTES');
        return null;
      }
      if (File(files[actual]!).lengthSync() != m['fileSizeBytes']) {
        blockers.add('SIZE_MISMATCH');
        return null;
      }
      m['contentHash'] = actual;
      final r = ContentRevisionStore.revisionForRow('audio_assets', m)!;
      revisions[r.key.token] = r;
      return r;
    }

    for (final raw in rows['audio_assets'] as List) {
      final r = add(Map<String, dynamic>.from(raw));
      if (r != null) heads[r.key.content.id] = r;
    }
    for (final row in rows['content_revisions'] as List) {
      try {
        final r = ContentRevision.fromMap(
          Map<String, dynamic>.from(jsonDecode(row['payload'])),
        );
        if (r.key.content.type == ContentType.track) {
          final h = r.payload['contentHash'];
          if (!files.containsKey(h) ||
              File(files[h]!).lengthSync() != r.payload['fileSizeBytes']) {
            blockers.add('RETAINED_BYTES_MISSING');
          } else {
            revisions[r.key.token] = r;
          }
        }
      } catch (_) {
        blockers.add('INVALID_RETAINED_REVISION');
      }
    }
    final refs = <Map<String, dynamic>>[];
    for (final table in _tables.skip(2)) {
      for (final row in rows[table] as List) {
        if (table == 'session_runs' &&
            ['running', 'paused', 'exitingEarly'].contains(row['status'])) {
          blockers.add('ACTIVE_SESSION');
        }
        final root = jsonDecode(row['payload']);
        final frozen = <String, ContentRevision>{};
        void snapshots(dynamic v) {
          if (v is Map) {
            if (v['id'] is String &&
                v['filePath'] is String &&
                v['durationMs'] is int &&
                v['fileSizeBytes'] is int) {
              // A legacy path alone cannot prove which bytes history used.
              if (v['contentHash'] is! String ||
                  !RegExp(r'^[a-f0-9]{64}$').hasMatch(v['contentHash'])) {
                blockers.add('HISTORY_EXACT_PROOF_MISSING');
              } else {
                final r = add(Map<String, dynamic>.from(v));
                if (r != null) frozen[r.key.content.id] = r;
              }
            }
            for (final e in v.values) {
              snapshots(e);
            }
          } else if (v is List) {
            for (final e in v) {
              snapshots(e);
            }
          }
        }

        if (table == 'session_runs') {
          snapshots(root);
          void hashes(dynamic v) {
            if (v is Map) {
              final metadata = v['audioMetadata'];
              if (metadata is Map) {
                for (final e in metadata.entries) {
                  final hash = e.value is Map ? e.value['contentHash'] : null;
                  if (hash == null) continue;
                  final exact = revisions.values
                      .where(
                        (r) =>
                            r.key.content.id == e.key &&
                            r.payload['contentHash'] == hash,
                      )
                      .toList();
                  if (exact.isEmpty) {
                    blockers.add('HISTORY_BYTES_OR_METADATA_MISSING');
                  } else if (exact.length > 1) {
                    blockers.add('AMBIGUOUS_HISTORY_REVISION');
                  } else {
                    frozen[e.key as String] = exact.single;
                  }
                }
              }
              for (final e in v.values) {
                hashes(e);
              }
            } else if (v is List) {
              for (final e in v) {
                hashes(e);
              }
            }
          }

          hashes(root);
        }
        void walk(dynamic v, String path) {
          if (v is Map) {
            if (v['audioAssetId'] is String) {
              final id = v['audioAssetId'];
              final r = table == 'session_runs' ? frozen[id] : heads[id];
              if (r == null && table == 'session_runs') {
                // Even one current candidate is not proof of historical bytes.
                blockers.add('HISTORY_EXACT_PROOF_MISSING');
              }
              if (r == null) {
                blockers.add('AMBIGUOUS_OR_MISSING_LEGACY_REFERENCE');
              } else {
                refs.add({
                  'ownerType': table,
                  'ownerId': row['id'].toString(),
                  'path': path,
                  'logicalId': id,
                  'revisionId': r.key.revision,
                  'blobSha': r.payload['contentHash'],
                });
              }
            }
            for (final e in v.entries) {
              walk(e.value, '$path.${e.key}');
            }
          } else if (v is List) {
            for (var i = 0; i < v.length; i++) {
              walk(v[i], '$path[$i]');
            }
          }
        }

        walk(root, r'$');
      }
    }
    final fingerprint = contentDigest({'rows': rows, 'files': names});
    return G3Plan(
      fingerprint,
      revisions,
      files,
      refs,
      blockers.toSet().toList(),
      heads,
    );
  }

  static Future<G3Sandbox> applyToNewSandbox(
    Database source,
    Directory audio,
    G3Plan plan, {
    Future<void> Function()? beforeCommit,
  }) async {
    if (plan.blockers.isNotEmpty) {
      throw StateError('G3_BLOCKED:${plan.blockers.join(',')}');
    }
    if ((await inventory(source, audio)).fingerprint != plan.fingerprint) {
      throw StateError('SOURCE_CHANGED');
    }
    final root = await Directory.systemTemp.createTemp('sulfi-g3-sandbox-');
    await File(p.join(root.path, '.g3-sandbox'))
        .writeAsString(plan.fingerprint, flush: true);
    final backup = p.join(root.path, 'source-backup.sqlite');
    await source.execute('VACUUM INTO ?', [backup]);
    final target = p.join(root.path, 'candidate.sqlite');
    await File(backup).copy(target);
    final db = await databaseFactoryFfi.openDatabase(target);
    // Verify the DB copy and source bytes are the exact inventory snapshot.
    if ((await inventory(db, audio)).fingerprint != plan.fingerprint) {
      await db.close();
      throw StateError('SNAPSHOT_CHANGED');
    }
    final box = G3Sandbox._(root, db, backup);
    try {
      for (final r in plan.revisions.values) {
        final h = r.payload['contentHash'] as String;
        final destination = File(p.join(root.path, 'blob-$h.bin'));
        if (!await destination.exists()) {
          await File(plan.files[h]!).copy(destination.path);
        }
        if (await _hash(destination) != h) {
          throw StateError('SOURCE_BYTES_CHANGED');
        }
      }
      await db.transaction((tx) async {
        await tx.execute(
          'CREATE TABLE g3_revisions(logicalId TEXT,revisionId TEXT,blobSha TEXT,payload TEXT NOT NULL,PRIMARY KEY(logicalId,revisionId))',
        );
        await tx.execute(
          'CREATE TABLE g3_refs(ownerType TEXT,ownerId TEXT,path TEXT,logicalId TEXT,revisionId TEXT,blobSha TEXT,PRIMARY KEY(ownerType,ownerId,path))',
        );
        await tx.execute(
          'CREATE TABLE g3_heads(logicalId TEXT PRIMARY KEY,revisionId TEXT)',
        );
        await tx.execute(
          "CREATE TRIGGER g3_immutable_update BEFORE UPDATE ON g3_revisions BEGIN SELECT RAISE(ABORT,'IMMUTABLE_REVISION'); END",
        );
        await tx.execute(
          "CREATE TRIGGER g3_immutable_delete BEFORE DELETE ON g3_revisions BEGIN SELECT RAISE(ABORT,'IMMUTABLE_REVISION'); END",
        );
        for (final r in plan.revisions.values) {
          await tx.insert('g3_revisions', {
            'logicalId': r.key.content.id,
            'revisionId': r.key.revision,
            'blobSha': r.payload['contentHash'],
            'payload': canonicalContent(r.toMap()),
          });
        }
        for (final r in plan.refs) {
          await tx.insert('g3_refs', r);
        }
        for (final entry in plan.heads.entries) {
          await tx.insert('g3_heads', {
            'logicalId': entry.key,
            'revisionId': entry.value.key.revision,
          });
        }
        await beforeCommit?.call();
      });
      return box;
    } catch (_) {
      await db.close();
      rethrow; /* Keep sandbox/backup for forensic recovery; no source cleanup or GC. */
    }
  }
}

class G3Sandbox {
  G3Sandbox._(this.root, this.db, this.backup);
  final Directory root;
  final Database db;
  final String backup;
  Future<List<int>> exact(
    String logicalId,
    String revisionId,
    String expectedBlob,
  ) async {
    final rows = await db.query(
      'g3_revisions',
      where: 'logicalId=? AND revisionId=?',
      whereArgs: [logicalId, revisionId],
    );
    if (rows.length != 1 || rows.single['blobSha'] != expectedBlob) {
      throw StateError('EXACT_REVISION_UNAVAILABLE');
    }
    final r = ContentRevision.fromMap(
      Map<String, dynamic>.from(jsonDecode(rows.single['payload'] as String)),
    );
    if (r.key.revision != revisionId ||
        r.key.content.id != logicalId ||
        r.payload['id'] != logicalId ||
        r.payload['contentHash'] != expectedBlob) {
      throw StateError('REVISION_METADATA_MISMATCH');
    }
    final f = File(p.join(root.path, 'blob-$expectedBlob.bin'));
    if (await f.length() != r.payload['fileSizeBytes'] ||
        await _hash(f) != expectedBlob) {
      throw StateError('BLOB_CORRUPT');
    }
    return f.readAsBytes();
  }

  Future<void> setExperimentalHead(String logicalId, String revisionId) async {
    if ((await db.query(
          'g3_revisions',
          where: 'logicalId=? AND revisionId=?',
          whereArgs: [logicalId, revisionId],
        )).length !=
        1) {
      throw StateError('MISSING_HEAD');
    }
    await db.update(
      'g3_heads',
      {'revisionId': revisionId},
      where: 'logicalId=?',
      whereArgs: [logicalId],
    );
  }

  Future<Database> rollbackClone() async {
    if (!await File(p.join(root.path, '.g3-sandbox')).exists()) {
      throw StateError('NOT_SANDBOX');
    }
    final path = p.join(
      root.path,
      'rollback-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    await File(backup).copy(path);
    return databaseFactoryFfi.openDatabase(
      path,
    ); // leaves experimental DB and blobs intact
  }

  Future<void> close() => db.close();
}
