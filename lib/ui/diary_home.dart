import 'package:flutter/material.dart';

import '../services/diary_controller.dart';
import 'diary_screen.dart';
import 'design.dart';

/// The tab is attached to the board edge; it occupies no session content row.
class DiaryHomeBoard extends StatelessWidget {
  const DiaryHomeBoard({super.key, required this.child, this.diary});
  final Widget child;
  final DiaryController? diary;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    fit: StackFit.expand,
    children: [
      LeatherBoard(child: child),
      if (diary != null)
        Positioned(
          top: -8,
          right: 32,
          child: ListenableBuilder(
            listenable: diary!,
            builder: (context, _) {
              final current = diary!.currentEntry;
              return Semantics(
                label: 'Дневник',
                button: true,
                excludeSemantics: true,
                child: TextButton(
                  key: const Key('home-diary'),
                  style: TextButton.styleFrom(
                    backgroundColor: neonLime,
                    foregroundColor: ink,
                    minimumSize: const Size(88, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => current == null
                          ? DiaryScreen(diary: diary!)
                          : DiaryReader(entry: current, diary: diary!),
                    ),
                  ),
                  child: const Text('Дневник'),
                ),
              );
            },
          ),
        ),
    ],
  );
}

class DiaryHomeMessage extends StatelessWidget {
  const DiaryHomeMessage({super.key, required this.diary});
  final DiaryController diary;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: diary,
    builder: (_, _) {
      final current = diary.currentEntry;
      return current == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                current.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: neonPink),
              ),
            );
    },
  );
}
