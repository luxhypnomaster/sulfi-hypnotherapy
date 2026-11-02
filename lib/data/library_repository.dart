import 'package:sqflite/sqflite.dart';

import '../models/audio_asset.dart';

abstract interface class LibraryRepository {
  Future<List<AudioAsset>> list();
  Future<void> save(AudioAsset asset);
  Future<void> delete(String id);
  Future<void> clear();
}

class SqliteLibraryRepository implements LibraryRepository {
  SqliteLibraryRepository(this.database);
  final Database database;

  static Future<SqliteLibraryRepository> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA secure_delete = ON'),
        onCreate: (db, version) => db.execute('''
          CREATE TABLE audio_assets (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            filePath TEXT NOT NULL UNIQUE,
            durationMs INTEGER NOT NULL CHECK(durationMs > 0),
            format TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            category TEXT NOT NULL,
            fileSizeBytes INTEGER NOT NULL CHECK(fileSizeBytes > 0)
          )
        '''),
      ),
    );
    return SqliteLibraryRepository(db);
  }

  @override
  Future<List<AudioAsset>> list() async => (await database.query(
    'audio_assets',
    orderBy: 'createdAt DESC, id DESC',
  )).map(AudioAsset.fromMap).toList();

  @override
  Future<void> save(AudioAsset asset) async {
    await database.transaction((tx) async {
      final count = await tx.update(
        'audio_assets',
        asset.toMap(),
        where: 'id = ?',
        whereArgs: [asset.id],
      );
      if (count == 0) await tx.insert('audio_assets', asset.toMap());
    });
  }

  @override
  Future<void> delete(String id) async {
    await database.delete('audio_assets', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clear() async {
    await database.delete('audio_assets');
  }
}
