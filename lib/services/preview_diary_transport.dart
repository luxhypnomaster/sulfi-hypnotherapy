import 'dart:async';
import 'dart:io';

import '../models/audio_asset.dart';
import '../models/diary_entry.dart';
import 'diary_audio.dart';
import 'preview_player.dart';

/// Adapter only: diary and library share one actual player and audio focus.
class PreviewDiaryTransport implements DiaryAudioTransport {
  PreviewDiaryTransport(this.player) {
    player.addListener(changed);
  }
  final PreviewPlayer player;
  DiaryBlock? block;
  String? path;
  final stream = StreamController<void>.broadcast();
  void changed() => stream.add(null);
  String get id => 'diary:${block?.media?.assetId}';
  @override
  Stream<void> get changes => stream.stream;
  @override
  bool get playing => player.current?.id == id && player.playing;
  @override
  bool get completed => player.current?.id == id && player.completed;
  @override
  Duration get position =>
      player.current?.id == id ? player.position : Duration.zero;
  @override
  Duration? get duration => block?.durationMs == null
      ? null
      : Duration(milliseconds: block!.durationMs!);
  @override
  Future<void> load(String path) async {
    this.path = path;
  }

  @override
  Future<void> play() async {
    if ((player.current?.id == id && player.playing) ||
        block == null ||
        path == null) {
      return;
    }
    await player.toggle(
      AudioAsset(
        id: id,
        source: 'diary_attachment',
        origin: 'personal',
        title: block!.label.isEmpty ? 'Аудио дневника' : block!.label,
        filePath: 'attachment.m4a',
        durationMs: block!.durationMs!,
        format: 'm4a',
        createdAt: DateTime.now(),
        category: AudioCategory.freeform,
        fileSizeBytes: block!.media!.bytes,
      ),
      File(path!),
    );
  }

  @override
  Future<void> pause() async {
    if (player.current?.id == id && playing) {
      await player.toggle(
        player.current!,
        player.currentFile ?? File(block?.media?.localPath ?? path ?? ''),
      );
    }
  }

  @override
  Future<void> seek(Duration p) =>
      player.current?.id == id ? player.seek(p) : Future.value();
  @override
  Future<void> dispose() async {
    player.removeListener(changed);
    await stream.close();
  }
}
