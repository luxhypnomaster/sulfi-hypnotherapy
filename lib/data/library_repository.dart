import 'package:sqflite/sqflite.dart';

import '../models/audio_asset.dart';
import 'app_database.dart';
import 'content_revision_store.dart';

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
      final next = asset.toMap();
      for (final old in await tx.query(
        'audio_assets',
        where: 'id=?',
        whereArgs: [asset.id],
      )) {
        if (old['contentHash'] != null &&
            asset.contentHash != null &&
            asset.contentHash != old['contentHash']) {
          throw StateError(
            'Новые аудиобайты требуют нового ID; прежняя история сохранена',
          );
        }
        if (asset.contentHash == null &&
            old['contentHash'] != null &&
            old['filePath'] != asset.filePath) {
          throw StateError('Изменённые аудиобайты требуют нового ID');
        }
        if (asset.contentHash == null && old['filePath'] == asset.filePath) {
          next['contentHash'] = old['contentHash'];
        }
        await ContentRevisionStore.retainRow(tx, 'audio_assets', old);
      }
      await ContentRevisionStore.retainRow(tx, 'audio_assets', next);
      final count = await tx.update(
        'audio_assets',
        next,
        where: 'id = ?',
        whereArgs: [asset.id],
      );
      if (count == 0) await tx.insert('audio_assets', next);
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
