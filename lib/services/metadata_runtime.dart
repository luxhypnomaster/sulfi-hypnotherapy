import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import '../models/metadata_contract.dart';
import '../models/vitrine_config.dart';
import 'catalog_snapshot_sync.dart';
import 'metadata_gateway.dart';
import 'alchemist_work_queue.dart';
import 'vitrine_settings.dart';

/// Runtime binding for BOTH UI and the existing headless worker. A negotiated
/// gateway is the only remote adapter; there is no second queue or worker.
class MetadataRuntime extends ChangeNotifier {
  MetadataRuntime({
    required this.db,
    required this.gateway,
    required this.owner,
    required this.canEdit,
    required this.applyConfig,
    this.settingsAccount,
  }) {
    sync = CatalogSnapshotSync(db: db, transport: gateway, owner: owner);
    gateway.knownHead = (scope) async => (await sync.lastGood(scope))?['head'];
    sync.addListener(_changed);
    gateway.addListener(_changed);
  }
  final Database db;
  final MetadataGateway gateway;
  final String? Function() owner;
  final bool Function() canEdit;
  final void Function(VitrineConfig) applyConfig;
  final String? Function()? settingsAccount;
  late final CatalogSnapshotSync sync;
  bool _closed = false;
  void _changed() {
    if (!_closed) notifyListeners();
  }

  VitrineSettingsStore get settings => VitrineSettingsStore(
    db,
    account: settingsAccount ?? owner,
    canEdit: canEdit,
    admin: gateway,
  );
  String _configKey(String a) =>
      'vitrine21_current:${contentDigest([a, gateway.scope])}';
  Future<void> restoreConfig() async {
    final a = owner();
    if (a == null) return;
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [_configKey(a)],
    );
    if (rows.isEmpty || owner() != a || _closed) return;
    final v = Map<String, dynamic>.from(
      jsonDecode(rows.single['value'] as String),
    );
    applyConfig(verifyVitrineView(v, 'vitrine:public'));
  }

  Future<List<Map<String, dynamic>>?> cachedCards() async {
    final view = await sync.lastGood(gateway.scope);
    if (view == null) return null;
    return [
      for (final r in view['snapshot']['items'] as List)
        if (r['catalogItemId'] is String && r['card'] is Map)
          {
            'catalogItemId': r['catalogItemId'],
            'type': r['type'],
            'logicalContentId': r['contentId'],
            'immutableRevisionId': r['revisionId'],
            'publicationState': 'published',
            'card': Map<String, dynamic>.from(r['card']),
          },
    ];
  }

  Future<bool> refresh(AlchemistWorkQueue queue, {bool force = false}) async {
    await restoreConfig();
    if (!await gateway.negotiate(force: force)) return false;
    await sync.request(gateway.scope, queue);
    return true;
  }

  Future<void> execute(Map<String, dynamic> row, bool Function() stop) async {
    final a = owner();
    await sync.execute(row, stop);
    if (stop() || owner() != a || _closed) return;
    final view = await gateway.configView();
    if (view == null) return;
    final config = verifyVitrineView(view, gateway.configScope);
    if (stop() || owner() != a || _closed) return;
    var changed = false;
    await db.transaction((tx) async {
      if (stop() || owner() != a || _closed) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      final key = _configKey(a!);
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [key],
      );
      if (rows.isNotEmpty) {
        final old = jsonDecode(rows.single['value'] as String);
        if (old['head']['configRevision'] >= view['head']['configRevision']) {
          return;
        }
      }
      await tx.insert('app_settings', {
        'name': key,
        'value': jsonEncode(view),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
    });
    if (changed && !stop() && owner() == a && !_closed) {
      applyConfig(config);
      _changed();
    }
  }

  @override
  void dispose() {
    _closed = true;
    sync.removeListener(_changed);
    gateway.removeListener(_changed);
    sync.dispose();
    gateway.dispose();
    super.dispose();
  }
}
