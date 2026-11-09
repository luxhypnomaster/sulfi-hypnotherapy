import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_contract_provider.dart';

/// Auth fixtures model grants on the server, not a UI mode in the APK.
/// This provider has no network, Google account, secret or production default.
class FakePublicationServer {
  bool offline = false;
  int revision = 0, writes = 0, uploads = 0;
  String get etag => '"$revision"';
  final manifests = <String, List<Map<String, dynamic>>>{};
  final blobs = <String, Uint8List>{};
  final packages = <String, String>{};
  final receipts = <String, ({String signature, ContractResponse response})>{};
  DiaryContractProvider client({
    required bool author,
  }) => DiaryContractProvider((operation, headers, body) async {
    if (offline) throw StateError('offline fixture');
    ContractResponse error(int code) =>
        ContractResponse.json(code, {'error': code});
    if (operation == 'feed') {
      return ContractResponse.json(
        200,
        {
          'entries': manifests.values.map((v) => v.last).toList(),
          'revision': etag,
          'nextPage': null,
        },
        headers: {'ETag': etag},
      );
    }
    if (operation.startsWith('blob/')) {
      final hash = operation.substring(5);
      final publicHashes = manifests.values
          .expand((versions) => versions)
          .expand(
            (m) => (m['blocks'] as List)
                .where((b) => b['media'] != null)
                .map((b) => b['media']['hash'] as String),
          )
          .toSet();
      final publicPackages = manifests.values
          .expand((versions) => versions)
          .expand(
            (m) => (m['contentLinks'] as List).map(
              (l) =>
                  packages[RevisionKey.fromMap(Map<String, dynamic>.from(l))
                      .token],
            ),
          )
          .whereType<String>()
          .toSet();
      if (!publicHashes.contains(hash) && !publicPackages.contains(hash)) {
        return error(403);
      }
      final bytes = blobs[hash];
      return bytes == null
          ? error(404)
          : ContractResponse(200, Uint8List.fromList(bytes));
    }
    if (!author) return error(403);
    final key = headers['Idempotency-Key'];
    if (key == null || key.isEmpty) return error(400);
    final signature = contentDigest({
      'operation': operation,
      'body': body == null ? null : base64Encode(body),
    });
    final old = receipts[key];
    if (old != null) {
      return old.signature == signature ? old.response : error(409);
    }
    ContractResponse result;
    if (operation.startsWith('upload/')) {
      final hash = operation.substring(7);
      if (body == null || sha256.convert(body).toString() != hash) {
        return error(422);
      }
      if (!blobs.containsKey(hash)) {
        blobs[hash] = Uint8List.fromList(body);
        uploads++;
      }
      result = ContractResponse.json(201, {'digest': hash});
    } else if (operation == 'publish') {
      if (headers['If-Match'] != etag) return error(412);
      final map = Map<String, dynamic>.from(jsonDecode(utf8.decode(body!)));
      final entry = DiaryEntry.fromMap(map);
      if (entry.status != DiaryStatus.published || entry.publishedAt == null) {
        return error(422);
      }
      if (entry.blocks
          .where((b) => b.media != null)
          .any((b) => !blobs.containsKey(b.media!.hash))) {
        return error(422);
      }
      if (entry.contentLinks.any((l) => !packages.containsKey(l.key.token))) {
        return error(422);
      }
      revision++;
      writes++;
      map['version'] = revision;
      manifests
          .putIfAbsent(entry.id, () => [])
          .add(jsonDecode(canonicalContent(map)));
      result = ContractResponse.json(
        200,
        {'id': entry.id},
        headers: {'ETag': etag},
      );
    } else {
      return error(404);
    }
    receipts[key] = (signature: signature, response: result);
    return result;
  });
}
