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
  work('Терапевтическое задание'),
  integration('Интеграция'),
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
