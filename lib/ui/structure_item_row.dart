import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import 'design.dart';
import '../services/preview_player.dart';

class StructureItemRow extends StatelessWidget {
  const StructureItemRow({
    super.key,
    required this.step,
    required this.handle,
    required this.menu,
    required this.onPause,
    required this.onPreview,
    required this.onDuration,
    this.compact = false,
    this.player,
    this.unavailable = false,
  });
  final SessionStep step;
  final Widget handle, menu;
  final VoidCallback? onPause, onPreview, onDuration;
  final bool compact;
  final bool unavailable;
  final PreviewPlayer? player;
  @override
  Widget build(BuildContext context) => player == null
      ? _row(context)
      : ListenableBuilder(
          listenable: player!,
          builder: (context, _) => _row(context),
        );
  Widget _row(BuildContext context) {
    final audio = step.kind == StepKind.audio;
    final playing =
        player?.current?.id == step.audioAssetId && (player?.playing ?? false);
    return Container(
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: compact
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFCCABBA).withValues(alpha: .32),
                  width: .6,
                ),
              ),
            )
          : BoxDecoration(
              color: const Color(0xAA230719),
              border: Border.all(color: neonPink.withValues(alpha: .45)),
              borderRadius: BorderRadius.circular(8),
            ),
      child: Row(
        children: [
          handle,
          IconButton(
            tooltip: audio
                ? (playing ? 'Пауза прослушивания' : 'Прослушать трек')
                : 'Изменить длительность паузы',
            onPressed: audio ? onPreview : onDuration,
            constraints: compact
                ? const BoxConstraints(minWidth: 32, minHeight: 36)
                : null,
            padding: compact ? EdgeInsets.zero : null,
            visualDensity: compact ? VisualDensity.compact : null,
            icon: Icon(
              audio
                  ? (playing
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline)
                  : step.kind == StepKind.voiceRecording
                  ? Icons.mic_none
                  : Icons.pause_circle_outline,
              color: audio ? neonPink : antiqueGold,
              size: compact ? 22 : 24,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
              child: Text(
                '${unavailable ? '⚠ Недоступен · ' : ''}${step.enabled ? '' : '○ '}${audio || compact ? step.title : step.kind.label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  color: step.enabled ? null : Colors.grey,
                ),
              ),
            ),
          ),
          if (audio || step.delayBeforeSeconds > 0)
            TextButton(
              key: Key('pause-${step.id}'),
              onPressed: onPause,
              style: TextButton.styleFrom(
                minimumSize: Size(compact ? 34 : 40, compact ? 36 : 48),
                tapTargetSize: compact
                    ? MaterialTapTargetSize.shrinkWrap
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                foregroundColor: neonLime,
              ),
              child: Tooltip(
                message: audio ? 'Пауза перед треком' : 'Пауза перед элементом',
                child: Text(
                  formatPause(step.delayBeforeSeconds),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          Semantics(
            label: step.durationMs == null ? 'Длительность неизвестна' : null,
            child: TextButton(
              onPressed: audio ? null : onDuration,
              style: TextButton.styleFrom(
                minimumSize: Size(compact ? 36 : 40, compact ? 36 : 48),
                tapTargetSize: compact
                    ? MaterialTapTargetSize.shrinkWrap
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                disabledForegroundColor: const Color(0xFFF6E9F1),
              ),
              child: Text(
                step.durationMs == null
                    ? '—:—'
                    : formatDuration(step.durationMs!),
                key: ValueKey('duration-${step.id}'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          menu,
        ],
      ),
    );
  }
}
