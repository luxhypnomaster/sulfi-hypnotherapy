import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/audio_asset.dart';
import '../models/content_revision.dart';
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
  final Map<String, Map<String, dynamic>> _catalogOrigins = {};
  bool isCatalogOriginal(String type, String id) =>
      _catalogOrigins.containsKey('$type:$id');
  List<Map<String, dynamic>> get catalogOrigins => _catalogOrigins.values
      .map((v) => Map<String, dynamic>.from(jsonDecode(jsonEncode(v))))
      .toList();
  static Map<String, dynamic> validateCatalogOrigin(
    Map<String, dynamic> value,
  ) {
    final key = RevisionKey.fromMap(
      Map<String, dynamic>.from(value['key'] as Map),
    );
    final endpoint = value['sourceEndpoint'], item = value['catalogItemId'];
    if (value['origin'] != 'official' ||
        !['track', 'module', 'template'].contains(key.content.type.name) ||
        endpoint is! String ||
        !RegExp(r'^https://script\.google\.com/macros/s/[\w-]+/exec$')
            .hasMatch(endpoint) ||
        item is! String ||
        !RegExp(r'^[\w-]{1,120}$').hasMatch(item)) {
      throw const FormatException('Некорректное происхождение материала');
    }
    // Local readonly provenance only. Roles, tokens and capabilities are never restored.
    return {
      'key': key.toMap(),
      'sourceEndpoint': endpoint,
      'catalogItemId': item,
      'origin': 'official',
    };
  }

  Future<void> registerCatalogOriginals(
    Iterable<Map<String, dynamic>> keys,
    String endpoint,
    String itemId,
  ) async {
    for (final key in keys) {
      final type = key['type'], id = key['logicalId'];
      if (!['track', 'module', 'template'].contains(type) || id is! String) {
        continue;
      }
      final value = validateCatalogOrigin({
        'key': key,
        'sourceEndpoint': endpoint,
        'catalogItemId': itemId,
        'origin': 'official',
      });
      await database?.insert('app_settings', {
        'name': 'alchemist_origin:$type:$id',
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      _catalogOrigins['$type:$id'] = value;
    }
    notifyListeners();
  }

  bool canEditMaterial(String type, String id, String origin) =>
      isAuthor || !isCatalogOriginal(type, id) && origin != 'supplied';
  void requireMaterial(String type, String id, String origin) {
    if (!canEditMaterial(type, id, origin)) {
      throw const LibraryException(
        'Официальный материал доступен для использования. Для изменений создайте личную копию.',
      );
    }
  }

  LocalMode _mode = LocalMode.author;
  LocalMode get mode => clientEdition ? LocalMode.client : _mode;
  bool _serverIdentityRequired = false;
  String? _serverRole;
  bool get serverIdentityRequired => _serverIdentityRequired;
  String? get serverRole => _serverRole;
  void applyVerifiedServerRole(String? role) {
    _serverIdentityRequired = true;
    _serverRole = role;
    notifyListeners();
  }

  bool get isAuthor =>
      !clientEdition &&
      (_serverIdentityRequired
          ? _serverRole == 'MASTER'
          : mode == LocalMode.author);
  Future<void> load() async {
    final rows = await database?.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['content_mode'],
    );
    await _loadCatalogOrigins();
    _mode = rows?.firstOrNull?['value'] == 'client'
        ? LocalMode.client
        : LocalMode.author;
    notifyListeners();
  }

  Future<void> _loadCatalogOrigins() async {
    _catalogOrigins.clear();
    for (final row
        in await database?.query(
              'app_settings',
              where: 'name LIKE ?',
              whereArgs: ['alchemist_origin:%'],
            ) ??
            <Map<String, Object?>>[]) {
      try {
        final v = Map<String, dynamic>.from(jsonDecode(row['value'] as String));
        final k = v['key'] as Map;
        if (v['origin'] == 'official') {
          _catalogOrigins['${k['type']}:${k['logicalId']}'] = v;
        }
      } catch (_) {
        /* Preserve malformed metadata; never grant author authority from it. */
      }
    }
  }

  Future<void> reloadCatalogOrigins() async {
    await _loadCatalogOrigins();
    notifyListeners();
  }

  Future<void> setMode(LocalMode value) async {
    if (value == LocalMode.author &&
        _serverIdentityRequired &&
        _serverRole != 'MASTER') {
      throw const LibraryException('Права мастера не подтверждены сервером');
    }
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
  bool canEditAudio(AudioAsset asset) =>
      isAuthor ||
      !asset.authorControlled && !isCatalogOriginal('track', asset.id);
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
