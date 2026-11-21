import 'content_revision.dart';
import 'vitrine_config.dart';

const metadataContract = 'alchemist.metadata/1';
const metadataCanonical = 'sorted-json-utf8-int-v1';
const metadataOperations = {
  'catalog.head',
  'catalog.snapshot',
  'vitrine.configRead',
  'vitrine.configPrepare',
  'vitrine.configCommit',
};

/// Independent config counter/hash/scope, never inferred from catalog revision.
VitrineConfig verifyVitrineView(Map view, String scope) {
  final h = view['head'], s = view['snapshot'];
  if (h is! Map ||
      s is! Map ||
      h['schemaVersion'] != 1 ||
      s['schemaVersion'] != 1 ||
      h['scope'] != scope ||
      s['scope'] != scope ||
      h['configRevision'] is! int ||
      h['configRevision'] < 1 ||
      h['configRevision'] != s['configRevision'] ||
      contentDigest(s) != h['snapshotHash'] ||
      h['snapshotId'] != 'sha256-${h['snapshotHash']}') {
    throw const FormatException('CONFIG_VERIFY_FAILED');
  }
  return VitrineConfig.fromMap(s['config']);
}
