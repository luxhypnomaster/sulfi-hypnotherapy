import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'apps_script_diary_transport.dart';
import 'alchemist_http.dart';
import 'diary_api.dart';

class AlchemistApiException extends DiaryApiException {
  const AlchemistApiException(
    super.message,
    this.status,
    this.code, [
    super.kind,
  ]);
  final int status;
  final String code;
}

/// New-project protocol. Legacy diary transport and credentials are untouched.
class AlchemistApi {
  AlchemistApi(
    this.endpoint, {
    DiaryRequest? connection,
    this.credential,
    this.maxAttempts = 3,
  }) : connection = connection ?? const AlchemistHttp().request {
    if (!AppsScriptDiaryTransport.supports(endpoint)) {
      throw const FormatException('Требуется проверенный адрес сервера /exec');
    }
  }
  final int maxAttempts;
  final Uri endpoint;
  final DiaryRequest connection;
  final Future<String?> Function()? credential;
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _once(operation, parameters);
      } catch (e) {
        final retryable =
            e is SocketException ||
            e is TimeoutException ||
            e is AlchemistApiException && [429, 503].contains(e.status);
        if (!retryable || attempt + 1 >= maxAttempts) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: (250 << attempt) + Random().nextInt(200)),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _once(
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    final token = await credential?.call();
    var response = await connection(
      'POST',
      endpoint,
      {'Accept': 'application/json', 'Content-Type': 'application/json'},
      jsonEncode({
        'version': 1,
        'operation': operation,
        'parameters': parameters,
        'credential': ?token,
      }),
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
      // Never forward the POST payload or credential to the redirect host.
      response = await connection('GET', target, {
        'Accept': 'application/json',
      }, null);
    }
    if (response.status != 200) {
      throw AlchemistApiException(
        'Сервер недоступен. Локальные данные сохранены.',
        response.status,
        'HTTP_SERVER_UNAVAILABLE',
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
      final rawCode = value['error'] is Map ? value['error']['code'] : null;
      final code =
          rawCode is String && RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(rawCode)
          ? rawCode
          : 'REQUEST_REJECTED';
      throw AlchemistApiException(
        'Сервер отклонил запрос: $code',
        status,
        code,
        status == 401 || status == 403
            ? DiaryFailure.authorization
            : status == 409 || status == 412
            ? DiaryFailure.conflict
            : DiaryFailure.network,
      );
    }
    if (value['result'] is! Map) {
      throw const DiaryApiException('Неожиданный результат сервера');
    }
    return Map<String, dynamic>.from(value['result']);
  }
}
