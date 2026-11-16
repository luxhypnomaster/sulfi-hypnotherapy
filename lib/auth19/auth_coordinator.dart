import 'dart:async';

import 'package:flutter/services.dart';

enum Auth19State {
  signedOut,
  restoring,
  authenticated,
  refreshing,
  offline,
  backendUnavailable,
  reauthRequired,
  revoked,
}

class Auth19Snapshot {
  const Auth19Snapshot(this.state, {this.uid, this.epoch = 0, this.code = ''});
  final Auth19State state;
  final String? uid;
  final int epoch;
  final String code;
  bool get ready => state == Auth19State.authenticated && uid != null;
  factory Auth19Snapshot.fromMap(Map<dynamic, dynamic> value) {
    const states = {
      'SIGNED_OUT': Auth19State.signedOut,
      'RESTORING': Auth19State.restoring,
      'AUTHENTICATED': Auth19State.authenticated,
      'REFRESHING': Auth19State.refreshing,
      'OFFLINE': Auth19State.offline,
      'BACKEND_UNAVAILABLE': Auth19State.backendUnavailable,
      'REAUTH_REQUIRED': Auth19State.reauthRequired,
      'REVOKED': Auth19State.revoked,
    };
    return Auth19Snapshot(
      states[value['state']] ?? Auth19State.backendUnavailable,
      uid: value['uid'] as String?,
      epoch: value['epoch'] as int? ?? 0,
      code: value['code'] as String? ?? '',
    );
  }
  @override
  String toString() => 'Auth19Snapshot(${state.name}, epoch=$epoch)';
}

/// There is no Supabase refresh token in Dart. Native broker is the only writer.
/// Production main.dart never instantiates this isolated staging coordinator.
class AuthCoordinator {
  AuthCoordinator({
    this.enabled = const bool.fromEnvironment('SULFI_AUTH19_STAGING'),
    MethodChannel? channel,
    this.events,
  }) : _channel = channel ?? const MethodChannel('ru.sulfi/auth19');
  final bool enabled;
  final MethodChannel _channel;
  final Stream<dynamic>? events;
  final _changes = StreamController<Auth19Snapshot>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  Future<Auth19Snapshot>? _restoring;
  Auth19Snapshot snapshot = const Auth19Snapshot(Auth19State.signedOut);
  Stream<Auth19Snapshot> get onAuthStateChange => _changes.stream;

  void _accept(Auth19Snapshot value) {
    snapshot = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<Auth19Snapshot> initialize({
    required String projectRef,
    required String publishableKey,
    String? expectedUid,
  }) async {
    if (!enabled) return snapshot;
    _subscription ??=
        (events ??
                const EventChannel('ru.sulfi/auth19/events')
                    .receiveBroadcastStream())
            .listen(
              (value) => _accept(Auth19Snapshot.fromMap(value as Map)),
              onError: (Object _) => _accept(
                const Auth19Snapshot(
                  Auth19State.backendUnavailable,
                  code: 'AUTH_EVENT_UNAVAILABLE',
                ),
              ),
            );
    return _request('initialize', {
      'projectRef': projectRef,
      'publishableKey': publishableKey,
      'expectedUid': ?expectedUid,
    });
  }

  Future<Auth19Snapshot> _request(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!enabled) return snapshot;
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>(
        method,
        arguments,
      );
      final value = Auth19Snapshot.fromMap(result ?? {});
      _accept(value);
      return value;
    } on PlatformException catch (e) {
      final value = Auth19Snapshot.fromMap({
        'state': e.message,
        'code': e.code,
      });
      _accept(value);
      return value;
    } on MissingPluginException {
      const value = Auth19Snapshot(
        Auth19State.backendUnavailable,
        code: 'NATIVE_STAGING_UNAVAILABLE',
      );
      _accept(value);
      return value;
    }
  }

  Future<Auth19Snapshot> restore() =>
      _restoring ??= _request('restore').whenComplete(() => _restoring = null);
  Future<Uri?> beginGoogleSignIn({bool switchAccount = false}) async {
    if (!enabled) return null;
    final value = await _channel.invokeMethod<String>('beginLogin', {
      'switchAccount': switchAccount,
    });
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !RegExp(r'^[a-z0-9]{20}\.supabase\.co$').hasMatch(uri.host) ||
        uri.path != '/auth/v1/authorize') {
      throw const FormatException('Invalid staging OAuth endpoint');
    }
    return uri;
  }

  Future<Auth19Snapshot> logout() => _request('logout');
  Future<Auth19Snapshot> cancelLogin() => _request('cancelLogin');

  /// Staging-only future gateway contract; MUST NOT be used by the GAS18 worker.
  Future<Map<dynamic, dynamic>?> workerLease(
    String expectedUid, {
    int? expectedEpoch,
  }) async {
    if (!enabled || expectedUid.isEmpty) return null;
    return _channel.invokeMapMethod<dynamic, dynamic>('lease', {
      'expectedUid': expectedUid,
      'expectedEpoch': ?expectedEpoch,
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
