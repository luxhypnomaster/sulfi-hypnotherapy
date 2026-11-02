import 'package:sqflite/sqflite.dart';

import '../models/audio_asset.dart';
import 'app_database.dart';

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
    final db = await openAppDatabase(path, factory: factory);
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
