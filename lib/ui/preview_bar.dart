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
  });
  final PreviewPlayer player;
  final LibraryService library;
  final AudioAsset? idleAsset;
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
