import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class StorageChangingException extends FormatException {
  const StorageChangingException()
    : super('База меняется; повторите безопасное открытие');
}

/// Validate only a disposable derivative, before any RW bootstrap/migration.
/// No original SQLite, WAL, journal or media is opened for writing or cleaned.
Future<void> preflightStorage(String path, DatabaseFactory factory) async {
  if (path == inMemoryDatabasePath) return;
  final original = File(path);
  if (!await original.exists()) {
    final parent = p.dirname(path);
    if (await File('$path.storage-ready').exists()) {
      throw const FormatException('Прежняя база недоступна; сброс запрещён');
    }
    for (final suffix in ['-wal', '-shm', '-journal']) {
      if (await File('$path$suffix').exists()) {
        throw const FormatException('Найдены данные незавершённой базы');
      }
    }
    for (final name in ['audio', 'diary_media', 'history_media']) {
      final dir = Directory(p.join(parent, name));
      if (await dir.exists() && !await dir.list().isEmpty) {
        throw const FormatException('Есть локальные файлы без доступной базы');
      }
    }
    return; // Genuine first install only, no inherited storage evidence.
  }
  final temp = await Directory.systemTemp.createTemp('sulfi-db-check-');
  Database? copy;
  try {
    final before = await _fingerprints(path);
    if (await original.length() == 0) {
      throw const FormatException('Пустой файл базы; сброс запрещён');
    }
    final target = p.join(temp.path, 'library.sqlite');
    for (final suffix in before.keys) {
      await File('$path$suffix').copy('$target$suffix');
    }
    if (jsonEncode(before) != jsonEncode(await _fingerprints(path))) {
      throw const StorageChangingException();
    }
    copy = await factory.openDatabase(
      target,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    final integrity = await copy.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw const FormatException('Нарушена целостность базы; сброс запрещён');
    }
    final version = Sqflite.firstIntValue(
      await copy.rawQuery('PRAGMA user_version'),
    )!;
    if (version < 1 || version > 9) {
      throw const FormatException('Неизвестная версия локальных данных');
    }
    final tables = (await copy.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((r) => r['name']).toSet();
    final required = <String, int>{
      'audio_assets': 1,
      'session_templates': 2,
      'current_draft': 2,
      'session_runs': 2,
      'run_events': 2,
      'app_counters': 2,
      'module_definitions': 3,
      'legacy_v2_documents': 3,
      'diary_public': 5,
      'diary_author': 5,
      'diary_removed': 5,
      'diary_sync': 5,
      'capsule_imports': 6,
      'app_settings': 7,
      'history_attachments': 8,
      'content_revisions': 9,
    };
    for (final e in required.entries) {
      if (version >= e.value && !tables.contains(e.key)) {
        throw const FormatException(
          'Неполная база; автоматический сброс запрещён',
        );
      }
    }
    for (final table in [
      'session_templates',
      'current_draft',
      'session_runs',
      'run_events',
      'module_definitions',
      'diary_public',
      'diary_author',
      'history_attachments',
      'content_revisions',
    ]) {
      if (!tables.contains(table)) continue;
      for (final row in await copy.query(table, columns: ['payload'])) {
        if (jsonDecode(row['payload'] as String) is! Map) {
          throw const FormatException(
            'Нечитаемые локальные ссылки; сброс запрещён',
          );
        }
      }
    }
  } finally {
    try {
      await copy?.close();
    } finally {
      await temp.delete(recursive: true); // Derivative only, never the source.
    }
  }
}

Future<Map<String, String>> _fingerprints(String path) async {
  final result = <String, String>{};
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) {
      result[suffix] = (await sha256.bind(file.openRead()).first).toString();
    }
  }
  return result;
}

/// Additional first-install guard, written only after successful app bootstrap.
/// No schema/table/API migration. A missing DB on later starts must fail closed.
Future<void> markStorageReady(String path) async {
  final marker = File('$path.storage-ready');
  if (!await marker.exists()) await marker.writeAsString('9', flush: true);
}
