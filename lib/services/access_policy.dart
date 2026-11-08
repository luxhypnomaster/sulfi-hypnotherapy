import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/audio_asset.dart';
import 'library_service.dart';

enum LocalMode { author, client }

/// Local content capabilities, independent of cloud diary authentication.
/// A client edition cannot enable author mode through settings or a capsule.
class AccessPolicy extends ChangeNotifier {
  AccessPolicy({this.database, bool? clientEdition})
    : clientEdition =
          clientEdition ??
          const String.fromEnvironment('SULFI_EDITION') == 'client';
  final Database? database;
  final bool clientEdition;
  LocalMode _mode = LocalMode.author;
  LocalMode get mode => clientEdition ? LocalMode.client : _mode;
  bool get isAuthor => mode == LocalMode.author;
  Future<void> load() async {
    final rows = await database?.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['content_mode'],
    );
    _mode = rows?.firstOrNull?['value'] == 'client'
        ? LocalMode.client
        : LocalMode.author;
    notifyListeners();
  }

  Future<void> setMode(LocalMode value) async {
    if (clientEdition) {
      throw const LibraryException(
        'Клиентская сборка: авторский режим недоступен.',
      );
    }
    await database?.insert('app_settings', {
      'name': 'content_mode',
      'value': value.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _mode = value;
    notifyListeners();
  }

  bool canEditOrigin(String origin) => isAuthor || origin != 'supplied';
  bool canEditAudio(AudioAsset asset) => isAuthor || !asset.authorControlled;
  void requireOrigin(String origin) {
    if (!canEditOrigin(origin)) {
      throw const LibraryException(
        'Авторский материал доступен для использования. Для изменений создайте личную копию.',
      );
    }
  }

  void requireAudio(AudioAsset asset) {
    if (!canEditAudio(asset)) {
      throw const LibraryException(
        'Авторскую аудиозапись можно использовать, но нельзя изменять в клиентском режиме.',
      );
    }
  }
}
