import 'dart:convert';
import 'dart:io';

import '../models/diary_entry.dart';

class DiaryApiException implements Exception {
  const DiaryApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DiaryResponse {
  const DiaryResponse(this.status, this.body, {this.headers = const {}});
  final int status;
  final String body;
  final Map<String, String> headers;
}

typedef DiaryRequest = Future<DiaryResponse> Function(
  String method,
  Uri uri,
  Map<String, String> headers,
  String? body,
);

class DiaryAuthorSession {
  DiaryAuthorSession._(this._token, this.expiresAt);
  final String _token;
  final DateTime expiresAt;
  bool get valid => expiresAt.isAfter(DateTime.now().toUtc());
}

class DiaryPage {
  DiaryPage({
    required this.entries,
    required this.removedIds,
    required this.revision,
    this.nextPage,
  });
  final List<DiaryEntry> entries;
  final Set<String> removedIds;
  final String revision;
  final String? nextPage;
}

/// No credentials in configuration. Identity tokens are kept only in RAM.
class DiaryApi {
  DiaryApi(this.base, {DiaryRequest? request})
    : _request = request ?? httpRequest {
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const DiaryApiException('Для дневника нужен HTTPS адрес сервера');
    }
  }
  final Uri base;
  final DiaryRequest _request;
  Uri _uri(String path, [Map<String, String>? query]) => base.replace(
    path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/$path',
    queryParameters: query,
  );
  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    DiaryAuthorSession? session,
    Map<String, Object?>? body,
  }) async {
    if (session != null && !session.valid) {
      throw const DiaryApiException('Авторизация истекла');
    }
    final response = await _request(method, _uri(path, query), {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session._token}',
    }, body == null ? null : jsonEncode(body));
    if (response.status == 401 || response.status == 403) {
      throw const DiaryApiException('Нет авторских прав. Войдите заново.');
    }
    if (response.status == 409 || response.status == 412) {
      throw const DiaryApiException(
        'Запись изменена на сервере. Обновите её перед публикацией.',
      );
    }
    if (response.status < 200 || response.status >= 300) {
      throw const DiaryApiException('Сервер дневника недоступен');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<DiaryPage> feed({String? since, String? page}) async {
    final m = await _json(
      'GET',
      'public/entries',
      query: {'since': ?since, 'page': ?page, 'limit': '50'},
    );
    final entries = (m['entries'] as List)
        .map((v) => DiaryEntry.fromMap(v as Map<String, dynamic>))
        .toList();
    if (entries.any(
      (e) => e.status != DiaryStatus.published || e.publishedAt == null,
    )) {
      throw const DiaryApiException('Сервер вернул непубличную запись');
    }
    return DiaryPage(
      entries: entries,
      removedIds: (m['removedIds'] as List).cast<String>().toSet(),
      revision: m['revision'] as String,
      nextPage: m['nextPage'] as String?,
    );
  }

  Future<DiaryAuthorSession> authenticate(String token) async {
    if (token.trim().isEmpty || token.contains(RegExp(r'[\r\n]'))) {
      throw const DiaryApiException('Войдите через Google заново');
    }
    final pending = DiaryAuthorSession._(
      token.trim(),
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    final m = await _json('GET', 'author/me', session: pending);
    final expires = DateTime.parse(m['expiresAt'] as String).toUtc();
    if (m['canPublish'] != true || !expires.isAfter(DateTime.now().toUtc())) {
      throw const DiaryApiException('Нет авторских прав');
    }
    return DiaryAuthorSession._(token.trim(), expires);
  }

  Future<DiaryEntry> publish(
    DiaryEntry entry,
    DiaryAuthorSession session, {
    required bool published,
  }) async {
    final m = await _json(
      'PUT',
      'author/entries/${Uri.encodeComponent(entry.id)}',
      session: session,
      body: {
        'expectedVersion': entry.version,
        'entry': entry.toMap(),
        'publish': published,
      },
    );
    final result = DiaryEntry.fromMap(m['entry'] as Map<String, dynamic>);
    if (result.id != entry.id ||
        result.status !=
            (published ? DiaryStatus.published : DiaryStatus.unpublished) ||
        result.version <= entry.version) {
      throw const DiaryApiException(
        'Сервер не подтвердил изменение публикации',
      );
    }
    return result;
  }

  Future<DiaryEntry> saveAuthorDraft(
    DiaryEntry entry,
    DiaryAuthorSession session,
  ) async {
    final m = await _json(
      'PUT',
      'author/entries/${Uri.encodeComponent(entry.id)}',
      session: session,
      body: {'expectedVersion': entry.version, 'entry': entry.toMap()},
    );
    final result = DiaryEntry.fromMap(m['entry'] as Map<String, dynamic>);
    if (result.id != entry.id ||
        result.version <= entry.version ||
        result.message != entry.message ||
        result.body != entry.body) {
      throw const DiaryApiException(
        'Сервер не подтвердил сохранение черновика',
      );
    }
    return result;
  }

  Future<List<DiaryEntry>> authorDrafts(DiaryAuthorSession session) async {
    final entries = <DiaryEntry>[];
    final seen = <String>{};
    String? page;
    do {
      final m = await _json(
        'GET',
        'author/entries',
        session: session,
        query: {'page': ?page, 'limit': '50'},
      );
      entries.addAll(
        (m['entries'] as List).map(
          (v) => DiaryEntry.fromMap(v as Map<String, dynamic>),
        ),
      );
      page = m['nextPage'] as String?;
      if (page != null && (!seen.add(page) || seen.length > 100)) {
        throw const DiaryApiException('Ошибка страниц авторского дневника');
      }
    } while (page != null);
    return entries;
  }

  static Future<DiaryResponse> httpRequest(
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
      request.followRedirects =
          false; // Never forward an author token to a redirect.
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const DiaryApiException('Слишком большой ответ дневника');
        }
      }
      return DiaryResponse(
        response.statusCode,
        utf8.decode(bytes),
        headers: {
          if (response.headers.value('location') case final String location)
            'location': location,
        },
      );
    } finally {
      client.close(force: true);
    }
  }
}
