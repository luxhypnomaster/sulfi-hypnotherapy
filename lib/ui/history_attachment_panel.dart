import 'dart:io';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/audio_asset.dart';
import '../services/history_attachments.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import '../services/device_files.dart';
import 'recorder_screen.dart';
import 'design.dart';
import 'session_actions.dart';

class HistoryAttachmentPanel extends StatefulWidget {
  const HistoryAttachmentPanel({
    super.key,
    required this.controller,
    required this.runId,
    required this.player,
  });
  final SessionController controller;
  final String runId;
  final PreviewPlayer player;
  @override
  State<HistoryAttachmentPanel> createState() => _HistoryAttachmentPanelState();
}

class _HistoryAttachmentPanelState extends State<HistoryAttachmentPanel> {
  HistoryAttachments get service => widget.controller.historyAttachments!;
  List<HistoryAttachment> items = [];
  bool busy = false;
  String? loadError;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = await service.list(widget.runId);
      if (mounted) {
        setState(() {
          items = next;
          loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError =
              'Не удалось прочитать вложения. Исходные файлы сохранены.',
        );
      }
    }
  }

  Future<void> action(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    await showActionError(context, f);
    if (mounted) {
      await load();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> image({bool camera = false}) async {
    final block = camera
        ? await (() async {
            final path = await DeviceFiles.channel.invokeMethod<String>(
              'capturePhoto',
            );
            if (path == null) return null;
            return service.media.importFile(DiaryBlockType.image, (
              name: 'photo.jpg',
              path: path,
            ));
          })()
        : await service.media.import(DiaryBlockType.image);
    if (block != null) await service.attach(widget.runId, block);
  }

  Future<void> record() async {
    await Navigator.push<DiaryBlock>(
      context,
      MaterialPageRoute(
        builder: (_) => RecorderScreen(
          controller: widget.controller,
          player: widget.player,
          diaryRecording: true,
          attachmentTitle: 'Голосовая заметка',
          attachmentStore: service.media,
          attachDiaryBlock: (b) async {
            await service.attach(widget.runId, b);
            return b;
          },
        ),
      ),
    );
  }

  Future<void> play(HistoryAttachment a) async {
    final b = a.block;
    await widget.player.toggle(
      AudioAsset(
        id: a.id,
        source: 'history_attachment',
        origin: 'personal',
        title: b.label.isEmpty ? 'Голосовая заметка' : b.label,
        filePath: 'attachment.m4a',
        durationMs: b.durationMs!,
        format: 'm4a',
        createdAt: a.createdAt,
        category: AudioCategory.freeform,
        fileSizeBytes: b.media!.bytes,
      ),
      service.media.file(b.media)!,
    );
  }

  @override
  Widget build(BuildContext context) => NeonPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loadError != null)
          TextButton(onPressed: load, child: Text(loadError!)),
        const Text(
          'Заметки и вложения',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: busy ? null : () => action(record),
              icon: const Icon(Icons.mic_none),
              label: const Text('Голос'),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => action(() => image(camera: true)),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Фото'),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => action(image),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Изображение'),
            ),
          ],
        ),
        for (final a in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              a.block.label.isEmpty ? 'Вложение' : a.block.label,
              maxLines: 2,
            ),
            subtitle: Text(
              '${formatLocal(a.createdAt)}${a.block.durationMs == null ? '' : ' · ${formatDuration(a.block.durationMs!)}'}',
            ),
            leading: a.block.type == DiaryBlockType.image
                ? InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.file(File(a.block.media!.localPath!)),
                        ),
                      ),
                    ),
                    child: Image.file(
                      File(a.block.media!.localPath!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  )
                : ListenableBuilder(
                    listenable: widget.player,
                    builder: (_, _) => IconButton(
                      onPressed: () => action(() => play(a)),
                      icon: Icon(
                        widget.player.current?.id == a.id &&
                                widget.player.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                    ),
                  ),
            trailing: IconButton(
              tooltip: 'Удалить вложение',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy
                  ? null
                  : () => action(() async {
                      if (await confirmAction(
                        context,
                        'Удалить вложение?',
                        'Остальные заметки и запись истории сохранятся.',
                        confirm: 'Удалить',
                      )) {
                        if (widget.player.current?.id == a.id) {
                          await widget.player.stop();
                        }
                        await service.remove(widget.runId, a.id);
                      }
                    }),
            ),
          ),
      ],
    ),
  );
  String formatLocal(DateTime d) =>
      '${d.toLocal().day}.${d.toLocal().month}.${d.toLocal().year} · ${d.toLocal().hour}:${d.toLocal().minute.toString().padLeft(2, '0')}';
}
