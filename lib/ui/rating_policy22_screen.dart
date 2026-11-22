import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/session_plan.dart' show newId;
import '../services/project22_runtime.dart';

/// Typed numeric parameters only. Formulas are reviewed server strategies,
/// never arbitrary scripts entered by a user. All new coefficients start blank.
class RatingPolicy22Screen extends StatefulWidget {
  const RatingPolicy22Screen({super.key, required this.runtime});
  final Project22Runtime runtime;
  @override
  State<RatingPolicy22Screen> createState() => _RatingPolicy22ScreenState();
}

class _RatingPolicy22ScreenState extends State<RatingPolicy22Screen> {
  static const types = ['COURSE', 'PROGRAM', 'MODULE', 'TRACK'];
  static const sourceKeys = [
    'CLIENT_DIRECT',
    'PRO_DIRECT',
    'COURSE_CONTEXT',
    'PROGRAM_CONTEXT',
  ];
  static const edgeKeys = [
    'SELF',
    'COURSE_PROGRAM',
    'COURSE_MODULE',
    'COURSE_TRACK',
    'PROGRAM_MODULE',
    'PROGRAM_TRACK',
  ];
  static const plainKeys = [
    'partialPermille',
    'maxIndirectPermille',
    'minimumIndependentN',
    'repeatedRootCap',
  ];
  final fields = <String, TextEditingController>{};
  String
  algorithm = 'not-calibrated',
  type = 'PROGRAM',
  policyId = newId(),
  status =
      'Производственные коэффициенты не утверждены. Взвешенная оценка не публикуется.';
  String? draftHash;
  Map<String, dynamic>? history;
  int configVersion = 1;
  bool busy = false;
  TextEditingController field(String path) =>
      fields.putIfAbsent(path, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final v = await widget.runtime.call('policy.history', {});
      if (mounted) setState(() => history = v);
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'История политик не получена. Прежняя модель не изменена.',
        );
      }
    }
  }

  Map<String, dynamic> value() {
    final experimental = algorithm != 'not-calibrated';
    Map<String, int> numbers(String t, String group, List<String> keys) => {
      for (final k in keys) k: int.parse(field('$t.$group.$k').text),
    };
    return {
      'schemaVersion': 1,
      'policyId': policyId,
      'configVersion': configVersion,
      'algorithmId': experimental
          ? 'evidence-mean-experimental'
          : 'not-calibrated',
      'algorithmVersion': algorithm.endsWith('@2') ? 2 : 1,
      'parameterSchemaVersion': 1,
      'config': experimental
          ? {
              'byTarget': {
                for (final t in types)
                  t: {
                    'sourceWeights': numbers(t, 'source', sourceKeys),
                    'edgeWeights': numbers(t, 'edge', edgeKeys),
                    'hopWeights': numbers(t, 'hop', ['0', '1', '2', '3']),
                    for (final k in plainKeys)
                      k: int.parse(field('$t.$k').text),
                  },
              },
            }
          : <String, dynamic>{},
    };
  }

  Future<void> action(String op) async {
    setState(() => busy = true);
    try {
      Map<String, dynamic> result;
      if (op == 'draft') {
        result = await widget.runtime.call('policy.draft', {
          'requestId': newId(),
          'policy': value(),
        });
        draftHash = result['hash'];
      } else if (op == 'preview') {
        final target = (widget.runtime.ratings?['snapshot']?['items'] as List?)
            ?.firstOrNull?['target'];
        if (target == null) throw const FormatException('NO_TARGET');
        result = await widget.runtime.call('policy.preview', {
          'policy': value(),
          'target': target,
        });
      } else {
        result = await widget.runtime.call('policy.validate', {
          'hash': draftHash,
        });
      }
      if (mounted) {
        setState(
          () => status = const JsonEncoder.withIndent('  ').convert(result),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Действие не подтверждено. Заполните допустимые числовые параметры и проверьте доступ. Действующая политика сохранена.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> publish(String hash, {bool rollback = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          rollback
              ? 'Вернуть предыдущую политику?'
              : 'Применить проверенную политику?',
        ),
        content: const Text(
          'Исходные отзывы, аудио и история сохраняются. Взвешенный публичный рейтинг останется неоткалиброванным.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      final q = await widget.runtime.call(
        rollback ? 'policy.rollback' : 'policy.activate',
        {
          'requestId': newId(),
          'hash': hash,
          'expectedRevision': history?['active']?['ratingsRevision'] ?? 0,
        },
      );
      final job = await widget.runtime.call('project.runOperation', {
        'operationId': q['operationId'],
      });
      if (job['state'] != 'SUCCEEDED' ||
          job['receipt']?['outcome'] != 'COMMITTED') {
        throw const FormatException('NOT_COMMITTED');
      }
      await load();
      if (mounted) {
        setState(
          () => status = 'Применение подтверждено квитанцией. Производственный взвешенный расчёт не включён.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Новая политика не подтверждена; предыдущая проверенная версия сохранена.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void cloneDraft(Map d) {
    final p = Map<String, dynamic>.from(d['policy']);
    for (final f in fields.values) {
      f.clear();
    }
    policyId = p['policyId'];
    configVersion = (p['configVersion'] as int) + 1;
    draftHash = null;
    algorithm = p['algorithmId'] == 'not-calibrated'
        ? 'not-calibrated'
        : 'evidence-mean-experimental@${p['algorithmVersion']}';
    if (p['config']['byTarget'] is Map) {
      for (final t in types) {
        final c = p['config']['byTarget'][t] as Map;
        for (final g in [
          ('sourceWeights', 'source'),
          ('edgeWeights', 'edge'),
          ('hopWeights', 'hop'),
        ]) {
          for (final e in (c[g.$1] as Map).entries) {
            field('$t.${g.$2}.${e.key}').text = '${e.value}';
          }
        }
        for (final k in plainKeys) {
          field('$t.$k').text = '${c[k]}';
        }
      }
    }
    setState(
      () => status = 'Создана локальная копия. Изменения пока не применены.',
    );
  }

  Widget number(String path, String label) => TextField(
    controller: field(path),
    enabled: !busy,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => setState(() => draftHash = null),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Модель рейтинга')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(status, key: const Key('policy22-status')),
        Text('Версия конфигурации: $configVersion'),
        DropdownButton<String>(
          value: algorithm,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'not-calibrated',
              child: Text('Без взвешенного расчёта'),
            ),
            DropdownMenuItem(
              value: 'evidence-mean-experimental@1',
              child: Text('Экспериментальная стратегия 1'),
            ),
            DropdownMenuItem(
              value: 'evidence-mean-experimental@2',
              child: Text('Экспериментальная стратегия 2'),
            ),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  algorithm = v!;
                  draftHash = null;
                }),
        ),
        if (algorithm != 'not-calibrated') ...[
          const Text(
            'Параметры используются только для предварительного расчёта. Значения не назначены автоматически.',
          ),
          DropdownButton<String>(
            value: type,
            items: [
              for (final t in types) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => type = v!),
          ),
          for (final k in sourceKeys) number('$type.source.$k', 'Источник $k'),
          for (final k in edgeKeys) number('$type.edge.$k', 'Переход $k'),
          for (final k in ['0', '1', '2', '3'])
            number('$type.hop.$k', 'Глубина $k'),
          for (final k in plainKeys) number('$type.$k', k),
        ],
        OutlinedButton(
          onPressed: busy ? null : () => action('preview'),
          child: const Text('Предпросмотр и сравнение'),
        ),
        FilledButton(
          onPressed:
              busy || widget.runtime.capability?['canManageRoles'] != true
              ? null
              : () => action('draft'),
          child: const Text('Сохранить черновик политики'),
        ),
        OutlinedButton(
          onPressed:
              busy || draftHash == null || !widget.runtime.canPublishPolicy
              ? null
              : () => action('validate'),
          child: const Text('Проверить черновик'),
        ),
        FilledButton(
          onPressed:
              busy || draftHash == null || !widget.runtime.canPublishPolicy
              ? null
              : () => publish(draftHash!),
          child: const Text('Применить после подтверждения'),
        ),
        for (final d in history?['drafts'] as List? ?? [])
          ListTile(
            title: Text(
              '${d['policy']['policyId']} · ${d['policy']['configVersion']} · ${d['validated'] == true ? 'проверен' : 'черновик'}',
            ),
            trailing: TextButton(
              onPressed: busy ? null : () => cloneDraft(d),
              child: const Text('Создать копию'),
            ),
          ),
        for (final h in history?['history'] as List? ?? [])
          ListTile(
            title: Text('Редакция оценок ${h['ratingsRevision']}'),
            subtitle: Text(h['computedAt']),
            trailing: TextButton(
              onPressed: busy || !widget.runtime.canPublishPolicy
                  ? null
                  : () => publish(h['policyHash'], rollback: true),
              child: const Text('Вернуть политику'),
            ),
          ),
      ],
    ),
  );
}
