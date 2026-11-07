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
      if (diary != null)
        Positioned(
          top: 0,
          left: 26,
          child: Container(
            width: 112,
            height: 42,
            padding: const EdgeInsets.only(top: 2, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF101500),
              border: Border.all(color: neonLime),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: neonLime.withValues(alpha: .35),
                  blurRadius: 9,
                ),
              ],
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: neonLime, size: 17),
                  SizedBox(width: 4),
                  Text(
                    'Дневник',
                    style: TextStyle(
                      color: neonLime,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      Positioned.fill(
        top: 20,
        child: DecoratedBox(
          key: const Key('home-board-frame'),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/art/leather_board.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 17, 15),
            child: child,
          ),
        ),
      ),
      if (diary != null)
        Positioned(
          top: 0,
          left: 26,
          width: 112,
          height: 48,
          child: ListenableBuilder(
            listenable: diary!,
            builder: (context, _) {
              final current = diary!.currentEntry;
              return Semantics(
                label: 'Дневник',
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('home-diary'),
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => current == null
                          ? DiaryScreen(diary: diary!)
                          : DiaryReader(entry: current, diary: diary!),
                    ),
                  ),
                  child: const SizedBox.expand(),
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
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                current.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: neonPink),
              ),
            );
    },
  );
}
