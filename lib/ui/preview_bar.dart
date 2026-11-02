import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../services/library_service.dart';
import '../services/preview_player.dart';
import 'design.dart';

class PreviewBar extends StatelessWidget {
  const PreviewBar({
    super.key,
    required this.player,
    required this.library,
    this.idleAsset,
    this.compact = false,
  });
  final PreviewPlayer player;
  final LibraryService library;
  final AudioAsset? idleAsset;
  final bool compact;
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is LibraryException
                  ? e.message
                  : 'Не удалось воспроизвести аудио.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: player,
    builder: (context, _) {
      final a = player.current ?? idleAsset;
      if (a == null) {
        return player.error == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  player.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
      }
      final loaded = player.current != null;
      final position = loaded
          ? player.position.inMilliseconds.clamp(0, a.durationMs)
          : 0;
      if (compact) {
        return NeonPanel(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(a.title),
                          content: Text(
                            '${a.description.isEmpty ? 'Описание не добавлено.' : a.description}\n\nДлительность: ${formatDuration(a.durationMs)}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Закрыть'),
                            ),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            player.error ??
                                (a.description.isEmpty
                                    ? 'Предпрослушивание трека'
                                    : a.description),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: player.error == null
                                  ? const Color(0xFFC8ADBD)
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Остановить прослушивание',
                    onPressed: loaded
                        ? () => _action(context, player.stop)
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined, size: 22),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: player.playing
                        ? 'Пауза'
                        : loaded
                        ? 'Продолжить'
                        : 'Прослушать трек',
                    onPressed: () => _action(
                      context,
                      () => player.toggle(a, library.fileFor(a)),
                    ),
                    icon: Icon(
                      player.playing ? Icons.pause_circle : Icons.play_circle,
                      color: neonPink,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      semanticFormatterCallback: (v) =>
                          formatDuration(v.round()),
                      value: position.toDouble(),
                      max: a.durationMs.toDouble(),
                      onChanged: loaded
                          ? (value) => _action(
                              context,
                              () => player.seek(
                                Duration(milliseconds: value.round()),
                              ),
                            )
                          : null,
                    ),
                  ),
                  Text(
                    '${formatDuration(position)} / ${formatDuration(a.durationMs)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(10),
        child: NeonPanel(
          padding: const EdgeInsets.all(10),
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (player.error != null)
                Text(
                  player.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Row(
                children: [
                  const Icon(Icons.graphic_eq, color: neonPink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Остановить прослушивание',
                    onPressed: loaded
                        ? () => _action(context, player.stop)
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                ],
              ),
              if (a.description.isNotEmpty)
                Text(
                  a.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: player.playing
                        ? 'Пауза'
                        : loaded
                        ? 'Продолжить'
                        : 'Прослушать трек',
                    onPressed: () => _action(
                      context,
                      () => player.toggle(a, library.fileFor(a)),
                    ),
                    icon: Icon(
                      player.playing ? Icons.pause_circle : Icons.play_circle,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      semanticFormatterCallback: (v) =>
                          formatDuration(v.round()),
                      value: position.toDouble(),
                      max: a.durationMs.toDouble(),
                      onChanged: !loaded
                          ? null
                          : (value) => _action(
                              context,
                              () => player.seek(
                                Duration(milliseconds: value.round()),
                              ),
                            ),
                    ),
                  ),
                  Text(
                    '${formatDuration(position)} / ${formatDuration(a.durationMs)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
