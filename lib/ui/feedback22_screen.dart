import 'package:flutter/material.dart';

import '../models/session_plan.dart';
import '../services/feedback22_store.dart';

class Feedback22Screen extends StatefulWidget {
  const Feedback22Screen({
    super.key,
    required this.store,
    required this.run,
    this.exactTarget,
  });
  final Feedback22Store store;
  final SessionRun run;
  final Map<String, dynamic>? exactTarget;
  @override
  State<Feedback22Screen> createState() => _Feedback22ScreenState();
}

class _Feedback22ScreenState extends State<Feedback22Screen> {
  int? rating;
  bool busy = false, consent = false, shared = false, shareReady = false;
  String status = 'Необязательно. Можно сохранить только на этом телефоне.';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final v = await widget.store.load(widget.run.id);
    if (mounted) {
      setState(() {
        rating = v?['feedback']?['rating'];
        shared = v?['receipt']?['shared'] == true;
        shareReady = widget.exactTarget != null || v?['shareReady'] == true;
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
        exactTarget: widget.exactTarget,
      );
      if (share != null) {
        await widget.store.consent(widget.run.id, share);
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
    appBar: AppBar(title: const Text('Личный отзыв о программе')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.run.snapshot.baseTemplateName ?? widget.run.name),
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
