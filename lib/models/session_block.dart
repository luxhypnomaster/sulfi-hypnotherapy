// Separate types for the next milestone. Topic recordings belong to a session,
// and must never implicitly become an AudioBlock in the playback sequence.
sealed class SessionBlock {
  const SessionBlock(this.id);
  final String id;
}

final class AudioBlock extends SessionBlock {
  const AudioBlock(super.id, {required this.assetId});
  final String assetId;
}

final class SilenceBlock extends SessionBlock {
  const SilenceBlock(super.id, {required this.duration});
  final Duration duration;
}

final class RecordMicBlock extends SessionBlock {
  const RecordMicBlock(super.id, {required this.duration});
  final Duration duration;
}
