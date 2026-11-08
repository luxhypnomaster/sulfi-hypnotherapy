import 'dart:convert';

import 'diary_api.dart';

/// Apps Script's ContentService uses POST envelopes and a Google-hosted redirect.
/// Credentials go only to the configured script, never into URLs or redirects.
class AppsScriptDiaryTransport {
  AppsScriptDiaryTransport(this.base, {DiaryRequest? connection})
    : _connection = connection ?? DiaryApi.httpRequest {
    if (!supports(base)) {
      throw const DiaryApiException(
        'Нужен адрес развёрнутого Apps Script, оканчивающийся на /exec',
      );
    }
  }
  final Uri base;
  final DiaryRequest _connection;

  static bool supports(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'script.google.com' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      RegExp(r'^/macros/s/[\w-]+/exec$').hasMatch(uri.path);

  Future<DiaryResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    if (uri.origin != base.origin || !uri.path.startsWith('${base.path}/')) {
      throw const DiaryApiException('Неверный адрес дневника');
    }
    final route = uri.path.substring(base.path.length + 1);
    final authorization = headers['Authorization'];
    late DiaryResponse response;
    if (route == 'public/entries' && method == 'GET' && authorization == null) {
      response = await _connection('GET', uri, {
        'Accept': 'application/json',
      }, null);
    } else {
      if (authorization == null || !authorization.startsWith('Bearer ')) {
        throw const DiaryApiException('Требуется вход автора');
      }
      response = await _connection(
        'POST',
        base,
        {'Accept': 'application/json', 'Content-Type': 'application/json'},
        jsonEncode({
          'method': method,
          'route': route,
          'query': uri.queryParameters,
          'token': authorization.substring(7),
          if (body != null) 'body': jsonDecode(body),
        }),
      );
    }
    // Google returns a signed, short-lived content URL. Do not log or persist it.
    for (
      var redirects = 0;
      response.status == 302 || response.status == 303;
      redirects++
    ) {
      final target = Uri.tryParse(response.headers['location'] ?? '');
      if (redirects >= 3 ||
          target == null ||
          target.scheme != 'https' ||
          target.host != 'script.googleusercontent.com' ||
          target.port != 443 ||
          target.userInfo.isNotEmpty ||
          target.hasFragment) {
        throw const DiaryApiException('Небезопасное перенаправление дневника');
      }
      response = await _connection('GET', target, {
        'Accept': 'application/json',
      }, null);
    }
    if (response.status != 200) return response;
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final status = envelope['status'];
    if (status is! int ||
        status < 200 ||
        status > 599 ||
        envelope['data'] is! Map) {
      throw const DiaryApiException('Неожиданный ответ Apps Script');
    }
    return DiaryResponse(status, jsonEncode(envelope['data']));
  }
}
