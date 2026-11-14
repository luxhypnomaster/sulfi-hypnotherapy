import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'alchemist_diagnostics.dart';
import 'alchemist_errors.dart';
import 'alchemist_http.dart';
import 'apps_script_diary_transport.dart';
import 'diary_api.dart';

class AlchemistApiException extends AlchemistFailure {
  const AlchemistApiException(
    super.message,
    super.status,
    super.code, [
    super.kind = DiaryFailure.network,
    super.retryable = false,
  ]);
}

/// Same GAS6 envelope and redirect policy; retries keep the original account.
class AlchemistApi {
  AlchemistApi(
    this.endpoint, {
    DiaryRequest? connection,
    this.credential,
    this.identityScope,
    this.identityEpoch,
    this.onUnauthorized,
    this.onAuthenticationFailure,
    this.maxAttempts = 3,
    Future<void> Function(Duration)? delay,
    AlchemistDiagnostics? diagnostics,
    this.callTimeout = const Duration(minutes: 3),
  }) : connection = connection ?? const AlchemistHttp().request,
       delay = delay ?? Future<void>.delayed,
       diagnostics = diagnostics ?? AlchemistDiagnostics.instance {
    if (!AppsScriptDiaryTransport.supports(endpoint)) {
      throw const FormatException('Требуется проверенный адрес сервера /exec');
    }
  }
  final String Function()? identityScope;
  final int Function()? identityEpoch;
  String? get currentIdentityScope => identityScope?.call();
  String? get ownerBinding =>
      currentIdentityScope == null || currentIdentityScope == 'public'
      ? null
      : sha256
            .convert(utf8.encode('$endpoint|$currentIdentityScope'))
            .toString();
  final int maxAttempts;
  final Uri endpoint;
  final DiaryRequest connection;
  final Future<String?> Function()? credential;
  final Future<bool> Function()? onUnauthorized;
  final void Function()? onAuthenticationFailure;
  final Future<void> Function(Duration) delay;
  final AlchemistDiagnostics diagnostics;
  final Duration callTimeout;

  static bool repeatable(String op, Map<String, dynamic> p) =>
      const {
            'media.beginUpload',
            'catalog.createDraft',
            'catalog.patchDraft',
            'catalog.updateMetadata',
            'catalog.publish',
            'catalog.withdraw',
            'catalog.archive',
            'catalog.restore',
            'entry.createDraft',
            'entry.patchDraft',
            'entry.updateMetadata',
            'entry.publish',
            'entry.unpublish',
            'entry.archive',
            'entry.restore',
            'reads.merge',
          }.contains(op) &&
          p['requestId'] is String &&
          (p['requestId'] as String).isNotEmpty ||
      const {
        'auth.whoami',
        'feed.list',
        'entry.get',
        'catalog.list',
        'catalog.get',
        'catalog.getRevision',
        'catalog.resolveReference',
        'catalog.changes',
        'catalog.checkUpdates',
        'content.getRevision',
        'media.getDescriptor',
        'media.beginDownload',
        'media.downloadChunk',
        'media.metadata',
        'system.authorizationStatus',
      }.contains(op) ||
      op == 'content.registerManifest' && p['revision'] is Map ||
      const {
            'media.uploadChunk',
            'media.commitUpload',
            'media.abortUpload',
          }.contains(op) &&
          p['sessionId'] is String;

  void _checkInterrupted() {
    final stop = Zone.current[#alchemistInterrupted];
    if (stop is bool Function() && stop()) {
      throw const AlchemistApiException(
        'Передача приостановлена.',
        0,
        'TRANSFER_PAUSED',
        DiaryFailure.network,
      );
    }
  }

  /// Read authoritative state before replaying an uncertain keyed mutation.
  /// The GET never grants a receipt by inference: replay still uses the SAME
  /// requestId so GAS returns its receipt or a safe precondition conflict.
  Future<void> reconcileUncertain(
    String operation,
    Map<String, dynamic> p,
  ) async {
    final catalog =
        operation.startsWith('catalog.') && p['catalogItemId'] is String;
    final diary = operation.startsWith('entry.') && p['entryId'] is String;
    if (!catalog && !diary) return;
    _checkInterrupted();
    diagnostics.stage('SERVER_COMMIT_UNCERTAIN');
    try {
      await call(catalog ? 'catalog.get' : 'entry.get', {
        if (catalog) 'catalogItemId': p['catalogItemId'],
        if (diary) 'entryId': p['entryId'],
      });
    } on AlchemistFailure catch (e) {
      if (e.status != 404) {
        rethrow; // A missing create may safely replay its key.
      }
    }
  }

  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    var originalScope = identityScope?.call();
    final originalEpoch = identityEpoch?.call(), trace = diagnostics.begin();
    var initialBinding = originalScope == 'public';
    final watch = Stopwatch()..start();
    var refreshed = false;
    void checkScope(bool afterCredential) {
      // A cold silent restore establishes the first verified identity before
      // any request is sent. Existing identities and logout epochs stay frozen.
      if (afterCredential &&
          initialBinding &&
          originalEpoch == identityEpoch?.call()) {
        originalScope = identityScope?.call();
        initialBinding = false;
      }
      if (originalScope != identityScope?.call() ||
          originalEpoch != identityEpoch?.call()) {
        throw const AlchemistApiException(
          'Аккаунт изменился. Задача приостановлена.',
          401,
          'ACCOUNT_CHANGED',
          DiaryFailure.authorization,
        );
      }
    }

    for (var attempt = 0; ; attempt++) {
      checkScope(false);
      _checkInterrupted();
      final left = callTimeout - watch.elapsed;
      if (left <= Duration.zero) {
        throw AlchemistFailure.from(TimeoutException('deadline'));
      }
      try {
        final result = await _once(
          operation,
          parameters,
          trace,
          attempt,
          checkScope,
        ).timeout(left);
        diagnostics.record(
          trace,
          operation,
          'complete',
          watch.elapsedMilliseconds,
          attempt: attempt,
          status: 200,
        );
        return result;
      } catch (error) {
        checkScope(false);
        final e = AlchemistFailure.from(error);
        diagnostics.record(
          trace,
          operation,
          'error',
          watch.elapsedMilliseconds,
          attempt: attempt,
          status: e.status,
          code: e.code,
        );
        if (e.status == 401) onAuthenticationFailure?.call();
        if (!refreshed &&
            e.status == 401 &&
            onUnauthorized != null &&
            !const {
              'IDENTITY_REVOKED',
              'TOKEN_AUDIENCE_INVALID',
              'ACCOUNT_CHANGED',
            }.contains(e.code)) {
          refreshed = true;
          if (await onUnauthorized!()) {
            checkScope(false);
            continue;
          }
        }
        if (!e.retryable ||
            !repeatable(operation, parameters) ||
            attempt + 1 >= maxAttempts ||
            watch.elapsed >= callTimeout) {
          if (error is DiaryApiException && error is! AlchemistFailure) rethrow;
          throw AlchemistApiException(
            e.message,
            e.status,
            e.code,
            e.kind,
            e.retryable,
          );
        }
        _checkInterrupted();
        if (parameters['requestId'] is String) {
          final remaining = callTimeout - watch.elapsed;
          if (remaining <= Duration.zero) {
            throw AlchemistFailure.from(TimeoutException('deadline'));
          }
          await reconcileUncertain(operation, parameters).timeout(remaining);
          checkScope(false);
        }
        diagnostics.record(
          trace,
          operation,
          'retry',
          watch.elapsedMilliseconds,
          attempt: attempt + 1,
          code: e.code,
        );
        await delay(
          Duration(
            milliseconds: (250 << min(attempt, 4)) + Random().nextInt(200),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _once(
    String operation,
    Map<String, dynamic> parameters,
    String trace,
    int attempt,
    void Function(bool) checkScope,
  ) async {
    final clock = Stopwatch()..start();
    final token = await credential?.call();
    checkScope(true);
    diagnostics.record(
      trace,
      operation,
      'credential',
      clock.elapsedMilliseconds,
      attempt: attempt,
    );
    _checkInterrupted();
    diagnostics.stage('HTTP_REQUEST_START');
    var response = await connection(
      'POST',
      endpoint,
      {'Accept': 'application/json', 'Content-Type': 'application/json'},
      jsonEncode({
        'version': 1,
        'operation': operation,
        'parameters': parameters,
        'traceId': trace,
        'credential': ?token,
      }),
    );
    checkScope(false);
    diagnostics.record(
      trace,
      operation,
      'response',
      clock.elapsedMilliseconds,
      attempt: attempt,
      status: response.status,
    );
    for (
      var count = 0;
      response.status == 302 || response.status == 303;
      count++
    ) {
      final target = Uri.tryParse(response.headers['location'] ?? '');
      if (count >= 3 ||
          target == null ||
          target.scheme != 'https' ||
          target.host != 'script.googleusercontent.com' ||
          target.port != 443 ||
          target.userInfo.isNotEmpty ||
          target.hasFragment) {
        throw const DiaryApiException('Небезопасное перенаправление сервера');
      }
      response = await connection('GET', target, {
        'Accept': 'application/json',
      }, null);
      checkScope(false);
    }
    if (response.status != 200) {
      final e = AlchemistFailure.server(
        response.status,
        'HTTP_${response.status}',
      );
      throw AlchemistApiException(
        e.message,
        e.status,
        e.code,
        e.kind,
        e.retryable,
      );
    }
    final mime = response.headers['content-type'];
    if (mime != null && mime.split(';').first.trim() != 'application/json') {
      throw const DiaryApiException(
        'Сервер вернул неподдерживаемый формат ответа',
        DiaryFailure.invalidData,
      );
    }
    Map<String, dynamic> value;
    try {
      value = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw const DiaryApiException('Некорректный ответ сервера');
    }
    final status = value['status'];
    if (status is! int ||
        status < 200 ||
        status > 599 ||
        value['ok'] is! bool) {
      throw const DiaryApiException('Некорректный протокол сервера');
    }
    if (value['ok'] != true || status >= 300) {
      final raw = value['error'] is Map ? value['error']['code'] : null;
      final code = raw is String && RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(raw)
          ? raw
          : 'REQUEST_REJECTED';
      final e = AlchemistFailure.server(status, code);
      throw AlchemistApiException(
        e.message,
        e.status,
        e.code,
        e.kind,
        e.retryable,
      );
    }
    if (value['result'] is! Map) {
      throw const DiaryApiException('Неожиданный результат сервера');
    }
    return Map<String, dynamic>.from(value['result']);
  }
}
