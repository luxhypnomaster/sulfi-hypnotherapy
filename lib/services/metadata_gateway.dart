import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/metadata_contract.dart';
import '../models/content_revision.dart';
import '../models/session_plan.dart' show newId;
import 'alchemist_api.dart';
import 'alchemist_errors.dart';
import 'catalog_snapshot_sync.dart';
import 'vitrine_settings.dart';
import 'diary_api.dart';

abstract interface class MetadataRpc {
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> parameters,
  );
}

/// Same validated HTTPS broker/credential/redirect policy. No new OAuth bridge,
/// no untrusted URL from capabilities. Queue owns retries of these reads.
class ExistingMetadataRpc implements MetadataRpc {
  ExistingMetadataRpc(AlchemistApi api)
    : api = AlchemistApi(
        api.endpoint,
        connection: api.connection,
        credential: api.credential,
        identityScope: api.identityScope,
        identityEpoch: api.identityEpoch,
        maxAttempts: 1,
        callTimeout: const Duration(seconds: 20),
      );
  final AlchemistApi api;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> parameters,
  ) => api.call(operation, parameters);
}

class MetadataGateway extends ChangeNotifier
    implements
        CatalogSnapshotTransport,
        VitrineAdminTransport,
        ConditionalVitrineAdmin {
  MetadataGateway({
    required this.rpc,
    required this.owner,
    required this.epoch,
    required this.scope,
    this.knownHead,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final MetadataRpc rpc;
  final String? Function() owner;
  final int Function() epoch;
  final String scope;
  final DateTime Function() clock;
  Future<Map<String, dynamic>?> Function(String)? knownHead;
  Map<String, dynamic>? capability, lastRemoteHead;
  Future<bool>? _probe;
  String? _binding;
  int? _epoch;
  DateTime? _retryAfter;
  String state = 'off';
  bool _closed = false;
  String get label => switch (state) {
    'ready' => 'Каталог: проверяемый протокол подключён',
    'checking' => 'Каталог: проверка возможностей сервера',
    'legacy' => 'Каталог: прежний API; новый протокол не поддерживается',
    'waiting_auth' => 'Каталог: нужен подтверждённый Google-аккаунт',
    'blocked' => 'Каталог: сервер не разрешил новую область',
    'error' => 'Каталог: проверка недоступна; сохранённая копия остаётся',
    _ => 'Каталог: новый протокол выключен',
  };
  bool get ready =>
      !_closed &&
      state == 'ready' &&
      _binding == owner() &&
      _epoch == epoch() &&
      (capability?['expiresAt'] as int? ?? 0) > clock().millisecondsSinceEpoch;
  bool get canPublish => ready && capability?['canWriteConfig'] == true;
  @override
  bool get available => canPublish;
  @override
  String get unavailableReason => label;
  @override
  String get appliedScope => configScope;
  String get configScope => capability!['configScope'] as String;
  void _status(String value) {
    state = value;
    if (!_closed) notifyListeners();
  }

  Future<bool> negotiate({bool force = false}) {
    if (_probe != null) return _probe!;
    if (_closed) return Future.value(false);
    if (ready && !force) return Future.value(true);
    if (!force &&
        _binding == owner() &&
        _epoch == epoch() &&
        (const ['legacy', 'blocked'].contains(state) ||
            state == 'error' && clock().isBefore(_retryAfter ?? clock()))) {
      return Future.value(false);
    }
    return _probe = _negotiate().whenComplete(() => _probe = null);
  }

  Future<bool> _negotiate() async {
    final binding = owner(), authorityEpoch = epoch();
    capability = null;
    lastRemoteHead = null;
    _binding = binding;
    _epoch = authorityEpoch;
    _retryAfter = null;
    if (binding == null || binding == 'public') {
      _status('waiting_auth');
      return false;
    }
    _status('checking');
    final nonce = newId();
    try {
      final c = await rpc
          .call('metadata.capabilities', {'scope': scope, 'nonce': nonce})
          .timeout(const Duration(seconds: 20));
      if (_closed) return false;
      if (owner() != binding || epoch() != authorityEpoch) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      if (c['contract'] != metadataContract ||
          c['schemaVersion'] != 1 ||
          c['canonical'] != metadataCanonical ||
          c['hash'] != 'sha256' ||
          c['scope'] != scope ||
          c['principalBinding'] != binding ||
          c['nonce'] != nonce ||
          c['atomicHeadReceipt'] != true ||
          c['expiresAt'] is! int ||
          c['expiresAt'] <= clock().millisecondsSinceEpoch ||
          c['configScope'] != 'vitrine:public' ||
          c['operations'] is! List ||
          !metadataOperations.every(
            (op) => (c['operations'] as List).contains(op),
          )) {
        _status('legacy');
        return false;
      }
      capability = c;
      _status('ready');
      return true;
    } catch (e) {
      final f = AlchemistFailure.from(e);
      _retryAfter = clock().add(const Duration(seconds: 20));
      _status(
        f.status == 401
            ? 'waiting_auth'
            : f.status == 403
            ? 'blocked'
            : const [404, 422, 501].contains(f.status)
            ? 'legacy'
            : 'error',
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> _call(String op, Map<String, dynamic> p) async {
    if (!await negotiate()) {
      if (state == 'waiting_auth' || state == 'blocked') {
        throw AlchemistFailure.server(
          state == 'waiting_auth' ? 401 : 403,
          state == 'waiting_auth' ? 'AUTH_REQUIRED' : 'SCOPE_DENIED',
        );
      }
      if (state == 'error') {
        throw AlchemistFailure.server(503, 'METADATA_CHECK_UNAVAILABLE');
      }
      throw const AlchemistFailure(
        'Новый протокол каталога недоступен.',
        422,
        'METADATA_UNSUPPORTED',
        DiaryFailure.blocked,
      );
    }
    final binding = owner(), generation = epoch();
    late final Map<String, dynamic> result;
    try {
      result = await rpc
          .call(op, {'scope': scope, ...p})
          .timeout(const Duration(seconds: 20));
    } on AlchemistFailure catch (e) {
      if (e.status == 401 || e.status == 403) {
        capability = null;
        _status(e.status == 401 ? 'waiting_auth' : 'blocked');
      }
      rethrow;
    }
    if (owner() != binding || epoch() != generation) {
      throw const AlchemistFailure(
        'Аккаунт изменился.',
        401,
        'ACCOUNT_CHANGED',
        DiaryFailure.authorization,
      );
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> head(String requestedScope) async {
    if (requestedScope != scope) throw const FormatException('SCOPE_MISMATCH');
    final old = await knownHead?.call(scope);
    final value = await _call('catalog.head', {
      if (old?['snapshotHash'] != null) 'ifSnapshotHash': old!['snapshotHash'],
    });
    lastRemoteHead = value;
    return value;
  }

  @override
  Future<Map<String, dynamic>> snapshot(
    String requestedScope,
    String id,
  ) async {
    if (requestedScope != scope) throw const FormatException('SCOPE_MISMATCH');
    return _call('catalog.snapshot', {'snapshotId': id});
  }

  Future<Map<String, dynamic>?> configView() async {
    final expected = lastRemoteHead?['vitrineHead'];
    if (expected == null) return null;
    final view = await _call('vitrine.configRead', {});
    verifyVitrineView(view, configScope);
    if (view['head']['snapshotHash'] != expected['snapshotHash'] ||
        view['head']['configRevision'] != expected['configRevision']) {
      throw const AlchemistFailure(
        'Настройки изменились; требуется повторная сверка.',
        409,
        'CONFIG_REVISION_CONFLICT',
      );
    }
    return view;
  }

  Future<Map<String, dynamic>?> readAppliedConfig() async {
    if (!await negotiate()) return null;
    final view = await _call('vitrine.configRead', {});
    if (view['head'] == null) return null;
    verifyVitrineView(view, configScope);
    return view;
  }

  @override
  Future<Map<String, dynamic>?> readAppliedView() => readAppliedConfig();
  @override
  Future<Map<String, dynamic>> publish({
    required String requestId,
    required int expectedRevision,
    required Map<String, dynamic> config,
  }) async {
    if (!await negotiate() || !canPublish) {
      throw const AlchemistFailure(
        'Сервер не разрешил публикацию настроек.',
        403,
        'CONFIG_WRITE_DENIED',
        DiaryFailure.blocked,
      );
    }
    final prepared = await _call('vitrine.configPrepare', {
      'requestId': '${requestId}_p',
      'expectedRevision': expectedRevision,
      'config': config,
    });
    if (prepared['head']?['configRevision'] != expectedRevision + 1 ||
        prepared['head']?['scope'] != configScope) {
      throw const FormatException('CONFIG_PREPARE_INVALID');
    }
    final receipt = await _call('vitrine.configCommit', {
      'requestId': requestId,
      'prepareId': prepared['prepareId'],
    });
    if (receipt['outcome'] != 'COMMITTED' ||
        receipt['requestId'] != requestId ||
        receipt['configHash'] != contentDigest(config) ||
        contentDigest(receipt['snapshotHead']) !=
            contentDigest(prepared['head'])) {
      throw const FormatException('CONFIG_RECEIPT_INVALID');
    }
    return receipt;
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
