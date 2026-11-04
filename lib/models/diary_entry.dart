enum DiaryStatus { draft, published, unpublished }

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.message,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.version = 0,
    this.publishedAt,
    this.status = DiaryStatus.draft,
    this.number,
  });
  final String id, message, body;
  final int version;
  final int? number;
  final DateTime createdAt, updatedAt;
  final DateTime? publishedAt;
  final DiaryStatus status;

  DiaryEntry copyWith({
    String? message,
    String? body,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DiaryStatus? status,
    int? version,
  }) => DiaryEntry(
    id: id,
    message: message ?? this.message,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    publishedAt: publishedAt ?? this.publishedAt,
    status: status ?? this.status,
    version: version ?? this.version,
    number: number,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'message': message,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'status': status.name,
    'version': version,
    'number': number,
  };
  factory DiaryEntry.fromMap(Map<String, dynamic> m) {
    final entry = DiaryEntry(
      id: m['id'] as String,
      message: m['message'] as String,
      body: m['body'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      publishedAt: m['publishedAt'] == null
          ? null
          : DateTime.parse(m['publishedAt'] as String),
      status: DiaryStatus.values.byName(m['status'] as String),
      version: m['version'] as int,
      number: m['number'] as int?,
    );
    if (entry.id.isEmpty ||
        entry.version < 0 ||
        entry.message.length > 1000 ||
        entry.body.length > 1000000) {
      throw const FormatException('Некорректная запись дневника');
    }
    return entry;
  }
}
