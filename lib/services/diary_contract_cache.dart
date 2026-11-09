import 'dart:io';

import 'package:crypto/crypto.dart';

import '../data/diary_repository.dart';
import '../models/diary_entry.dart';
import 'diary_contract_provider.dart';
import 'diary_media_store.dart';

/// Explicitly injected future-provider cache, not wired to the live API.
/// Server supplies immutable digest descriptors; it never supplies a local path.
Future<void> cacheContractDiary(
  DiaryContractProvider provider,
  DiaryRepository repository,
  DiaryMediaStore store,
) async {
  final feed = await provider.feed();
  final entries = <DiaryEntry>[];
  await store.directory.create(recursive: true);
  for (final entry in feed.entries) {
    final blocks = <DiaryBlock>[];
    for (final block in entry.blocks) {
      final media = block.media;
      if (media == null) {
        blocks.add(block);
        continue;
      }
      final hash = media.hash;
      if (hash == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw const FormatException('Invalid media digest');
      }
      final ext = switch (media.mime) {
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        'image/webp' => 'webp',
        'audio/mp4' => 'm4a',
        'audio/wav' => 'wav',
        'audio/mpeg' => 'mp3',
        _ => throw const FormatException('Unsupported media'),
      };
      final file = File('${store.directory.path}/$hash.$ext');
      var valid = false;
      if (await file.exists()) {
        valid =
            await file.length() == media.bytes &&
            (await sha256.bind(file.openRead()).first).toString() == hash;
      }
      if (!valid) {
        final bytes = await provider.blob(hash);
        if (bytes.length != media.bytes) {
          throw const FormatException('Media size mismatch');
        }
        final part = File('${file.path}.part');
        await part.writeAsBytes(bytes, flush: true);
        await part.rename(file.path);
      }
      blocks.add(
        block.copyWith(
          media: DiaryMedia(
            assetId: media.assetId,
            mime: media.mime,
            bytes: media.bytes,
            hash: hash,
            localPath: file.path,
          ),
        ),
      );
    }
    entries.add(entry.copyWith(blocks: blocks));
  }
  // Public cache changes atomically only after all bytes were verified.
  await repository.cache(entries, {}, feed.etag);
}
