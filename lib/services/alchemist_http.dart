import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'alchemist_diagnostics.dart';
import 'diary_api.dart';

/// Bounded response and keep-alive pool per HTTP override (native app / tests).
/// Cookies/authorization are not installed on the pool; each request is fresh.
class AlchemistHttp {
  const AlchemistHttp({
    this.responseTimeout = const Duration(seconds: 90),
    this.reuseConnections = true,
  });
  final Duration responseTimeout;
  final bool reuseConnections;
  static final Map<HttpOverrides?, HttpClient> _clients = {};
  Future<DiaryResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    HttpClient create() => HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 2;
    final client = reuseConnections
        ? _clients.putIfAbsent(HttpOverrides.current, create)
        : create();
    HttpClientRequest? request;
    final clock = Stopwatch()..start();
    String? trace, op;
    try {
      final m = body == null ? null : jsonDecode(body);
      if (m is Map) {
        trace = m['traceId'] as String?;
        op = m['operation'] as String?;
      }
    } catch (_) {}
    void measure(String phase) {
      if (trace != null && op != null) {
        AlchemistDiagnostics.instance.record(
          trace,
          op,
          phase,
          clock.elapsedMilliseconds,
        );
      }
    }

    try {
      request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 20));
      measure('connect_including_dns_tls');
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) request.add(utf8.encode(body));
      final response = await request.close().timeout(responseTimeout);
      measure('headers');
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const DiaryApiException('Слишком большой ответ сервера');
        }
      }
      measure('body');
      return DiaryResponse(
        response.statusCode,
        utf8.decode(bytes),
        headers: {
          if (response.headers.value('location') case final String value)
            'location': value,
          if (response.headers.contentType?.mimeType case final String mime)
            'content-type': mime,
        },
      );
    } catch (e) {
      request?.abort();
      rethrow;
    } finally {
      if (!reuseConnections) client.close(force: true);
    }
  }
}
