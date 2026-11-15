import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_media_transfer.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

import 'support/task15_fixture.dart';

void main() {
  test('18 lost upload ack reconciles exact same request before replay; receipt and bytes survive', () async {
    final f = await Fixture15.open();
    final file = File('${f.root.path}/controlled18.raw');
    final bytes = List<int>.generate(400001, (i) => i % 251);
    await file.writeAsBytes(bytes);
    final hash = sha256.convert(bytes).toString();
    var offset = 0, beginCount = 0, applied = 0, loss = true;
    String? requestId;
    final events = <String>[];
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/controlled18/exec'),
      delay: (_) async {},
      connection: (_, _, _, body) async {
        final e = jsonDecode(body!);
        final op = e['operation'];
        final p = e['parameters'];
        events.add(op);
        Map<String, dynamic> result;
        switch (op) {
          case 'media.beginUpload':
            beginCount++;
            requestId ??= p['requestId'];
            expect(p['requestId'], requestId);
            result = {'sessionId': 'one-session', 'offset': offset};
          case 'media.uploadChunk':
            final n = base64Decode(p['base64']).length;
            if (p['offset'] == offset) {
              offset += n;
              applied++;
            }
            if (loss) {
              loss = false;
              throw const SocketException('CONTROLLED_LOST_ACK');
            }
            result = {'offset': offset};
          case 'media.commitUpload':
            result = {
              'assetRevisionId': 'confirmed18',
              'logicalId': 'track18',
              'revisionId': 'rev18',
              'sha256': hash,
              'byteLength': bytes.length,
            };
          case 'media.getDescriptor':
            result = {
              'assetRevisionId': 'confirmed18',
              'logicalId': 'track18',
              'revisionId': 'rev18',
              'sha256': hash,
              'byteLength': bytes.length,
              'mime': 'audio/wav',
            };
          default:
            throw StateError('Unexpected fixture operation');
        }
        return DiaryResponse(
          200,
          jsonEncode({'ok': true, 'status': 200, 'result': result}),
        );
      },
    );
    try {
      final receipt = await AlchemistMediaTransfer(f.db, api).upload(
        file,
        logicalId: 'track18',
        revisionId: 'rev18',
        mime: 'audio/wav',
      );
      expect(receipt['assetRevisionId'], 'confirmed18');
      expect(beginCount, 2);
      expect(applied, 2);
      expect(events.take(4), [
        'media.beginUpload',
        'media.uploadChunk',
        'media.beginUpload',
        'media.uploadChunk',
      ]);
      final row = (await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_upload:%'],
      )).single;
      final checkpoint = jsonDecode(row['value'] as String);
      expect(checkpoint['offset'], bytes.length);
      expect(checkpoint['requestId'], requestId);
      expect(checkpoint['receipt'], receipt);
      events.clear();
      await AlchemistMediaTransfer(f.db, api).upload(
        file,
        logicalId: 'track18',
        revisionId: 'rev18',
        mime: 'audio/wav',
      );
      expect(events, ['media.getDescriptor']);
      expect(applied, 2);
      expect(await file.readAsBytes(), bytes);
    } finally {
      await f.close();
    }
  });
}
