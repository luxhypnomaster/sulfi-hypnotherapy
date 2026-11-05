import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import 'design.dart';

class StructureItemRow extends StatelessWidget {
  const StructureItemRow({
    super.key,
    required this.step,
    required this.handle,
    required this.menu,
    required this.onPause,
    required this.onPreview,
    required this.onDuration,
  });
  final SessionStep step;
  final Widget handle, menu;
  final VoidCallback? onPause, onPreview, onDuration;
  @override
  Widget build(BuildContext context) {
    final audio = step.kind == StepKind.audio;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xAA230719),
        border: Border.all(color: neonPink.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          handle,
          IconButton(
            tooltip: audio ? 'Прослушать трек' : 'Изменить длительность паузы',
            onPressed: audio ? onPreview : onDuration,
            icon: Icon(
              audio
                  ? Icons.play_circle_outline
                  : step.kind == StepKind.voiceRecording
                  ? Icons.mic_none
                  : Icons.pause_circle_outline,
              color: audio ? neonPink : antiqueGold,
              size: 24,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                '${step.enabled ? '' : '○ '}${audio ? step.title : step.kind.label}',
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
                minimumSize: const Size(40, 48),
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
                minimumSize: const Size(40, 48),
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
