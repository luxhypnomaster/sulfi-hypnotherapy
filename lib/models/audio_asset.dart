enum AudioCategory {
  induction('Введение'),
  deepener('Углубление'),
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

  AudioAsset edited(String title, AudioCategory category) => AudioAsset(
    id: id,
    title: title.trim(),
    filePath: filePath,
    durationMs: durationMs,
    format: format,
    createdAt: createdAt,
    category: category,
    fileSizeBytes: fileSizeBytes,
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
  );
}

String formatDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}
