import 'diary_entry.dart';
import 'session_plan.dart';

const diaryCategories = <String, String>{
  'entertainment': 'Развлечения',
  'tarot': 'Таро',
  'announcements': 'Объявления',
  'appointment': 'Запись на приём',
  'critical_updates': 'Критические обновления приложения',
  'new_content': 'Новые модули и шаблоны',
};

/// Optional local/future-contract metadata. Unknown keys stay in DiaryEntry.extra.
class DiaryPublication {
  const DiaryPublication({
    this.categoryId = 'announcements',
    this.highPriority = false,
    this.urgent = false,
    required this.cycle,
    required this.activatedAt,
    this.authorClosed = false,
    this.validUntil,
  });
  final String categoryId, cycle;
  final bool highPriority, urgent, authorClosed;
  final DateTime activatedAt;
  final DateTime? validUntil;
  String get categoryName =>
      diaryCategories[categoryId] ?? 'Неизвестная категория';
  bool active(DiaryEntry e, DateTime now) =>
      e.status == DiaryStatus.published &&
      !authorClosed &&
      (validUntil == null || now.toUtc().isBefore(validUntil!));
  factory DiaryPublication.of(DiaryEntry e) {
    final raw = e.extra['publication'];
    final m = raw is Map ? raw : const {};
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toUtc() : null;
    return DiaryPublication(
      categoryId: m['categoryId'] as String? ?? 'announcements',
      highPriority: m['priority'] == 'high',
      urgent: m['urgent'] == true,
      cycle:
          m['activationCycleId'] as String? ??
          'legacy:${e.id}:${e.publishedAt?.toUtc().toIso8601String() ?? e.createdAt.toUtc().toIso8601String()}',
      activatedAt: date(m['activatedAt']) ?? e.publishedAt ?? e.createdAt,
      authorClosed: m['authorClosed'] == true,
      validUntil: date(m['validUntil']),
    );
  }
  Map<String, dynamic> toMap() => {
    'categoryId': categoryId,
    'priority': highPriority ? 'high' : 'normal',
    'urgent': urgent,
    'activationCycleId': cycle,
    'activatedAt': activatedAt.toUtc().toIso8601String(),
    'authorClosed': authorClosed,
    'validUntil': validUntil?.toUtc().toIso8601String(),
  };
  DiaryEntry apply(DiaryEntry e) => e.copyWith(
    extra: {
      ...e.extra,
      'publication': {
        if (e.extra['publication'] is Map)
          ...Map<String, dynamic>.from(e.extra['publication']),
        ...toMap(),
      },
    },
  );
  DiaryPublication changed({
    String? categoryId,
    bool? highPriority,
    bool? urgent,
    bool? authorClosed,
    DateTime? validUntil,
    bool clearExpiry = false,
    bool reannounce = false,
    DateTime? now,
  }) => DiaryPublication(
    categoryId: categoryId ?? this.categoryId,
    highPriority: highPriority ?? this.highPriority,
    urgent: urgent ?? this.urgent,
    cycle: reannounce ? newId() : cycle,
    activatedAt: reannounce ? (now ?? DateTime.now()).toUtc() : activatedAt,
    authorClosed: reannounce ? false : authorClosed ?? this.authorClosed,
    validUntil: clearExpiry ? null : validUntil ?? this.validUntil,
  );
}

/// Stable order: newest activation first, then high/normal alternation; ties by ID.
/// Cursor advances explicitly, never during widget build.
List<DiaryEntry> diaryRotation(
  Iterable<DiaryEntry> entries,
  DateTime now,
  bool Function(DiaryEntry) isRead,
) {
  final all = entries
      .where((e) => DiaryPublication.of(e).active(e, now) && !isRead(e))
      .toList();
  int compare(DiaryEntry a, DiaryEntry b) {
    final n = DiaryPublication.of(b).activatedAt
        .compareTo(DiaryPublication.of(a).activatedAt);
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  all.sort(compare);
  if (all.isEmpty) return all;
  final newest = all.removeAt(0);
  final high = all.where((e) => DiaryPublication.of(e).highPriority).toList();
  final normal = all
      .where((e) => !DiaryPublication.of(e).highPriority)
      .toList();
  final result = [newest];
  var takeHigh = !DiaryPublication.of(newest).highPriority;
  while (high.isNotEmpty || normal.isNotEmpty) {
    final queue = takeHigh
        ? (high.isEmpty ? normal : high)
        : (normal.isEmpty ? high : normal);
    result.add(queue.removeAt(0));
    takeHigh = !takeHigh;
  }
  return result;
}
