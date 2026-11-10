import 'dart:convert';

import 'apps_script_diary_transport.dart';
import 'diary_api.dart';

/// New-project protocol. Legacy diary transport and credentials are untouched.
class AlchemistApi {
  AlchemistApi(this.endpoint, {DiaryRequest? connection, this.credential})
    : connection = connection ?? DiaryApi.httpRequest {
    if (!AppsScriptDiaryTransport.supports(endpoint)) {
      throw const FormatException('Требуется проверенный адрес сервера /exec');
    }
  }
  final Uri endpoint;
  final DiaryRequest connection;
  final Future<String?> Function()? credential;
  Future<Map<String, dynamic>> call(
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
      throw const DiaryApiException(
        'Сервер недоступен. Локальные данные сохранены.',
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
      throw DiaryApiException(
        'Сервер отклонил запрос: $code',
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
