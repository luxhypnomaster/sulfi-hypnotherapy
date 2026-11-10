import 'dart:convert';
import 'dart:io';

import 'diary_api.dart';

/// Apps Script may spend over 20 seconds committing private Drive metadata.
/// Keep connection/body deadlines short, but allow a bounded server execution.
/// Legacy diary HTTP behavior is deliberately unchanged.
class AlchemistHttp {
  const AlchemistHttp({this.responseTimeout = const Duration(minutes: 5)});

  final Duration responseTimeout;

  Future<DiaryResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) request.add(utf8.encode(body));
      final response = await request.close().timeout(responseTimeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const DiaryApiException('Слишком большой ответ сервера');
        }
      }
      return DiaryResponse(
        response.statusCode,
        utf8.decode(bytes),
        headers: {
          if (response.headers.value('location') case final String location)
            'location': location,
          if (response.headers.contentType?.mimeType case final String mime)
            'content-type': mime,
        },
      );
    } finally {
      client.close(force: true);
    }
  }
}
