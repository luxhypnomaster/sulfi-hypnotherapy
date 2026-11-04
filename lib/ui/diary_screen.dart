import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/session_plan.dart';
import '../services/diary_controller.dart';
import '../services/diary_api.dart';
import 'design.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.diary});
  final DiaryController diary;
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DiaryController get d => widget.diary;
  @override
  void initState() {
    super.initState();
    unawaited(d.sync());
  }

  Future<void> _editor([DiaryEntry? entry]) async {
    if (!d.authorWorkspace) return;
    final now = DateTime.now().toUtc();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditor(
          diary: d,
          entry:
              entry ??
              DiaryEntry(
                id: newId(),
                message: '',
                body: '',
                createdAt: now,
                updatedAt: now,
              ),
        ),
      ),
    );
  }

  Future<void> _authorAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is DiaryApiException
                  ? e.message
                  : 'Действие не выполнено. Попробуйте снова.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _restore() async {
    final count = await d.restoreFromCloud();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Добавлено записей: $count. Существующие черновики на телефоне сохранены.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: d,
    builder: (context, _) => LeatherScaffold(
      title: 'Дневник Сульфи',
      actions: [
        if (d.canSignIn)
          IconButton(
            tooltip: d.authorWorkspace
                ? 'Выйти из аккаунта автора'
                : 'Войти как автор через Google',
            onPressed: d.authorBusy
                ? null
                : () => _authorAction(
                    d.authorWorkspace ? d.logout : d.signInAuthor,
                  ),
            icon: Icon(d.authorWorkspace ? Icons.logout : Icons.person_outline),
          ),
        if (d.authorWorkspace && d.api != null)
          IconButton(
            tooltip: 'Загрузить недостающие черновики с Диска',
            onPressed: d.authorBusy ? null : () => _authorAction(_restore),
            icon: const Icon(Icons.cloud_download_outlined),
          ),
        IconButton(
          tooltip: 'Обновить дневник',
          onPressed: d.syncing ? null : d.sync,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          if (d.syncing) const LinearProgressIndicator(minHeight: 2),
          if (d.error != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                d.error!,
                style: const TextStyle(fontSize: 12, color: antiqueGold),
              ),
            ),
          Expanded(
            child: d.published.isEmpty
                ? const Center(
                    child: Text(
                      'Опубликованных записей пока нет.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: d.published.length,
                    itemBuilder: (context, i) {
                      final e = d.published[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          e.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: neonPink),
                        ),
                        subtitle: Text(
                          formatLocalDate(e.publishedAt!),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiaryReader(entry: e),
                          ),
                        ),
                        trailing: d.authorWorkspace
                            ? IconButton(
                                tooltip: 'Редактировать публикацию',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editor(
                                  d.drafts
                                          .where((v) => v.id == e.id)
                                          .firstOrNull ??
                                      e,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),
          if (d.authorWorkspace) ...[
            TextButton.icon(
              onPressed: () => _editor(),
              icon: const Icon(Icons.add),
              label: const Text('Автор: создать запись'),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in d.drafts)
                    ListTile(
                      dense: true,
                      title: Text(
                        e.message.isEmpty ? 'Черновик' : e.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(switch (e.status) {
                        DiaryStatus.draft => 'Черновик · только автор',
                        DiaryStatus.published => 'Опубликована',
                        DiaryStatus.unpublished => 'Снята с публикации',
                      }),
                      onTap: () => _editor(e),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

String diaryDate(DateTime date) {
  final local = date.toLocal();
  const days = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  String n(int v) => v.toString().padLeft(2, '0');
  return '${days[local.weekday - 1]}, ${n(local.day)}.${n(local.month)}.${local.year} · ${n(local.hour)}:${n(local.minute)}';
}

TextSpan diaryHeading(DiaryEntry e) => TextSpan(
  children: [
    TextSpan(
      text:
          'Запись ${e.number == null ? e.id : '№${e.number}'}\n${diaryDate(e.publishedAt ?? e.createdAt)}\n\n',
      style: const TextStyle(fontSize: 12, color: Color(0xFF5C4232)),
    ),
    TextSpan(
      text: '${e.message}\n\n',
      style: const TextStyle(
        color: Color(0xFFC00C71),
        fontWeight: FontWeight.w700,
      ),
    ),
  ],
);

/// Fits actual Flutter typography to the reader's available paper rectangle.
/// Cuts on grapheme boundaries and preserves every character of the body.
List<String> paginateDiary(
  DiaryEntry e,
  double width,
  double height,
  TextScaler scaler,
  TextStyle style,
) {
  final characters = e.body.characters.toList();
  final pages = <String>[];
  var start = 0;
  do {
    var low = start, high = characters.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final span = TextSpan(
        style: style,
        children: [
          if (pages.isEmpty) diaryHeading(e),
          TextSpan(text: characters.sublist(start, mid).join()),
        ],
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final fits = painter.height <= height;
      painter.dispose();
      if (fits) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    // For very large fonts a heading can fill a page; put body on page two.
    if (low == start && pages.isEmpty) {
      pages.add('');
      continue;
    }
    if (low == start) low = math.min(start + 1, characters.length);
    for (var cut = low; cut > math.max(start + 1, low - 60); cut--) {
      if (characters[cut - 1].trim().isEmpty) {
        low = cut;
        break;
      }
    }
    pages.add(characters.sublist(start, low).join());
    start = low;
  } while (start < characters.length);
  return pages;
}

class DiaryReader extends StatefulWidget {
  const DiaryReader({super.key, required this.entry, this.preview = false});
  final DiaryEntry entry;
  final bool preview;
  @override
  State<DiaryReader> createState() => _DiaryReaderState();
}

class _DiaryReaderState extends State<DiaryReader> {
  int page = 0;
  int? _layoutKey;
  List<String> _layoutPages = [];
  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: widget.preview ? 'Предпросмотр дневника' : 'Дневник Сульфи',
    actions: [
      IconButton(
        tooltip: 'На главную',
        icon: const Icon(Icons.home_outlined),
        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
      IconButton(
        tooltip: 'Оглавление',
        icon: const Icon(Icons.format_list_bulleted),
        onPressed: () => Navigator.pop(context),
      ),
    ],
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2CC9D), Color(0xFFF6E8C8), Color(0xFFD7BD87)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: LayoutBuilder(
          builder: (context, box) {
            const style = TextStyle(
              inherit: false,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.normal,
              letterSpacing: 0,
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF302519),
            );
            final layoutKey = Object.hash(
              widget.entry.body,
              widget.entry.message,
              widget.entry.publishedAt,
              box.maxWidth,
              box.maxHeight,
              MediaQuery.textScalerOf(context).scale(16),
            );
            if (_layoutKey != layoutKey) {
              _layoutKey = layoutKey;
              _layoutPages = paginateDiary(
                widget.entry,
                box.maxWidth,
                math.max(1, box.maxHeight - 48),
                MediaQuery.textScalerOf(context),
                style,
              );
            }
            final pages = _layoutPages;
            final current = page.clamp(0, pages.length - 1);
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: box.maxWidth,
                      child: Text.rich(
                        TextSpan(
                          style: style,
                          children: [
                            if (current == 0) diaryHeading(widget.entry),
                            TextSpan(text: pages[current]),
                          ],
                        ),
                        key: ValueKey('diary-page-$current'),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Предыдущая страница',
                        color: const Color(0xFF302519),
                        onPressed: current == 0
                            ? null
                            : () => setState(() => page = current - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${current + 1} из ${pages.length}',
                            key: const Key('diary-pagination'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF302519),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CustomPaint(painter: _SulfurMark()),
                      ),
                      IconButton(
                        tooltip: 'Следующая страница',
                        color: const Color(0xFF302519),
                        onPressed: current + 1 >= pages.length
                            ? null
                            : () => setState(() => page = current + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SulfurMark extends CustomPainter {
  const _SulfurMark();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFF76531A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    c.drawArc(
      Rect.fromLTWH(1, 1, s.width - 2, s.height - 2),
      .2,
      math.pi * 1.94,
      false,
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(s.width - 2, s.height * .35)
        ..lineTo(s.width - 7, s.height * .4)
        ..lineTo(s.width - 4, s.height * .2)
        ..close(),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(s.width * .5, 6)
        ..lineTo(s.width * .28, 18)
        ..lineTo(s.width * .72, 18)
        ..close()
        ..moveTo(s.width * .5, 18)
        ..lineTo(s.width * .5, 27)
        ..moveTo(11, 23)
        ..lineTo(21, 23),
      p,
    );
  }

  @override
  bool shouldRepaint(_SulfurMark old) => false;
}

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({super.key, required this.diary, required this.entry});
  final DiaryController diary;
  final DiaryEntry entry;
  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_save());
    }
  }

  late DiaryEntry entry = widget.entry;
  late final message = TextEditingController(text: entry.message);
  late final body = TextEditingController(text: entry.body);
  Timer? timer;
  Future<void> tail = Future.value();
  String? error;
  bool allowPop = false, busy = false;
  DiaryEntry get value => entry.copyWith(
    message: message.text,
    body: body.text,
    updatedAt: DateTime.now().toUtc(),
  );
  void _changed(String _) {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 350), () => unawaited(_save()));
  }

  Future<bool> _save() async {
    timer?.cancel();
    final snapshot = value;
    final operation = tail.then((_) => widget.diary.saveDraft(snapshot));
    tail = operation.catchError((Object _) {});
    try {
      await operation;
      if (mounted) setState(() => error = null);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось сохранить черновик. Не закрывайте экран; повторите сохранение.',
        );
      }
      return false;
    }
  }

  Future<void> _close() async {
    if (busy) return;
    if (await _save() && mounted) {
      setState(() => allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _publish(bool publish) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!await _save()) return;
      if (publish &&
          (message.text.trim().isEmpty || body.text.trim().isEmpty)) {
        throw const FormatException('Заполните послание и основной текст');
      }
      await widget.diary.publish(value, published: publish);
      entry = widget.diary.drafts.firstWhere((e) => e.id == entry.id);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DiaryApiException ? e.message : 'Публикация не выполнена; черновик сохранён. Проверьте соединение и повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _login() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.diary.signInAuthor();
      if (mounted) setState(() => error = widget.diary.error);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DiaryApiException
              ? e.message
              : 'Не удалось войти через Google.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveToCloud() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!await _save()) return;
      await widget.diary.saveToCloud(value);
      entry = widget.diary.drafts.firstWhere((e) => e.id == entry.id);
      if (mounted) {
        setState(() => error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Черновик сохранён на Диске. Публичная запись не изменена.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DiaryApiException ? e.message : 'Сохранение на Диск не выполнено. Черновик остался на телефоне.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    message.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.diary.authorWorkspace) {
      return const Scaffold(
        body: Center(child: Text('Авторский режим недоступен')),
      );
    }
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (p, _) {
        if (!p) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Сохранить и закрыть',
            onPressed: busy ? null : _close,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Автор: дневник'),
          actions: [
            if (widget.diary.canSignIn)
              IconButton(
                tooltip: 'Подтвердить вход через Google',
                onPressed: busy ? null : _login,
                icon: const Icon(Icons.key),
              ),
          ],
        ),
        body: SafeArea(
          child: LeatherBoard(
            child: Column(
              children: [
                Text(switch (entry.status) {
                  DiaryStatus.draft => 'Черновик · только на этом устройстве',
                  DiaryStatus.published =>
                    'Опубликована · изменения сохраняются отдельно',
                  DiaryStatus.unpublished => 'Снята с публикации',
                }, style: const TextStyle(fontSize: 12, color: antiqueGold)),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(fontSize: 12, color: neonPink),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      TextField(
                        enabled: !busy,
                        controller: message,
                        onChanged: _changed,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Короткое послание',
                        ),
                        style: const TextStyle(color: neonPink),
                      ),
                      TextField(
                        enabled: !busy,
                        controller: body,
                        onChanged: _changed,
                        minLines: 8,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Основной текст',
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: busy ? null : _save,
                      child: const Text('Сохранить черновик'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await _save() && context.mounted) {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DiaryReader(
                                      entry: value,
                                      preview: true,
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Предпросмотр'),
                    ),
                    if (widget.diary.api != null)
                      TextButton(
                        onPressed: busy ? null : _saveToCloud,
                        child: const Text('Сохранить на Диск'),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => _publish(true),
                      child: const Text('Опубликовать'),
                    ),
                    if (entry.status == DiaryStatus.published)
                      TextButton(
                        onPressed: busy ? null : () => _publish(false),
                        child: const Text('Снять публикацию'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
