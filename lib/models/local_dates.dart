const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
String localDateLabel(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String historicalDateLabel(DateTime utc, int? offset, {String? legacyLabel}) {
  if (offset != null) {
    return localDateLabel(utc.toUtc().add(Duration(minutes: offset)));
  }
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{2}) · (\d{2}):(\d{2})$')
      .firstMatch(legacyLabel ?? '');
  if (match != null) {
    final d = DateTime.utc(
      2000 + int.parse(match[3]!),
      int.parse(match[2]!),
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
    );
    return '${localDateLabel(d)} · часовой пояс неизвестен';
  }
  return '${localDateLabel(utc.toUtc())} UTC · исходный часовой пояс неизвестен';
}
