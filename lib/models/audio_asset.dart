import 'dart:convert';

enum LibrarySection {
  general('Общие аудиозаписи'),
  suggestions('Установки'),
  personal('Мои аудиозаписи');

  const LibrarySection(this.label);
  final String label;
}

enum AudioCategory {
  preparation('Подготовка'),
  induction('Погружение'),
  deepener('Углубление'),
  safePlace('Безопасное место'),
  work('Терапевтическое задание'),
  integration('Интеграция'),
  progression('Прогрессия'),
  suggestions('Установки'),
  exit('Выход'),
  freeform('Другое');

  const AudioCategory(this.label);
  final String label;
}

class AudioAsset {
  const AudioAsset({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationMs,
    required this.format,
    required this.createdAt,
    required this.category,
    required this.fileSizeBytes,
    this.description = '',
    this.section = LibrarySection.general,
    this.tags = const [],
    this.source = 'imported',
    this.origin,
    this.contentHash,
    this.baseRevision = 1,
    this.author,
    this.authorManaged = false,
  });

  final String id;
  final String title;
  // Relative to the app's private audio directory, never an external URI.
  final String filePath;
  final int durationMs;
  final String format;
  final DateTime createdAt;
  final AudioCategory category;
  final int fileSizeBytes;
  final String description;
  final LibrarySection section;
  final List<String> tags;
  final String source;
  final String? origin, contentHash, author;
  final int baseRevision;
  final bool authorManaged;
  bool get authorControlled =>
      authorManaged ||
      origin == 'supplied' ||
      section != LibrarySection.personal;

  /// Origin is independent of content category and legacy presentation section.
  bool get isPersonal =>
      origin == 'personal' ||
      (origin == null &&
          (source == 'recorded' || section == LibrarySection.personal));
  bool get isSuggestion =>
      category == AudioCategory.suggestions ||
      section == LibrarySection.suggestions;

  AudioAsset edited(
    String title,
    AudioCategory category, {
    String? description,
    LibrarySection? section,
    List<String>? tags,
  }) => AudioAsset(
    id: id,
    title: title.trim(),
    filePath: filePath,
    durationMs: durationMs,
    format: format,
    createdAt: createdAt,
    category: category,
    fileSizeBytes: fileSizeBytes,
    description: description ?? this.description,
    section: section ?? this.section,
    tags: List.unmodifiable(tags ?? this.tags),
    source: source,
    origin: origin,
    contentHash: contentHash,
    baseRevision: baseRevision,
    author: author,
    authorManaged: authorManaged,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'durationMs': durationMs,
    'format': format,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'category': category.name,
    'fileSizeBytes': fileSizeBytes,
    'description': description,
    'section': section.name,
    'tags': jsonEncode(tags),
    'source': source,
    'origin': origin ?? (isPersonal ? 'personal' : 'supplied'),
    'contentHash': contentHash,
    'baseRevision': baseRevision,
    'author': author,
    'authorManaged': authorManaged ? 1 : 0,
  };

  factory AudioAsset.fromMap(Map<String, Object?> row) => AudioAsset(
    id: row['id'] as String,
    title: row['title'] as String,
    filePath: row['filePath'] as String,
    durationMs: row['durationMs'] as int,
    format: row['format'] as String,
    createdAt: DateTime.parse(row['createdAt'] as String),
    category: AudioCategory.values.byName(row['category'] as String),
    fileSizeBytes: row['fileSizeBytes'] as int,
    description: row['description'] as String? ?? '',
    section: LibrarySection.values.byName(
      row['section'] as String? ?? 'general',
    ),
    tags: List.unmodifiable(
      (jsonDecode(row['tags'] as String? ?? '[]') as List).cast<String>(),
    ),
    source: row['source'] as String? ?? 'imported',
    origin: row['origin'] as String?,
    contentHash: row['contentHash'] as String?,
    baseRevision: row['baseRevision'] as int? ?? 1,
    author: row['author'] as String?,
    authorManaged: row['authorManaged'] == 1,
  );
}

String formatDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}

String formatPause(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Explicit units for the session card; pause digits keep their separate MM:SS UI.
String formatDurationWords(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final hours = seconds ~/ 3600;
  final minutes = seconds ~/ 60 % 60;
  return '${hours > 0 ? '$hours ч ' : ''}$minutes мин ${(seconds % 60).toString().padLeft(2, '0')} с';
}
