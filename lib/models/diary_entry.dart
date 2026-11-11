import 'content_link.dart';

enum DiaryStatus { draft, published, unpublished }

enum DiaryBlockType { text, image, audio, video }

/// Private local location is never included in a public projection.
class DiaryMedia {
  const DiaryMedia({
    required this.assetId,
    required this.mime,
    required this.bytes,
    this.localPath,
    this.locator,
    this.hash,
  });
  final String assetId, mime;
  final int bytes;
  final String? localPath, locator, hash;
  Map<String, Object?> toMap({bool public = false}) => {
    'assetId': assetId,
    'mime': mime,
    'bytes': bytes,
    if (!public) 'localPath': localPath,
    'locator': locator,
    'hash': hash,
  };
  factory DiaryMedia.fromMap(Map<String, dynamic> m) => DiaryMedia(
    assetId: m['assetId'] as String,
    mime: m['mime'] as String,
    bytes: m['bytes'] as int,
    localPath: m['localPath'] as String?,
    locator: m['locator'] as String?,
    hash: m['hash'] as String?,
  );
}

class DiaryBlock {
  const DiaryBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.media,
    this.width,
    this.height,
    this.altText = '',
    this.caption = '',
    this.label = '',
    this.durationMs,
  });
  final String id, text, altText, caption, label;
  final DiaryBlockType type;
  final DiaryMedia? media;
  final int? width, height, durationMs;
  bool get substantive =>
      type == DiaryBlockType.text ? text.trim().isNotEmpty : media != null;
  DiaryBlock copyWith({
    String? text,
    DiaryMedia? media,
    int? width,
    int? height,
    String? altText,
    String? caption,
    String? label,
    int? durationMs,
  }) => DiaryBlock(
    id: id,
    type: type,
    text: text ?? this.text,
    media: media ?? this.media,
    width: width ?? this.width,
    height: height ?? this.height,
    altText: altText ?? this.altText,
    caption: caption ?? this.caption,
    label: label ?? this.label,
    durationMs: durationMs ?? this.durationMs,
  );
  Map<String, Object?> toMap({bool public = false}) => {
    'id': id,
    'type': type.name,
    'text': text,
    'media': media?.toMap(public: public),
    'width': width,
    'height': height,
    'altText': altText,
    'caption': caption,
    'label': label,
    'durationMs': durationMs,
  };
  factory DiaryBlock.fromMap(Map<String, dynamic> m) {
    final b = DiaryBlock(
      id: m['id'] as String,
      type: DiaryBlockType.values.byName(m['type'] as String),
      text: m['text'] as String? ?? '',
      media: m['media'] == null
          ? null
          : DiaryMedia.fromMap(m['media'] as Map<String, dynamic>),
      width: m['width'] as int?,
      height: m['height'] as int?,
      altText: m['altText'] as String? ?? '',
      caption: m['caption'] as String? ?? '',
      label: m['label'] as String? ?? '',
      durationMs: m['durationMs'] as int?,
    );
    if (b.id.isEmpty ||
        (b.durationMs ?? 0) < 0 ||
        (b.type == DiaryBlockType.image &&
            ((b.width ?? 0) <= 0 || (b.height ?? 0) <= 0)) ||
        (b.type != DiaryBlockType.text &&
            (b.media == null ||
                b.media!.assetId.isEmpty ||
                b.media!.bytes < 0))) {
      throw const FormatException('Некорректный блок дневника');
    }
    return b;
  }
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.message,
    String body = '',
    this.title = '',
    List<DiaryBlock>? blocks,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
    this.version = 0,
    this.publishedAt,
    this.status = DiaryStatus.draft,
    this.number,
    this.readingState = const {},
    this.extra = const {},
    // ignore: prefer_initializing_formals
  }) : _body = body,
       _blocks = blocks == null ? null : List.unmodifiable(blocks);
  // Legacy private state is retained verbatim. New reader state lives separately
  // in DiaryReadStore, never in the author publication.
  final Map<String, dynamic> readingState;
  final Map<String, dynamic> extra;
  List<ContentLink> get contentLinks {
    final result = <ContentLink>[];
    for (final raw
        in extra['contentLinks'] is List
            ? extra['contentLinks'] as List
            : const []) {
      try {
        result.add(ContentLink.fromMap(Map<String, dynamic>.from(raw)));
      } catch (_) {
        /* Future link types retained verbatim, not executed. */
      }
    }
    return List.unmodifiable(result);
  }

  final String id, message, title, _body;
  final List<DiaryBlock>? _blocks;
  final int version, order;
  final int? number;
  final DateTime createdAt, updatedAt;
  final DateTime? publishedAt;
  final DiaryStatus status;
  String get displayTitle => title.trim().isEmpty
      ? (message.isEmpty ? 'Без названия' : message)
      : title;
  String get body => _blocks == null
      ? _body
      : _blocks
            .where((b) => b.type == DiaryBlockType.text)
            .map((b) => b.text)
            .join('\n\n');
  List<DiaryBlock> get blocks => List.unmodifiable(
    _blocks ??
        [DiaryBlock(id: '$id-text', type: DiaryBlockType.text, text: _body)],
  );
  bool get multimedia => blocks.any((b) => b.type != DiaryBlockType.text);
  String? get publicationError => publicationErrorFor();
  String? publicationErrorFor({bool advanced = false}) {
    if (!advanced &&
        (extra.containsKey('contentLinks') ||
            extra.containsKey('publication'))) {
      return 'Новые настройки и ссылки пока доступны локально. Публикация требует подтверждённого серверного контракта.';
    }
    if (title.trim().isEmpty) return 'Заполните название записи';
    if (message.trim().isEmpty) return 'Заполните короткое послание';
    if (!blocks.any((b) => b.substantive)) {
      return 'Добавьте содержательный блок';
    }
    return null;
  }

  DiaryEntry copyWith({
    String? message,
    String? body,
    String? title,
    List<DiaryBlock>? blocks,
    int? order,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DiaryStatus? status,
    int? version,
    Map<String, dynamic>? extra,
  }) => DiaryEntry(
    id: id,
    message: message ?? this.message,
    title: title ?? this.title,
    body: body ?? this.body,
    blocks: blocks ?? (body == null ? _blocks : null),
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    publishedAt: publishedAt ?? this.publishedAt,
    status: status ?? this.status,
    version: version ?? this.version,
    number: number,
    readingState: readingState,
    extra: extra ?? this.extra,
  );
  Map<String, Object?> toMap({bool public = false}) => {
    if (!public) ...extra,
    'schemaVersion': 2,
    'id': id,
    'title': title,
    'message': message,
    'body': body,
    'blocks': blocks
        .where((b) => !public || b.substantive)
        .map((b) => b.toMap(public: public))
        .toList(),
    'order': order,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'status': status.name,
    'version': version,
    'number': number,
    if (!public && readingState.isNotEmpty) 'readingState': readingState,
  };
  factory DiaryEntry.fromMap(Map<String, dynamic> m) {
    if ((m['schemaVersion'] as int? ?? 1) > 2) {
      throw const FormatException('Неизвестная версия записи');
    }
    final entry = DiaryEntry(
      id: m['id'] as String,
      message: m['message'] as String,
      body: m['body'] as String? ?? '',
      title: m['title'] as String? ?? '',
      blocks: m['blocks'] == null
          ? null
          : (m['blocks'] as List)
                .map((b) => DiaryBlock.fromMap(b as Map<String, dynamic>))
                .toList(),
      order: m['order'] as int? ?? 0,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      publishedAt: m['publishedAt'] == null
          ? null
          : DateTime.parse(m['publishedAt'] as String),
      status: DiaryStatus.values.byName(m['status'] as String),
      version: m['version'] as int,
      number: m['number'] as int?,
      readingState: Map<String, dynamic>.from(m['readingState'] ?? {}),
      extra: {
        for (final e in m.entries)
          if (!{
            'schemaVersion',
            'id',
            'title',
            'message',
            'body',
            'blocks',
            'order',
            'createdAt',
            'updatedAt',
            'publishedAt',
            'status',
            'version',
            'number',
            'readingState',
          }.contains(e.key))
            e.key: e.value,
      },
    );
    if (entry.id.isEmpty ||
        entry.version < 0 ||
        entry.message.length > 1000000 ||
        entry.body.length > 1000000 ||
        entry.title.length > 1000000 ||
        entry.blocks.map((b) => b.id).toSet().length != entry.blocks.length) {
      throw const FormatException('Некорректная запись дневника');
    }
    return entry;
  }
}
