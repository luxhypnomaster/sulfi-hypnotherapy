import 'package:flutter/material.dart';

import '../models/ratings22.dart';

class Rating22Summary extends StatelessWidget {
  const Rating22Summary({super.key, required this.value, required this.stale});
  final Map<String, dynamic>? value;
  final bool stale;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Пользовательский: ${value == null && stale ? 'Нет данных' : directLabel22(value?['consumerDirect'])}',
      ),
      Text(
        'Профессиональный: ${value == null && stale ? 'Нет данных' : directLabel22(value?['professionalDirect'])}',
      ),
      const Text('Взвешенный: модель не откалибрована'),
      if (value != null)
        Text(
          'Косвенных источников: ${value!['evidenceCounts']?['contextCourseN'] ?? 0} курсов, ${value!['evidenceCounts']?['contextProgramN'] ?? 0} программ',
        ),
      if (stale) const Text('Сохранённая копия; актуальность не подтверждена'),
    ],
  );
}
