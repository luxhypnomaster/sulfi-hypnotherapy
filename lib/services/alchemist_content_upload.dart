import '../models/content_revision.dart';
import 'alchemist_api.dart';
import 'alchemist_media_transfer.dart';
import 'capsule_service.dart';
import 'local_content_catalog.dart';

/// One exact closure uploader shared by author catalog and diary ContentLinks.
Future<Map<String, Map<String, dynamic>>> registerAlchemistContent(
  CapsuleService service,
  AlchemistApi api,
  List<RevisionKey> roots, {
  List<ContentRevision> embedded = const [],
  bool Function()? interrupted,
  void Function(int, int)? progress,
  void Function(String)? onStage,
  String? taskId,
}) async {
  final originalOwner = api.ownerBinding,
      originalEpoch = api.identityEpoch?.call();
  bool stopped() =>
      interrupted?.call() == true ||
      originalOwner != api.ownerBinding ||
      originalEpoch != api.identityEpoch?.call();
  final index = [
    ...await LocalCatalogSource.currentIndex(service),
    ...embedded,
  ];
  final closure = resolveContentRoots(roots, index),
      refs = <String, Map<String, dynamic>>{};
  final assets = await service.library.repository.list();
  final totalBytes = closure.revisions
      .where((r) => r.key.content.type == ContentType.track)
      .fold<int>(0, (n, r) => n + (r.payload['fileSizeBytes'] as int));
  var acknowledged = 0;
  for (final r in closure.revisions) {
    if (stopped()) {
      throw const FormatException('Передача приостановлена');
    }
    if (r.key.content.type == ContentType.track) {
      final asset = assets.singleWhere((a) => a.id == r.key.content.id);
      final mime = switch (asset.format.toLowerCase()) {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        _ => throw const FormatException('Неподдерживаемый формат'),
      };
      await AlchemistMediaTransfer(service.database, api).upload(
        service.library.fileFor(asset),
        logicalId: asset.id,
        revisionId: r.key.revision,
        mime: mime,
        expectedHash: r.payload['contentHash'],
        interrupted: stopped,
        progress: (n, _) => progress?.call(acknowledged + n, totalBytes),
        onStage: onStage,
        taskId: taskId,
      );
      acknowledged += asset.fileSizeBytes;
    }
    if (stopped()) {
      throw const FormatException('Передача приостановлена');
    }
    onStage?.call('manifest_registering');
    final body = {
      'type': r.key.content.type.name,
      'logicalId': r.key.content.id,
      'payload': r.payload,
      'dependencies': r.dependencies.map((d) => d.toMap()).toList(),
      'parent': r.parent?.toMap(),
      'declaredVersion': r.declaredVersion,
    };
    refs[r.key.token] = await api.call('content.registerManifest', {
      'revision': r.toMap(),
      'canonicalBody': canonicalContent(body),
      'canonicalRevision': canonicalContent(r.toMap()),
    });
  }
  return refs;
}
