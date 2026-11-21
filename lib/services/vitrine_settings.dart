import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import '../models/session_plan.dart' show newId;
import '../models/vitrine_config.dart';
import '../models/metadata_contract.dart';

/// No production implementation until an approved, server-authorized contract
/// exists. Implementations MUST verify role, expected revision and idempotency.
abstract interface class VitrineAdminTransport {
  Future<Map<String, dynamic>> publish({
    required String requestId,
    required int expectedRevision,
    required Map<String, dynamic> config,
  });
}

abstract interface class ConditionalVitrineAdmin {
  bool get available;
  String get unavailableReason;
  String get appliedScope;
  Future<Map<String, dynamic>?> readAppliedView();
}

class VitrineSettingsStore {
  VitrineSettingsStore(
    this.db, {
    required this.account,
    required this.canEdit,
    this.admin,
  });
  final Database db;
  final String? Function() account;
  final bool Function() canEdit;
  final VitrineAdminTransport? admin;
  bool get canPublish =>
      admin != null &&
      (admin is! ConditionalVitrineAdmin ||
          (admin as ConditionalVitrineAdmin).available);
  Future<void> refreshApplied() async {
    final a = account(), backend = admin;
    if (a == null || backend == null || backend is! ConditionalVitrineAdmin) {
      return;
    }
    final conditional = backend as ConditionalVitrineAdmin;
    final view = await conditional.readAppliedView();
    if (view == null) return;
    final config = verifyVitrineView(view, conditional.appliedScope);
    await db.transaction((tx) async {
      if (a != account()) throw const FormatException('ACCOUNT_CHANGED');
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [_key(a)],
      );
      final old = rows.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(rows.single['value'] as String),
            );
      if ((old['appliedRevision'] as int? ?? 0) >
          view['head']['configRevision']) {
        return;
      }
      await tx.insert('app_settings', {
        'name': _key(a),
        'value': jsonEncode({
          ...old,
          'applied': config.toMap(),
          'appliedRevision': view['head']['configRevision'],
          'appliedHead': view['head'],
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void>? _publishing;
  String _key(String a) => 'vitrine20:${contentDigest(a)}';
  Future<Map<String, dynamic>> load() async {
    final a = account();
    if (a == null) return {};
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [_key(a)],
    );
    if (a != account() || rows.isEmpty) return {};
    return Map<String, dynamic>.from(
      jsonDecode(rows.single['value'] as String),
    );
  }

  Future<void> save(VitrineConfig config) async {
    config.validate();
    final a = account();
    if (a == null || !canEdit()) {
      throw const FormatException('Авторский режим недоступен');
    }
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [_key(a)],
      );
      final old = rows.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(rows.single['value'] as String),
            );
      if (a != account() || !canEdit()) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      await tx.insert('app_settings', {
        'name': _key(a),
        'value': jsonEncode({
          ...old,
          'saved': config.toMap(),
          'savedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> publish() =>
      _publishing ??= _publish().whenComplete(() => _publishing = null);
  Future<void> _publish() async {
    final a = account();
    if (a == null || !canEdit() || admin == null) {
      throw const FormatException(
        'Публикация настроек не подключена к серверу',
      );
    }
    final old = await load();
    final config = Map<String, dynamic>.from(old['saved']);
    VitrineConfig.fromMap(config);
    // Persist stable request identity before calling transport; lost response can
    // be retried without creating another publication. Preserve previous receipt.
    final fingerprint = contentDigest(config);
    final expectedRevision =
        (old['appliedRevision'] as int? ?? 0) >
            (old['publishedRevision'] as int? ?? 0)
        ? old['appliedRevision'] as int
        : old['publishedRevision'] as int? ?? 0;
    if (old['published'] != null &&
        contentDigest(old['published']) == fingerprint &&
        expectedRevision == (old['publishedRevision'] ?? 0)) {
      return;
    }
    final requestId =
        old['pendingHash'] == fingerprint &&
            (old['pendingExpectedRevision'] ?? old['publishedRevision'] ?? 0) ==
                expectedRevision
        ? old['requestId'] as String
        : newId();
    final intent = {
      ...old,
      'pendingHash': fingerprint,
      'requestId': requestId,
      'pendingExpectedRevision': expectedRevision,
    };
    await db.insert('app_settings', {
      'name': _key(a),
      'value': jsonEncode(intent),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (a != account() || !canEdit()) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    final receipt = await admin!.publish(
      requestId: requestId,
      expectedRevision: expectedRevision,
      config: config,
    );
    if (a != account() || !canEdit()) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    if (receipt['requestId'] != requestId ||
        receipt['configHash'] != fingerprint ||
        receipt['configRevision'] is! int ||
        receipt['configRevision'] != expectedRevision + 1 ||
        receipt['configRevision'] <= (old['publishedRevision'] ?? 0)) {
      throw const FormatException('Некорректное подтверждение сервера');
    }
    await db.transaction((tx) async {
      if (a != account() || !canEdit()) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [_key(a)],
      );
      final latest = Map<String, dynamic>.from(
        jsonDecode(rows.single['value'] as String),
      );
      if (latest['requestId'] != requestId ||
          latest['pendingHash'] != fingerprint) {
        throw const FormatException(
          'Настройки изменились; требуется сверка подтверждения',
        );
      }
      await tx.insert('app_settings', {
        'name': _key(a),
        'value': jsonEncode({
          ...latest,
          'published': config,
          'publishedRevision': receipt['configRevision'],
          'appliedRevision': receipt['configRevision'],
          'receipt': receipt,
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
