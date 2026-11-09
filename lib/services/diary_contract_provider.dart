import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/content_revision.dart';
import '../models/diary_entry.dart';
import 'diary_publication_diff.dart';

/// Injected contract transport only: no default HTTP/OAuth implementation.
/// A future Apps Script adapter must map these operations to doGet/doPost.
class ContractResponse {
  ContractResponse(this.status, this.bytes, {this.headers = const {}});
  final int status;
  final Uint8List bytes;
  final Map<String, String> headers;
  factory ContractResponse.json(
    int status,
    Object body, {
    Map<String, String> headers = const {},
  }) => ContractResponse(
    status,
    Uint8List.fromList(utf8.encode(jsonEncode(body))),
    headers: headers,
  );
  dynamic get json => jsonDecode(utf8.decode(bytes));
}

typedef ContractRequest = Future<ContractResponse> Function(
  String operation,
  Map<String, String> headers,
  Uint8List? body,
);

class ContractFailure implements Exception {
  ContractFailure(this.status);
  final int status;
  @override
  String toString() => 'Contract request failed: $status';
}

class DiaryContractProvider {
  DiaryContractProvider(this.request);
  final ContractRequest request;
  Future<ContractResponse> _call(
    String operation, {
    Map<String, String> headers = const {},
    Object? json,
    Uint8List? bytes,
  }) async {
    final r = await request(
      operation,
      headers,
      bytes ??
          (json == null
              ? null
              : Uint8List.fromList(utf8.encode(canonicalContent(json)))),
    );
    if (r.status < 200 || r.status >= 300) throw ContractFailure(r.status);
    return r;
  }

  Future<({List<DiaryEntry> entries, String etag})> feed() async {
    final r = await _call('feed');
    return (
      entries: (r.json['entries'] as List)
          .map((v) => DiaryEntry.fromMap(Map<String, dynamic>.from(v)))
          .toList(),
      etag: r.headers['ETag']!,
    );
  }

  Future<String> publish(
    DiaryEntry e, {
    required String ifMatch,
    required String idempotencyKey,
  }) async {
    final r = await _call(
      'publish',
      headers: {'If-Match': ifMatch, 'Idempotency-Key': idempotencyKey},
      json: diaryPublicManifest(e),
    );
    return r.headers['ETag']!;
  }

  Future<void> upload(
    String digest,
    Uint8List bytes, {
    required String idempotencyKey,
  }) async {
    if (sha256.convert(bytes).toString() != digest) {
      throw const FormatException('Blob SHA-256 mismatch');
    }
    await _call(
      'upload/$digest',
      headers: {'Idempotency-Key': idempotencyKey},
      bytes: bytes,
    );
  }

  Future<Uint8List> blob(String digest) async {
    final r = await _call('blob/$digest');
    if (sha256.convert(r.bytes).toString() != digest) {
      throw const FormatException('Blob SHA-256 mismatch');
    }
    return r.bytes;
  }
}
