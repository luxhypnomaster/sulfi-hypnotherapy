import '../services/session_audio_handler.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import '../services/diary_controller.dart';

Future<({int width, int height, int durationMs})> probeDiaryVideo(
  File file,
) async {
  final controller = VideoPlayerController.file(file);
  try {
    await controller.initialize().timeout(const Duration(seconds: 30));
    if (controller.value.hasError) {
      throw const FormatException('Кодек видео не поддерживается');
    }
    return (
      width: controller.value.size.width.round(),
      height: controller.value.size.height.round(),
      durationMs: controller.value.duration.inMilliseconds,
    );
  } catch (_) {
    throw const FormatException(
      'Видео не удалось декодировать на этом устройстве',
    );
  } finally {
    await controller.dispose();
  }
}

class DiaryVideo extends StatefulWidget {
  const DiaryVideo({super.key, required this.block, this.diary});
  final DiaryBlock block;
  final DiaryController? diary;
  @override
  State<DiaryVideo> createState() => _DiaryVideoState();
}

class _DiaryVideoState extends State<DiaryVideo> with WidgetsBindingObserver {
  VideoPlayerController? player;
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player?.pause();
  }

  Future<void> open() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    VideoPlayerController? next;
    try {
      if (sessionAudioHandler?.engine?.active ?? false) {
        throw const FormatException('Сначала завершите сессию');
      }
      await widget.diary?.pauseReaders();
      final file = await widget.diary?.mediaStore?.resolve(widget.block.media);
      if (file == null || !await file.exists()) {
        throw const FormatException(
          'Видео недоступно офлайн. Проверьте сеть и повторите.',
        );
      }
      next = VideoPlayerController.file(file);
      await next.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) {
        await next.dispose();
        return;
      }
      await player?.dispose();
      player = next;
      next = null;
      player!.addListener(changed);
      await player!.play();
    } catch (_) {
      await next?.dispose();
      if (mounted) {
        setState(
          () => error =
              'Видео недоступно или кодек не поддерживается. Можно повторить.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player?.removeListener(changed);
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Column(
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (p == null)
          Expanded(
            child: Center(
              child: TextButton.icon(
                onPressed: loading ? null : open,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  widget.block.label.isEmpty
                      ? 'Скачать и открыть видео'
                      : widget.block.label,
                ),
              ),
            ),
          )
        else ...[
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: p.value.aspectRatio,
                child: VideoPlayer(p),
              ),
            ),
          ),
          VideoProgressIndicator(p, allowScrubbing: true),
          IconButton(
            tooltip: p.value.isPlaying ? 'Пауза' : 'Воспроизвести',
            onPressed: () => p.value.isPlaying ? p.pause() : p.play(),
            icon: Icon(p.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          if (p.value.hasError)
            const Text('Ошибка видеокодека. Откройте другой файл.'),
        ],
      ],
    );
  }
}
