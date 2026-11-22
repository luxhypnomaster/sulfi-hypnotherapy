import 'package:flutter/material.dart';

import '../models/session_plan.dart';
import '../services/feedback22_store.dart';
import '../services/playback22_evidence.dart';

class Feedback22Screen extends StatefulWidget {
  const Feedback22Screen({
    super.key,
    required this.store,
    required this.run,
    this.exactTarget,
    this.recordKey,
    this.execution,
    this.title,
    this.occurrences,
  });
  final Feedback22Store store;
  final SessionRun run;
  final Map<String, dynamic>? exactTarget, execution;
  final String? recordKey, title;
  final List<Map<String, dynamic>>? occurrences;
  @override
  State<Feedback22Screen> createState() => _Feedback22ScreenState();
}

class _Feedback22ScreenState extends State<Feedback22Screen> {
  String get recordKey => widget.recordKey ?? widget.run.id;
  List<Map<String, dynamic>> occurrences = [];
  Map<String, dynamic>? target;
  final components = <String, int>{};
  int? rating;
  bool busy = false, consent = false, shared = false, shareReady = false;
  String status = 'Необязательно. Можно сохранить только на этом телефоне.';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final v = await widget.store.load(recordKey);
    final captured = widget.exactTarget == null
        ? await playbackFeedback22(
            widget.store.db,
            widget.run,
            owner: widget.store.owner(),
          )
        : null;
    target = widget.exactTarget ?? captured?['target'];
    occurrences =
        widget.occurrences ??
        List<Map<String, dynamic>>.from(captured?['occurrences'] ?? []);
    for (final c in v?['feedback']?['componentRatings'] as List? ?? []) {
      components[c['target']['contentId']] = c['rating'];
    }
    if (mounted) {
      setState(() {
        rating = v?['feedback']?['rating'];
        shared = v?['receipt']?['shared'] == true;
        shareReady =
            target != null && target!['ratingEpochId'] != 'local-unresolved' ||
            v?['shareReady'] == true;
      });
    }
  }

  Future<void> act({bool? share}) async {
    if (rating == null) return;
    setState(() => busy = true);
    try {
      await widget.store.save(
        widget.run,
        rating!,
        exactTarget: target,
        recordKey: recordKey,
        execution: widget.execution,
        occurrences: occurrences,
        componentRatings: [
          for (final t
              in occurrences
                  .map((o) => o['target'] as Map)
                  .where((t) => components.containsKey(t['contentId'])))
            {
              'target': Map<String, dynamic>.from(t),
              'rating': components[t['contentId']],
            },
        ],
      );
      if (share != null) {
        await widget.store.consent(recordKey, share);
      }
      if (mounted) {
        setState(
          () => status = share == null
              ? 'Сохранено только на этом телефоне'
              : share
              ? 'Отправка поставлена в очередь; сервер ещё не подтвердил'
              : 'Отзыв согласия поставлен в очередь; ожидается подтверждение',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Не удалось завершить действие. Локальный отзыв сохранён; проверьте подключение.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Личный отзыв')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.title ??
              widget.run.snapshot.baseTemplateName ??
              widget.run.name,
        ),
        const Text(
          'Как вы оцениваете свой опыт? Это субъективный отзыв, а не медицинская оценка.',
        ),
        Wrap(
          children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                key: Key('rating22-$n'),
                tooltip: '$n из 5',
                onPressed: busy ? null : () => setState(() => rating = n),
                icon: Icon(
                  rating != null && n <= rating!
                      ? Icons.star
                      : Icons.star_border,
                ),
              ),
          ],
        ),
        for (final t in {
          for (final o in occurrences)
            if (['PARTIAL', 'COMPLETED'].contains(o['status']))
              o['target']['contentId']: o['target'],
        }.values)
          DropdownButtonFormField<int>(
            initialValue: components[t['contentId']],
            decoration: InputDecoration(
              labelText:
                  'Отдельно ${t['type']}: ${t['contentId']} (необязательно)',
            ),
            items: [
              for (var n = 1; n <= 5; n++)
                DropdownMenuItem(value: n, child: Text('$n из 5')),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() => components[t['contentId']] = v!),
          ),
        Text(status, key: const Key('feedback22-status')),
        FilledButton(
          onPressed: busy || rating == null ? null : () => act(),
          child: const Text('Оставить у себя'),
        ),
        CheckboxListTile(
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v!),
          title: const Text('Разрешаю передать оценку для общей статистики'),
          subtitle: const Text(
            'Личные заметки, текст и записи голоса не передаются.',
          ),
        ),
        OutlinedButton(
          onPressed:
              busy ||
                  rating == null ||
                  !consent ||
                  !shareReady ||
                  widget.store.runtime == null
              ? null
              : () => act(share: true),
          child: const Text('Передать добровольно'),
        ),
        if (!shareReady)
          const Text(
            'Передача доступна только для подтверждённой редакции каталога. Локальная оценка доступна всегда.',
          ),
        if (shared)
          TextButton(
            onPressed: busy ? null : () => act(share: false),
            child: const Text('Отозвать согласие'),
          ),
        TextButton(
          key: const Key('feedback22-skip'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Пропустить'),
        ),
      ],
    ),
  );
}
