import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_install.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

import 'support/task15_fixture.dart';

void main() {
  const chunkSize = 262144;
  final bytes = List<int>.generate(
    chunkSize * 2 + 31,
    (i) => (i * 17 + 3) % 256,
  );
  final hash = sha256.convert(bytes).toString();
  final descriptor = <String, dynamic>{
    'assetRevisionId': 'fixture18',
    'sha256': hash,
    'byteLength': bytes.length,
  };
  const endpoint = 'https://script.google.com/macros/s/controlled18/exec';

  test('18 download survives interruption; validates saved prefix and truncates only unconfirmed tail', () async {
    final f = await Fixture15.open();
    var failAtSecond = true;
    final offsets = <int>[];
    final api = AlchemistApi(
      Uri.parse(endpoint),
      maxAttempts: 1,
      connection: (_, _, _, body) async {
        final q = jsonDecode(body!);
        final op = q['operation'];
        final p = q['parameters'];
        if (op == 'media.finalizeDownload') {
          return DiaryResponse(
            200,
            jsonEncode({
              'ok': true,
              'status': 200,
              'result': {'verified': true, 'assetRevisionId': 'fixture18'},
            }),
          );
        }
        final offset = p['offset'] as int;
        offsets.add(offset);
        if (offset == chunkSize && failAtSecond) {
          throw const SocketException('controlled interruption');
        }
        final data = bytes.sublist(
          offset,
          (offset + chunkSize).clamp(0, bytes.length),
        );
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {
              'base64': base64Encode(data),
              'offset': offset,
              'byteLength': bytes.length,
              'sha256': hash,
              'chunkSha256': sha256.convert(data).toString(),
            },
          }),
        );
      },
    );
    try {
      final install = AlchemistInstall(f.c.capsules!, api);
      await expectLater(
        install.downloadAsset(descriptor),
        throwsA(isA<AlchemistFailure>()),
      );
      final stage = File(
        '${f.root.path}/alchemist_transfers/public/$hash.part',
      );
      expect(await stage.length(), chunkSize);
      final source = File('${f.root.path}/audio/untouched.bin');
      await source.writeAsBytes([4, 3, 2, 1]);
      await stage.writeAsBytes([9, 8, 7], mode: FileMode.append);
      failAtSecond = false;
      offsets.clear();
      final result = await AlchemistInstall(
        f.c.capsules!,
        api,
      ).downloadAsset(descriptor);
      expect(offsets, [chunkSize, chunkSize * 2]);
      expect(await result.readAsBytes(), bytes);
      expect(await source.readAsBytes(), [4, 3, 2, 1]);
      final ledger = (await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_download_receipt:%'],
      )).single;
      final receipt = jsonDecode(ledger['value'] as String);
      expect(receipt['receipt']['verified'], true);
      expect(receipt['assetRevisionId'], 'fixture18');
      expect(receipt['sha256'], hash);
      offsets.clear();
      await install.downloadAsset(descriptor);
      expect(
        offsets,
        isEmpty,
        reason: 'complete exact bytes reused without another download',
      );
    } finally {
      await f.close();
    }
  });

  test('18 corrupt saved chunk stops before network/installation and preserves diagnostic bytes', () async {
    final f = await Fixture15.open();
    var interrupt = true, calls = 0;
    final api = AlchemistApi(
      Uri.parse(endpoint),
      maxAttempts: 1,
      connection: (_, _, _, body) async {
        final p = jsonDecode(body!)['parameters'];
        calls++;
        final offset = p['offset'] as int;
        if (offset == chunkSize && interrupt) {
          throw const SocketException('controlled');
        }
        final data = bytes.sublist(
          offset,
          (offset + chunkSize).clamp(0, bytes.length),
        );
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {
              'offset': offset,
              'base64': base64Encode(data),
              'byteLength': bytes.length,
              'sha256': hash,
              'chunkSha256': sha256.convert(data).toString(),
            },
          }),
        );
      },
    );
    try {
      await expectLater(
        AlchemistInstall(f.c.capsules!, api).downloadAsset(descriptor),
        throwsA(isA<AlchemistFailure>()),
      );
      final part = File('${f.root.path}/alchemist_transfers/public/$hash.part');
      final corrupt = await part.readAsBytes();
      corrupt[2] ^= 255;
      await part.writeAsBytes(corrupt);
      calls = 0;
      interrupt = false;
      await expectLater(
        AlchemistInstall(f.c.capsules!, api).downloadAsset(descriptor),
        throwsA(anything),
      );
      expect(calls, 0);
      expect(await part.readAsBytes(), corrupt);
      expect(await f.c.library.repository.list(), isEmpty);
    } finally {
      await f.close();
    }
  });

  test('18 no server chunk support is explicit compatibility failure, no full-file fallback', () async {
    final f = await Fixture15.open();
    var calls = 0;
    final api = AlchemistApi(
      Uri.parse(endpoint),
      maxAttempts: 1,
      connection: (_, _, _, _) async {
        calls++;
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': false,
            'status': 501,
            'error': {'code': 'OPERATION_NOT_SUPPORTED'},
          }),
        );
      },
    );
    try {
      await expectLater(
        AlchemistInstall(f.c.capsules!, api).downloadAsset(descriptor),
        throwsA(
          isA<AlchemistFailure>().having(
            (e) => e.code,
            'code',
            'CHUNK_RESUME_UNAVAILABLE',
          ),
        ),
      );
      expect(calls, 1);
      expect(await f.c.library.repository.list(), isEmpty);
    } finally {
      await f.close();
    }
  });
  test('18 wrong final receipt cannot mark download successful; retry reuses checked bytes', () async {
    final f = await Fixture15.open();
    var valid = false, chunks = 0, finals = 0;
    final api = AlchemistApi(
      Uri.parse(endpoint),
      maxAttempts: 1,
      connection: (_, _, _, body) async {
        final q = jsonDecode(body!), p = q['parameters'];
        if (q['operation'] == 'media.finalizeDownload') {
          finals++;
          return DiaryResponse(
            200,
            jsonEncode({
              'ok': true,
              'status': 200,
              'result': {'verified': valid, 'assetRevisionId': 'fixture18'},
            }),
          );
        }
        chunks++;
        final offset = p['offset'] as int;
        final data = bytes.sublist(
          offset,
          (offset + chunkSize).clamp(0, bytes.length),
        );
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {
              'offset': offset,
              'byteLength': bytes.length,
              'sha256': hash,
              'base64': base64Encode(data),
              'chunkSha256': sha256.convert(data).toString(),
            },
          }),
        );
      },
    );
    try {
      final install = AlchemistInstall(f.c.capsules!, api);
      await expectLater(
        install.downloadAsset(descriptor),
        throwsA(
          isA<AlchemistFailure>().having(
            (e) => e.code,
            'code',
            'DOWNLOAD_RECEIPT_INVALID',
          ),
        ),
      );
      expect(await f.c.library.repository.list(), isEmpty);
      expect(
        await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_download_receipt:%'],
        ),
        isEmpty,
      );
      final sent = chunks;
      valid = true;
      final restored = await install.downloadAsset(descriptor);
      expect(chunks, sent);
      expect(finals, 2);
      expect((await sha256.bind(restored.openRead()).first).toString(), hash);
      expect(
        (await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_download_receipt:%'],
        )).length,
        1,
      );
    } finally {
      await f.close();
    }
  });
}
