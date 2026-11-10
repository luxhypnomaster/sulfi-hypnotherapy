import 'dart:io';

import 'diary_video.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import 'diary_content_link.dart';
import '../services/diary_audio.dart';
import '../services/preview_diary_transport.dart';
import '../services/diary_controller.dart';
import '../services/diary_layout.dart';
import 'design.dart';
import 'diary_screen.dart';

class DiaryReader extends StatefulWidget {
  const DiaryReader({
    super.key,
    required this.entry,
    this.preview = false,
    this.diary,
    this.fromJournal = false,
    this.onLayout,
    this.calculateOnly = false,
  });
  final DiaryEntry entry;
  final bool preview, fromJournal, calculateOnly;
  final void Function(DiaryLayout, double, double)? onLayout;
  final DiaryController? diary;
  @override
  State<DiaryReader> createState() => _DiaryReaderState();
}

class _DiaryReaderState extends State<DiaryReader> with WidgetsBindingObserver {
  int page = 0, generation = 0;
  Object? layoutKey;
  DiaryLayout? layout;
  DiaryAudio? audio;
  bool calculating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.diary?.addListener(diaryChanged);
    if (!widget.calculateOnly) {
      audio = widget.diary?.audioFor(widget.entry, preview: widget.preview);
    }
  }

  void diaryChanged() {
    if (!mounted || widget.preview) return;
    unawaited(audio?.navigationPause());
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(audio?.pause());
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.diary?.removeListener(diaryChanged);
    if (widget.preview || !(widget.diary?.ownsAudio(audio) ?? false)) {
      unawaited(audio?.close());
    }
    super.dispose();
  }

  void calculate(double w, double h, TextScaler scaler) {
    final key = Object.hash(entry, w, h, scaler.scale(16));
    if (key == layoutKey) return;
    final anchor = layout
        ?.pages[page.clamp(0, layout!.pages.length - 1)]
        .fragments
        .firstOrNull;
    DiaryAnchor? readingAnchor = anchor == null
        ? null
        : DiaryAnchor(anchor.block.id, anchor.offset);
    if (readingAnchor != null &&
        !entry.blocks.any((b) => b.id == readingAnchor!.blockId)) {
      final oldIds = layout!.pages
          .expand((p) => p.fragments)
          .map((f) => f.block.id)
          .toSet()
          .toList();
      final oldIndex = oldIds.indexOf(readingAnchor.blockId);
      for (var distance = 1; distance <= oldIds.length; distance++) {
        final candidates = [
          oldIndex + distance,
          oldIndex - distance,
        ].where((i) => i >= 0 && i < oldIds.length);
        final nearby = candidates
            .map((i) => oldIds[i])
            .where((id) => entry.blocks.any((b) => b.id == id))
            .firstOrNull;
        if (nearby != null) {
          readingAnchor = DiaryAnchor(nearby, 0);
          break;
        }
      }
    }
    layoutKey = key;
    calculating = true;
    final task = ++generation;
    unawaited(
      layoutDiary(entry, w, h, scaler).then((value) {
        if (!mounted || task != generation) return;
        widget.onLayout?.call(value, w, h);
        setState(() {
          layout = value;
          calculating = false;
          page = value.pageFor(readingAnchor);
          if (readingAnchor == null &&
              !widget.preview &&
              !widget.calculateOnly) {
            final store = widget.diary?.reads;
            final saved = store?.state(entry);
            if (saved?['fingerprint'] == store?.fingerprint(entry)) {
              page = (saved?['page'] as int? ?? 0).clamp(
                0,
                value.pages.length - 1,
              );
            }
          }
        });
      }),
    );
  }

  Future<void> turn(int next) async {
    await audio?.navigationPause();
    if (mounted) {
      setState(() => page = next.clamp(0, layout!.pages.length - 1));
      if (!widget.preview && !widget.calculateOnly) {
        await widget.diary?.textProgress(entry, page);
      }
    }
  }

  Future<void> home() async {
    await audio?.navigationPause();
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> journal() async {
    await audio?.navigationPause();
    if (!mounted) return;
    if (widget.preview || widget.fromJournal || widget.diary == null) {
      Navigator.maybePop(context);
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => DiaryScreen(diary: widget.diary!)),
      );
    }
  }

  DiaryEntry get entry => widget.preview
      ? widget.entry
      : widget.diary?.published
                .where((e) => e.id == widget.entry.id)
                .firstOrNull ??
            widget.entry;
  @override
  Widget build(BuildContext context) => DiaryReadingFrame(
    preview: widget.preview,
    onHome: home,
    onJournal: journal,
    child: Column(
      children: [
        for (final link in entry.contentLinks) DiaryContentLink(link: link),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              calculate(
                box.maxWidth,
                box.maxHeight,
                MediaQuery.textScalerOf(context),
              );
              if (!widget.preview &&
                  widget.diary != null &&
                  widget.diary!.hasCache &&
                  !widget.diary!.published.any(
                    (e) => e.id == widget.entry.id,
                  )) {
                return const Center(
                  child: Text(
                    'Запись больше не опубликована. Вернитесь к списку записей.',
                  ),
                );
              }
              final value = layout;
              if (widget.calculateOnly) return const SizedBox();
              if (value == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final index = page.clamp(0, value.pages.length - 1);
              return GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() > 150) unawaited(turn(index + (v < 0 ? 1 : -1)));
                },
                child: Column(
                  children: [
                    if (calculating)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey('diary-page-$index'),
                        child: SizedBox(
                          width: box.maxWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (index == 0)
                                DiaryHeader(entry: entry, size: value.header),
                              for (final f in value.pages[index].fragments) ...[
                                if (f.text != null)
                                  SizedBox(
                                    height: f.height,
                                    child: Text(
                                      f.text!,
                                      style: diaryTextStyle,
                                      textScaler: MediaQuery.textScalerOf(
                                        context,
                                      ),
                                      locale: const Locale('ru'),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: f.height,
                                    child: f.block.type == DiaryBlockType.image
                                        ? DiaryImage(
                                            block: f.block,
                                            diary: widget.diary,
                                          )
                                        : f.block.type == DiaryBlockType.video
                                        ? DiaryVideo(
                                            block: f.block,
                                            diary: widget.diary,
                                          )
                                        : DiaryAudioCard(
                                            block: f.block,
                                            audio: audio,
                                          ),
                                  ),
                                // Text fragments include their original whitespace; gaps only between blocks.
                                if (f.text == null ||
                                    f.end == f.block.text.length)
                                  const SizedBox(height: 12),
                              ],
                              if (index == value.pages.length - 1 &&
                                  !widget.preview &&
                                  !widget.calculateOnly &&
                                  widget.diary != null &&
                                  entry.blocks.any(
                                    (b) =>
                                        b.substantive &&
                                        b.type != DiaryBlockType.audio,
                                  ))
                                TextButton.icon(
                                  key: const Key('diary-text-end'),
                                  onPressed: () => widget.diary!.textProgress(
                                    entry,
                                    index,
                                    end: true,
                                  ),
                                  icon: const Icon(Icons.done),
                                  label: const Text('Дочитано'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (layout != null)
          DiaryNavigation(
            page: page,
            count: layout!.pages.length,
            onPage: turn,
          ),
      ],
    ),
  );
}

class DiaryReadingFrame extends StatelessWidget {
  const DiaryReadingFrame({
    super.key,
    required this.child,
    required this.preview,
    required this.onHome,
    required this.onJournal,
  });
  final Widget child;
  final bool preview;
  final VoidCallback onHome, onJournal;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Row(
                children: [
                  if (!preview)
                    Expanded(
                      child: TextButton(
                        onPressed: onHome,
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                          ),
                        ),
                        child: const Text(
                          'Вернуться на главную',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextButton(
                      onPressed: onJournal,
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                        ),
                      ),
                      child: Text(
                        preview ? 'Вернуться в редактор' : 'К списку записей',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(child: LeatherBoard(child: child)),
            ],
          ),
        ),
      ),
    ),
  );
}

class DiaryHeader extends StatelessWidget {
  const DiaryHeader({super.key, required this.entry, required this.size});
  final DiaryEntry entry;
  final DiaryHeaderSize size;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: size.meta,
        child: Text(
          diaryMeta(entry),
          style: diaryMetaStyle,
          locale: const Locale('ru'),
        ),
      ),
      const SizedBox(height: 10),
      NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        glow: true,
        child: SizedBox(
          height: size.title,
          child: Text(
            entry.displayTitle,
            style: diaryTitleStyle,
            locale: const Locale('ru'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      NeonPanel(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: size.message,
          child: Text(
            entry.message,
            style: diaryMessageStyle,
            locale: const Locale('ru'),
          ),
        ),
      ),
      const SizedBox(
        height: 20,
        child: Center(child: Divider(color: neonPink)),
      ),
    ],
  );
}

class DiaryNavigation extends StatelessWidget {
  const DiaryNavigation({
    super.key,
    required this.page,
    required this.count,
    required this.onPage,
  });
  final int page, count;
  final void Function(int) onPage;
  Widget button(BuildContext context, bool previous) {
    final enabled = previous ? page > 0 : page < count - 1;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC1DFA7),
        disabledForegroundColor: Colors.grey,
        side: BorderSide(
          color: enabled ? const Color(0xFF9CBF88) : Colors.grey,
        ),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: enabled ? () => onPage(page + (previous ? -1 : 1)) : null,
      child: Semantics(
        label: previous ? 'Предыдущая страница' : 'Следующая страница',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(previous ? Icons.chevron_left : Icons.chevron_right, size: 18),
            if (MediaQuery.textScalerOf(context).scale(16) < 24 &&
                MediaQuery.sizeOf(context).width >= 360)
              Text(
                previous ? 'Предыдущая' : 'Следующая',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Tooltip(message: 'Предыдущая страница', child: button(context, true)),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${page + 1} из $count',
              key: const Key('diary-pagination'),
              style: const TextStyle(fontSize: 12),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (
                  var i = math.max(0, math.min(page - 2, count - 5));
                  i < math.min(count, math.max(5, page + 3));
                  i++
                )
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: i == page ? neonPink : Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      Tooltip(message: 'Следующая страница', child: button(context, false)),
    ],
  );
}

class DiaryImage extends StatefulWidget {
  const DiaryImage({super.key, required this.block, this.diary});
  final DiaryBlock block;
  final DiaryController? diary;
  @override
  State<DiaryImage> createState() => _DiaryImageState();
}

class _DiaryImageState extends State<DiaryImage> {
  int retry = 0;
  File? loaded;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(covariant DiaryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.media?.hash != widget.block.media?.hash ||
        oldWidget.block.media?.assetId != widget.block.media?.assetId) {
      loaded = null;
      unawaited(load());
    }
  }

  Future<void> load() async {
    try {
      final file = await widget.diary?.mediaStore?.resolve(widget.block.media);
      if (mounted) setState(() => loaded = file);
    } catch (_) {
      if (mounted) setState(() => loaded = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block,
        file = loaded ?? widget.diary?.mediaStore?.file(widget.block.media);
    Widget unavailable() => Center(
      child: TextButton.icon(
        onPressed: () {
          setState(() => retry++);
          unawaited(load());
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Изображение недоступно · повторить'),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: block.altText.isEmpty ? 'Изображение' : block.altText,
            button: true,
            child: file == null
                ? unavailable()
                : InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: SafeArea(
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: IconButton(
                                  tooltip: 'Закрыть изображение',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              Expanded(
                                child: InteractiveViewer(
                                  minScale: .5,
                                  maxScale: 5,
                                  child: Image.file(
                                    file,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => unavailable(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: Image.file(
                      file,
                      key: ValueKey('${block.media?.assetId}-$retry'),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => unavailable(),
                    ),
                  ),
          ),
        ),
        if (block.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(block.caption, style: diaryMetaStyle),
          ),
      ],
    );
  }
}

String diaryTime(Duration? d) {
  if (d == null) return '—:—';
  final seconds = d.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class DiaryAudioCard extends StatelessWidget {
  const DiaryAudioCard({super.key, required this.block, this.audio});
  final DiaryBlock block;
  final DiaryAudio? audio;
  @override
  Widget build(BuildContext context) {
    Widget content() {
      final a = audio,
          selected = a?.transport is PreviewDiaryTransport
              ? (a!.transport as PreviewDiaryTransport).player.current?.id ==
                    'diary:${block.media?.assetId}'
              : a?.current == block.id;
      final duration = selected
          ? (a?.duration ??
                (block.durationMs == null
                    ? null
                    : Duration(milliseconds: block.durationMs!)))
          : (block.durationMs == null
                ? null
                : Duration(milliseconds: block.durationMs!));
      final position = selected && a?.transport is PreviewDiaryTransport
          ? (a!.transport as PreviewDiaryTransport).player.position
          : a?.positionFor(block.id) ?? Duration.zero;
      final playing = selected && (a?.playing ?? false);
      return NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: playing ? 'Пауза аудио' : 'Воспроизвести аудио',
                    onPressed: a == null ? null : () => a.toggle(block),
                    icon: playing
                        ? const Icon(Icons.pause, color: neonPink)
                        : Image.asset(
                            'assets/brand/spiral.png',
                            width: 28,
                            height: 28,
                          ),
                  ),
                  Expanded(
                    child: Text(
                      block.label.isEmpty ? 'Аудио' : block.label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (selected && (a?.loading ?? false))
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              // Slider owns the horizontal gesture arena; the reader cannot steal seeks.
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                ),
                child: Slider(
                  semanticFormatterCallback: (v) =>
                      diaryTime(Duration(milliseconds: v.toInt())),
                  activeColor: neonLime,
                  inactiveColor: Colors.white24,
                  min: 0,
                  max: math.max(1.0, duration?.inMilliseconds.toDouble() ?? 1),
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    math.max(1.0, duration?.inMilliseconds.toDouble() ?? 1),
                  ),
                  onChanged: selected && duration != null
                      ? (v) => a?.seek(Duration(milliseconds: v.toInt()))
                      : null,
                ),
              ),
              Text(
                '${diaryTime(position)} / ${diaryTime(duration)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: neonLime),
              ),
              if (a?.error != null)
                TextButton(
                  onPressed: () => a?.toggle(block),
                  child: Text(a?.error ?? ''),
                ),
              if (selected && (a?.transport.completed ?? false))
                const Text(
                  'Конец · нажмите спираль для повтора',
                  style: TextStyle(fontSize: 11),
                ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (_) {},
      child: audio == null
          ? content()
          : ListenableBuilder(listenable: audio!, builder: (_, _) => content()),
    );
  }
}
