import 'package:sqflite/sqflite.dart';

import 'dart:convert';

import 'v4_migration.dart';
import 'content_revision_store.dart';
import 'storage_preflight.dart';

Future<Database> openAppDatabase(
  String path, {
  DatabaseFactory? factory,
  bool independentConnection = false,
  bool allowMigrations = true,
}) async {
  final backend = factory ?? databaseFactory;
  await preflightStorage(
    path,
    backend,
    allowCreate: allowMigrations,
    requiredVersion: allowMigrations ? null : 9,
  );
  return backend.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 9,
      singleInstance: !independentConnection,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA secure_delete = ON');
      },
      onCreate: (db, version) async {
        if (!allowMigrations) {
          throw const FormatException('Фоновое создание базы запрещено');
        }
        await db.execute('''CREATE TABLE audio_assets (
        id TEXT PRIMARY KEY,title TEXT NOT NULL,filePath TEXT NOT NULL UNIQUE,
        durationMs INTEGER NOT NULL CHECK(durationMs > 0),format TEXT NOT NULL,
        createdAt TEXT NOT NULL,category TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL CHECK(fileSizeBytes > 0),
        description TEXT NOT NULL DEFAULT '',section TEXT NOT NULL DEFAULT 'general',
        tags TEXT NOT NULL DEFAULT '[]',source TEXT NOT NULL DEFAULT 'imported'
      )''');
        await _createSessionTables(db);
        await _createV4Tables(db);
        await _createDiaryTables(db);
        await _addIdentity(db);
        await _addAccessSettings(db);
        await _addHistoryAttachments(db);
        await _addContentRevisions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (!allowMigrations) {
          throw const FormatException('Обновите базу в обычном приложении');
        }
        if (oldVersion < 2) {
          // Additive migration: no rename/delete of audio metadata or media files.
          await db.execute(
            "ALTER TABLE audio_assets ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE audio_assets ADD COLUMN section TEXT NOT NULL DEFAULT 'general'",
          );
          await db.execute(
            "ALTER TABLE audio_assets ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            "ALTER TABLE audio_assets ADD COLUMN source TEXT NOT NULL DEFAULT 'imported'",
          );
          await _createSessionTables(db);
        }
        if (oldVersion < 3) {
          await _createV4Tables(db);
          for (final table in [
            'session_templates',
            'current_draft',
            'session_runs',
          ]) {
            for (final row in await db.query(table)) {
              final original = row['payload'] as String;
              await db.insert('legacy_v2_documents', {
                'kind': table,
                'documentId': row['id'].toString(),
                'payload': original,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
              final updated = migratePlanDocument(
                Map<String, dynamic>.from(jsonDecode(original)),
              );
              await db.update(
                table,
                {'payload': jsonEncode(updated)},
                where: 'id=?',
                whereArgs: [row['id']],
              );
            }
          }
        }
        if (oldVersion < 5) await _createDiaryTables(db);
        if (oldVersion < 6) await _addIdentity(db);
        if (oldVersion < 7) await _addAccessSettings(db);
        if (oldVersion < 8) await _addHistoryAttachments(db);
        if (oldVersion < 9) await _addContentRevisions(db);
      },
    ),
  );
}

Future<void> _addIdentity(DatabaseExecutor db) async {
  final columns = (await db.rawQuery('PRAGMA table_info(audio_assets)'))
      .map((r) => r['name'])
      .toSet();
  for (final e in {
    'origin': "TEXT NOT NULL DEFAULT 'personal'",
    'contentHash': 'TEXT',
    'baseRevision': 'INTEGER NOT NULL DEFAULT 1',
    'author': 'TEXT',
  }.entries) {
    if (!columns.contains(e.key)) {
      await db.execute(
        'ALTER TABLE audio_assets ADD COLUMN ${e.key} ${e.value}',
      );
    }
  }
  await db.execute(
    "UPDATE audio_assets SET origin='supplied' WHERE source='supplied'",
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS capsule_imports(id TEXT PRIMARY KEY, importedAt TEXT NOT NULL)',
  );
}

Future<void> _createSessionTables(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE session_templates (id TEXT PRIMARY KEY,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE current_draft (id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE session_runs (id TEXT PRIMARY KEY,displayNumber INTEGER NOT NULL UNIQUE,status TEXT NOT NULL,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE run_events (id INTEGER PRIMARY KEY AUTOINCREMENT,runId TEXT NOT NULL REFERENCES session_runs(id) ON DELETE CASCADE,payload TEXT NOT NULL)',
  );
  await db.execute('CREATE INDEX run_events_run ON run_events(runId,id)');
  await db.execute(
    'CREATE TABLE app_counters (name TEXT PRIMARY KEY,value INTEGER NOT NULL)',
  );
}

Future<void> _createV4Tables(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS module_definitions(id TEXT PRIMARY KEY,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS legacy_v2_documents(kind TEXT NOT NULL,documentId TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(kind,documentId))',
  );
}

Future<void> _createDiaryTables(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS diary_removed(id TEXT PRIMARY KEY,version INTEGER NOT NULL,revision TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS diary_public(id TEXT PRIMARY KEY,version INTEGER NOT NULL,publishedAt TEXT NOT NULL,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS diary_author(id TEXT PRIMARY KEY,updatedAt TEXT NOT NULL,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS diary_sync(id INTEGER PRIMARY KEY CHECK(id=1),revision TEXT NOT NULL)',
  );
}

Future<void> _addAccessSettings(DatabaseExecutor db) async {
  final columns = (await db.rawQuery('PRAGMA table_info(audio_assets)'))
      .map((r) => r['name'])
      .toSet();
  if (!columns.contains('authorManaged')) {
    await db.execute(
      "ALTER TABLE audio_assets ADD COLUMN authorManaged INTEGER NOT NULL DEFAULT 0",
    );
    await db.execute(
      "UPDATE audio_assets SET authorManaged=1 WHERE origin='supplied' OR section IN ('general','suggestions')",
    );
  }
  await db.execute(
    'CREATE TABLE IF NOT EXISTS app_settings(name TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );
}

Future<void> _addHistoryAttachments(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS history_attachments(id TEXT PRIMARY KEY,runId TEXT NOT NULL REFERENCES session_runs(id) ON DELETE CASCADE,payload TEXT NOT NULL)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS history_attachments_run ON history_attachments(runId)',
  );
}

Future<void> _addContentRevisions(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS content_revisions(id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
  );
  for (final table in [
    'audio_assets',
    'module_definitions',
    'session_templates',
  ]) {
    for (final row in await db.query(table)) {
      await ContentRevisionStore.retainRow(db, table, row);
    }
  }
}
