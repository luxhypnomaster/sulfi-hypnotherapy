import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/diary_entry.dart';
import '../models/session_plan.dart';
import 'library_service.dart';
import 'mp4_audio.dart';

class DiaryMediaLimits {
  static const imageBytes = 20 * 1024 * 1024;
  static const audioBytes = 100 * 1024 * 1024;
  static const imagePixels = 40000000;
  static int bytes(DiaryBlockType type) =>
      type == DiaryBlockType.image ? imageBytes : audioBytes;
}

typedef DiaryVideoProbe =
    Future<({int width, int height, int durationMs})> Function(File file);

typedef DiaryMediaPicker = Future<AudioSelection?> Function(
  DiaryBlockType type,
);

/// Separate from the user's audio library. Originals are never moved/deleted.
class DiaryMediaStore {
  DiaryMediaStore(
    this.directory, {
    required this.pick,
    required this.probe,
    this.stripImageMetadata = false,
    this.videoProbe,
  });
  final Directory directory;
  final DiaryVideoProbe? videoProbe;
  Future<File?> Function(DiaryMedia)? remoteResolver;
  Future<File?> resolve(DiaryMedia? media) async {
    final local = file(media);
    if (local != null && await local.exists()) {
      if (media?.hash == null ||
          await local.length() == media!.bytes &&
              (await sha256.bind(local.openRead()).first).toString() ==
                  media.hash) {
        return local;
      }
      if (remoteResolver == null) {
        throw const FormatException('Файл вложения повреждён');
      }
    }
    if (media == null) return null;
    return remoteResolver?.call(media);
  }

  final bool stripImageMetadata;
  final DiaryMediaPicker pick;
  final DurationProbe probe;
  Future<DiaryBlock?> import(DiaryBlockType type, {String? blockId}) async {
    final selected = await pick(type);
    if (selected == null) return null;
    return importFile(type, selected, blockId: blockId);
  }

  Future<DiaryBlock> importFile(
    DiaryBlockType type,
    AudioSelection selected, {
    String? blockId,
  }) async {
    if (type == DiaryBlockType.text) {
      throw const FormatException('Выберите изображение или аудио');
    }
    if (type == DiaryBlockType.video) {
      return _importVideo(selected, blockId: blockId);
    }
    final source = File(selected.path);
    var size = await source.length();
    final limit = DiaryMediaLimits.bytes(type);
    if (size == 0 || size > limit) {
      throw FormatException(
        'Файл пустой или больше ${limit ~/ (1024 * 1024)} МБ',
      );
    }
    await directory.create(recursive: true);
    final id = newId();
    final temp = File(p.join(directory.path, '$id.part'));
    try {
      await source.copy(temp.path);
      var data = await temp.readAsBytes();
      if (data.length != size || data.length > limit) {
        throw const FormatException('Файл изменился при копировании');
      }
      String mime, ext;
      int? width, height, duration;
      bool starts(List<int> magic) =>
          data.length >= magic.length &&
          List.generate(
            magic.length,
            (i) => data[i] == magic[i],
          ).every((b) => b);
      String ascii(int a, int b) => String.fromCharCodes(data.sublist(a, b));
      if (type == DiaryBlockType.image) {
        if (starts([137, 80, 78, 71, 13, 10, 26, 10])) {
          mime = 'image/png';
          ext = 'png';
        } else if (starts([255, 216, 255])) {
          mime = 'image/jpeg';
          ext = 'jpg';
        } else if (data.length > 12 &&
            ascii(0, 4) == 'RIFF' &&
            ascii(8, 12) == 'WEBP') {
          mime = 'image/webp';
          ext = 'webp';
        } else {
          throw const FormatException(
            'Поддерживаются только JPEG, PNG и WebP. Видео запрещено.',
          );
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(data);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          width = descriptor.width;
          height = descriptor.height;
          if (width * height > DiaryMediaLimits.imagePixels) {
            throw const FormatException('Изображение больше 40 мегапикселей');
          }
          final codec = await descriptor.instantiateCodec(
            targetWidth: stripImageMetadata ? null : 256,
          );
          try {
            final frame = await codec.getNextFrame();
            try {
              if (stripImageMetadata) {
                width = frame.image.width;
                height = frame.image.height;
                final png = await frame.image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                if (png == null || png.lengthInBytes > limit) {
                  throw const FormatException(
                    'Изображение слишком большое после обработки',
                  );
                }
                data = png.buffer.asUint8List();
                size = data.length;
                mime = 'image/png';
                ext = 'png';
                await temp.writeAsBytes(data, flush: true);
              }
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
          buffer.dispose();
        }
      } else {
        if (data.length > 12 &&
            ascii(0, 4) == 'RIFF' &&
            ascii(8, 12) == 'WAVE') {
          mime = 'audio/wav';
          ext = 'wav';
        } else if (isAudioOnlyMp4(data)) {
          mime = 'audio/mp4';
          ext = 'm4a';
        } else if (data.length > 2 &&
            data[0] == 255 &&
            (data[1] & 246) == 240) {
          mime = 'audio/aac';
          ext = 'aac';
        } else if (starts([73, 68, 51]) ||
            (data.length > 2 && data[0] == 255 && (data[1] & 224) == 224)) {
          mime = 'audio/mpeg';
          ext = 'mp3';
        } else if (starts([79, 103, 103, 83])) {
          mime = 'audio/ogg';
          ext = 'ogg';
        } else if (data.length > 2 &&
            data[0] == 255 &&
            (data[1] & 246) == 240) {
          mime = 'audio/aac';
          ext = 'aac';
        } else {
          throw const FormatException(
            'Поддерживаются MP3, M4A, WAV, AAC и OGG. Видеоконтейнеры запрещены.',
          );
        }
        // Some native decoders require the correct extension.
      }
      final persisted = await temp.open(mode: FileMode.append);
      try {
        await persisted.flush();
      } finally {
        await persisted.close();
      }
      final target = File(p.join(directory.path, '$id.$ext'));
      await temp.rename(target.path);
      try {
        if (type == DiaryBlockType.audio) {
          final decoded = await probe(target.path);
          if (decoded == null || decoded.inMilliseconds <= 0) {
            throw const FormatException('Аудио не удалось декодировать');
          }
          duration = decoded.inMilliseconds;
        }
        return DiaryBlock(
          id: blockId ?? newId(),
          type: type,
          media: DiaryMedia(
            assetId: id,
            mime: mime,
            bytes: size,
            localPath: target.path,
            hash: sha256.convert(data).toString(),
          ),
          width: width,
          height: height,
          durationMs: duration,
          label: p.basenameWithoutExtension(selected.name),
        );
      } catch (_) {
        if (await target.exists()) await target.delete();
        rethrow;
      }
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<DiaryBlock> _importVideo(
    AudioSelection selected, {
    String? blockId,
  }) async {
    final source = File(selected.path),
        size = await File(selected.path).length();
    if (size < 16) throw const FormatException('Видеофайл пуст или повреждён');
    final input = await source.open();
    late final List<int> header;
    try {
      header = await input.read(64);
    } finally {
      await input.close();
    }
    final ext = p.extension(selected.name).toLowerCase();
    String mime;
    if (header.length >= 12 &&
        String.fromCharCodes(header.sublist(4, 8)) == 'ftyp' &&
        ['.mp4', '.mov', '.m4v'].contains(ext)) {
      mime = ext == '.mov' ? 'video/quicktime' : 'video/mp4';
    } else if (header.length >= 4 &&
        header[0] == 0x1a &&
        header[1] == 0x45 &&
        header[2] == 0xdf &&
        header[3] == 0xa3 &&
        ext == '.webm') {
      mime = 'video/webm';
    } else {
      throw const FormatException('Поддерживаются видео MP4/MOV/WebM');
    }
    if (videoProbe == null) {
      throw const FormatException('Проверка видеокодека недоступна');
    }
    await directory.create(recursive: true);
    final id = newId(), temp = File(p.join(directory.path, '$id.part'));
    File? target;
    try {
      await source.copy(temp.path);
      if (await temp.length() != size) {
        throw const FormatException('Видео изменилось при копировании');
      }
      target = await temp.rename(p.join(directory.path, '$id$ext'));
      final info = await videoProbe!(target);
      if (info.durationMs <= 0 || info.width <= 0 || info.height <= 0) {
        throw const FormatException(
          'Видеокодек не поддерживается на этом устройстве',
        );
      }
      final hash = (await sha256.bind(target.openRead()).first).toString();
      return DiaryBlock(
        id: blockId ?? newId(),
        type: DiaryBlockType.video,
        media: DiaryMedia(
          assetId: id,
          mime: mime,
          bytes: size,
          localPath: target.path,
          hash: hash,
        ),
        width: info.width,
        height: info.height,
        durationMs: info.durationMs,
        label: p.basenameWithoutExtension(selected.name),
      );
    } catch (_) {
      if (target != null && await target.exists()) await target.delete();
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  File? file(DiaryMedia? media) {
    if (media == null) return null;
    String? location = media.localPath;
    if (location == null &&
        media.hash != null &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(media.hash!)) {
      final ext = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/webp': 'webp',
        'audio/mpeg': 'mp3',
        'audio/mp4': 'm4a',
        'audio/wav': 'wav',
        'audio/aac': 'aac',
        'audio/ogg': 'ogg',
        'video/mp4': 'mp4',
        'video/quicktime': 'mov',
        'video/webm': 'webm',
      }[media.mime];
      if (ext != null) location = p.join(directory.path, '${media.hash}.$ext');
    }
    if (location == null) return null;
    final path = p.normalize(location);
    if (!p.isWithin(directory.absolute.path, p.absolute(path))) return null;
    return File(path);
  }

  /// Call only with ALL author and public references, never just visible rows.
  Future<void> collect(Set<String> retainedPaths) async {
    if (!await directory.exists()) return;
    await for (final f in directory.list()) {
      if (f is File && !retainedPaths.contains(f.path)) await f.delete();
    }
  }
}
