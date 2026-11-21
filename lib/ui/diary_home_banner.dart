import 'dart:async';

import 'package:flutter/material.dart';

import '../models/content_revision.dart';
import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import '../services/diary_carousel.dart';
import '../services/diary_controller.dart';
import 'design.dart';
import 'diary_reader.dart';

/// Occupies exactly the old HOME portrait slot; no external padding/height.
class DiaryHomeBanner extends StatefulWidget {
  const DiaryHomeBanner({super.key, required this.diary, required this.splash});
  final DiaryController diary;
  final Widget splash;
  @override
  State<DiaryHomeBanner> createState() => _DiaryHomeBannerState();
}

class _DiaryHomeBannerState extends State<DiaryHomeBanner>
    with WidgetsBindingObserver {
  late final DiaryCarousel rotation;
  Timer? timer;
  String? signature;
  String? accountScope;
  int generation = 0;
  bool resumed = true;
  @override
  void initState() {
    super.initState();
    rotation = DiaryCarousel(config: widget.diary.homeConfig);
    WidgetsBinding.instance.addObserver(this);
    widget.diary.addListener(changed);
    changed();
  }

  @override
  void didUpdateWidget(DiaryHomeBanner old) {
    super.didUpdateWidget(old);
    if (old.diary != widget.diary) {
      old.diary.removeListener(changed);
      widget.diary.addListener(changed);
      signature = null;
      changed();
    }
  }

  void schedule() {
    timer?.cancel();
    if (!resumed || !rotation.hasEntries) return;
    timer = Timer(rotation.duration, () {
      if (!mounted) return;
      setState(rotation.advance);
      schedule();
    });
  }

  void apply(List<DiaryEntry> ready) {
    final old = rotation.current?.id;
    rotation.update(
      ready,
      widget.diary.clock(),
      widget.diary.reads.isRead,
      nextConfig: widget.diary.homeConfig,
    );
    if (mounted) setState(() {});
    if (old != rotation.current?.id || timer == null || !timer!.isActive) {
      schedule();
    }
  }

  void changed() {
    final d = widget.diary;
    final scope =
        d.api?.readerScope ?? (d.reads.loaded ? d.reads.readerId : null);
    if (accountScope != scope) {
      accountScope = scope;
      rotation.update([], d.clock(), (_) => false);
    }
    final next = contentDigest([
      scope,
      d.homeConfig.toMap(),
      for (final e in d.published)
        [
          e.toMap(),
          d.reads.isRead(e),
          DiaryPublication.of(e).active(e, d.clock()),
        ],
    ]);
    if (signature == next) return;
    signature = next;
    final epoch = ++generation;
    // Revoke/read invalidation is immediate, even while new media are pending.
    final visible = d.published
        .where(
          (e) =>
              e.extra['_alchemistScope'] == null ||
              e.extra['_alchemistScope'] == 'public' ||
              e.extra['_alchemistScope'] == scope,
        )
        .toList();
    final ready = visible
        .where((e) => e.blocks.every((b) => b.media == null))
        .toList();
    final old = rotation.current;
    if (old != null && !ready.any((e) => e.id == old.id)) {
      final latest = visible
          .where(
            (e) =>
                e.id == old.id &&
                contentDigest(e.blocks.map((b) => b.media?.toMap()).toList()) ==
                    contentDigest(
                      old.blocks.map((b) => b.media?.toMap()).toList(),
                    ),
          )
          .firstOrNull;
      if (latest != null) ready.add(latest);
    }
    apply(ready);
    unawaited(() async {
      for (final e in visible) {
        if (e.blocks.every((b) => b.media == null)) continue;
        var verified = true;
        for (final b in e.blocks.where((b) => b.media != null)) {
          try {
            if (b.media!.hash == null ||
                await d.mediaStore?.resolve(b.media) == null) {
              verified = false;
              break;
            }
          } catch (_) {
            verified = false;
            break;
          }
          if (!mounted || epoch != generation) return;
        }
        if (verified) ready.add(e);
      }
      if (mounted && epoch == generation) apply(ready);
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    schedule();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    widget.diary.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = rotation.current;
    if (e == null) return widget.splash;
    final images = e.blocks
            .where((b) => b.type == DiaryBlockType.image && b.media != null)
            .toList(),
        audio = e.blocks
            .where((b) => b.type == DiaryBlockType.audio && b.media != null)
            .toList(),
        texts = e.blocks
            .where((b) => b.type == DiaryBlockType.text && b.substantive)
            .length;
    void open() => Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryReader(entry: e, diary: widget.diary),
      ),
    );
    return ColoredBox(
      key: const Key('diary-home-slide'),
      color: const Color(0xFF200514),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: open,
                    child: Text(
                      e.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: neonLime),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: open,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (texts > 0)
                        Text(
                          '+$texts текст',
                          style: const TextStyle(fontSize: 10),
                        ),
                      const Spacer(),
                      if (audio.isNotEmpty)
                        SizedBox(
                          width: 48,
                          height: 36,
                          child: IconButton(
                            key: const Key('diary-home-play'),
                            tooltip: 'Слушать публикацию',
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                widget.diary.audioFor(e)?.toggle(audio.first),
                            icon: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset('assets/brand/spiral.png'),
                                const Icon(
                                  Icons.play_arrow,
                                  color: neonLime,
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (audio.length > 1)
                        Text(
                          '+${audio.length - 1}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (images.isNotEmpty)
              AspectRatio(
                aspectRatio: .75,
                child: GestureDetector(
                  onTap: open,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.diary.mediaStore?.file(images.first.media)
                          case final file?)
                        Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      if (images.length > 1)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Text(
                            '+${images.length - 1}',
                            style: const TextStyle(
                              backgroundColor: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
