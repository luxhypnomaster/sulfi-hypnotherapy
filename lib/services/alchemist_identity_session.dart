import 'dart:convert';

import 'diary_identity.dart';

/// SDK identity cache in RAM only. Expiry decoding never grants server authority.
class AlchemistIdentitySession {
  AlchemistIdentitySession(this.identity, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DiaryIdentity identity;
  final DateTime Function() clock;
  String? _token;
  DateTime? _until;
  Future<String>? _pending;
  int _generation = 0;
  Future<String> token() {
    if (_token != null && _until != null && clock().isBefore(_until!)) {
      return Future.value(_token);
    }
    return _pending ??= _signIn().whenComplete(() => _pending = null);
  }

  Future<String> _signIn() async {
    final generation = _generation;
    final result = await identity.signIn();
    if (generation != _generation) {
      throw const FormatException('Вход отменён выходом из аккаунта');
    }
    final pieces = result.idToken.split('.');
    if (pieces.length != 3) {
      throw const FormatException('Google вернул некорректный токен');
    }
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(pieces[1]))),
    );
    final exp = claims['exp'];
    if (exp is! int) throw const FormatException('У токена нет срока действия');
    final limit = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    ).subtract(const Duration(minutes: 1));
    if (!limit.isAfter(clock())) {
      throw const FormatException('Вход Google истёк');
    }
    _until = limit;
    _token = result.idToken;
    return _token!;
  }

  Future<void> logout() async {
    _generation++;
    _token = null;
    _until = null;
    await identity.signOut();
  }
}
