import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/mp4_audio.dart';
import 'package:sulfi_hypnotherapy/services/recorder_service.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

import 'support/fakes.dart';
import 'support/capture_fake.dart';

class Mp4Capture extends FakeCapture {
  @override
  Future<void> start(String value) async {
    await super.start(value);
    await File('test/fixtures/android_aac_isom.m4a').copy(value);
  }
}

void main() {
  late Directory root;
  late DiaryMediaStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task5-media');
    store = DiaryMediaStore(
      Directory('${root.path}/diary_media'),
      pick: (_) async => null,
      probe: (_) async => const Duration(seconds: 12),
    );
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'Android isom AAC is audio; video handler and truncated boxes rejected',
    () async {
      final bytes = await File('test/fixtures/android_aac_isom.m4a')
          .readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'isom');
      expect(isAudioOnlyMp4(bytes), isTrue);
      final handler = String.fromCharCodes(bytes).indexOf('soun');
      final video = Uint8List.fromList(bytes)
        ..setRange(handler, handler + 4, 'vide'.codeUnits);
      expect(isAudioOnlyMp4(video), isFalse);
      expect(
        isAudioOnlyMp4(Uint8List.sublistView(bytes, 0, bytes.length - 2)),
        isFalse,
      );
    },
  );
  test('record -> diary attach preserves bytes, stable media ID and no library rows', () async {
    final repo = MemoryRepository();
    final recorder = RecorderService(
      backend: Mp4Capture(),
      library: LibraryService(
        repository: repo,
        directory: Directory('${root.path}/audio'),
        pick: () async => null,
        probe: (_) async => const Duration(seconds: 12),
      ),
      tempDirectory: Directory('${root.path}/takes'),
    );
    await recorder.start();
    await recorder.finish();
    final path = recorder.path!;
    final block = await recorder.saveTo(
      (path) => store.importFile(DiaryBlockType.audio, (
        name: 'recording.m4a',
        path: path,
      )),
    );
    expect(recorder.error, isNull);
    expect(block!.durationMs, 12000);
    expect(block.media!.assetId, isNotEmpty);
    expect(
      await store.file(block.media)!.readAsBytes(),
      await File('test/fixtures/android_aac_isom.m4a').readAsBytes(),
    );
    expect(await File(path).exists(), isFalse);
    expect(await repo.list(), isEmpty);
    final restored = DiaryBlock.fromMap(block.toMap());
    expect(restored.media!.assetId, block.media!.assetId);
    await recorder.close();
  });
  test('failed attachment retains raw take for retry and does not blame microphone', () async {
    final recorder = RecorderService(
      backend: Mp4Capture(),
      library: LibraryService(
        repository: MemoryRepository(),
        directory: Directory('${root.path}/audio'),
        pick: () async => null,
        probe: (_) async => const Duration(seconds: 12),
      ),
      tempDirectory: Directory('${root.path}/takes'),
    );
    await recorder.start();
    await recorder.finish();
    final path = recorder.path!;
    await recorder.saveTo<Object>(
      (_) async => throw const FormatException('Не удалось декодировать аудио'),
    );
    expect(await File(path).exists(), isTrue);
    expect(recorder.canSave, isTrue);
    expect(recorder.error, 'Не удалось декодировать аудио');
    expect(
      (await recorder.saveTo(
        (path) => store.importFile(DiaryBlockType.audio, (
          name: 'retry.m4a',
          path: path,
        )),
      ))!.media,
      isNotNull,
    );
    await recorder.close();
  });
  test('phone import copies original and failed import leaves prior attachment intact', () async {
    final original = File('test/fixtures/android_aac_isom.m4a');
    final first = await store.importFile(DiaryBlockType.audio, (
      name: 'original.m4a',
      path: original.path,
    ));
    final bad = File('${root.path}/bad.m4a');
    await bad.writeAsBytes([1, 2, 3]);
    await expectLater(
      store.importFile(DiaryBlockType.audio, (name: 'bad.m4a', path: bad.path)),
      throwsFormatException,
    );
    expect(await original.exists(), isTrue);
    expect(await store.file(first.media)!.exists(), isTrue);
    expect(await store.directory.list().length, 1);
  });
}
