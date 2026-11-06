import 'dart:io';

import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/preview_player.dart';

AudioAsset sampleAsset({
  String id = 'sample',
  String title = 'Тестовая запись',
}) => AudioAsset(
  id: id,
  title: title,
  filePath: 'asset_$id.wav',
  durationMs: 65000,
  format: 'wav',
  createdAt: DateTime.utc(2026),
  category: AudioCategory.freeform,
  fileSizeBytes: 1024,
);

class MemoryRepository implements LibraryRepository {
  final Map<String, AudioAsset> items = {};
  bool failSave = false;
  @override
  Future<List<AudioAsset>> list() async => items.values.toList();
  @override
  Future<void> save(AudioAsset asset) async {
    if (failSave) throw StateError('test storage failure');
    items[asset.id] = asset;
  }

  @override
  Future<void> delete(String id) async {
    items.remove(id);
  }

  @override
  Future<void> clear() async {
    items.clear();
  }
}

class MemoryLibrary extends LibraryService {
  MemoryLibrary(MemoryRepository repository)
    : super(
        repository: repository,
        directory: Directory.systemTemp,
        pick: () async => null,
        probe: (_) async => null,
      );
  AudioAsset? importResult;
  bool importFails = false;
  bool discarded = false;
  @override
  Future<AudioAsset?> prepareImport() async {
    if (importFails) throw const LibraryException('Повреждённый файл');
    return importResult;
  }

  @override
  Future<void> discard(AudioAsset asset) async {
    discarded = true;
  }

  @override
  Future<void> delete(AudioAsset asset) => repository.delete(asset.id);
  @override
  Future<void> reset() => repository.clear();
}

class MemoryPlayer extends PreviewPlayer {
  AudioAsset? _current;
  bool _playing = false;
  @override
  AudioAsset? get current => _current;
  @override
  bool get playing => _playing;
  @override
  Duration get position => Duration.zero;
  @override
  String? get error => null;
  @override
  Future<void> toggle(AudioAsset asset, File file) async {
    _playing = _current?.id == asset.id ? !_playing : true;
    _current = asset;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _current = null;
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> close() async {
    dispose();
  }
}

class MemorySessionRepository implements SessionRepository {
  CurrentSessionDraft? draft;
  final Map<String, SessionTemplate> savedTemplates = {};
  final Map<String, SessionRun> savedRuns = {};
  final Map<String, List<Map<String, dynamic>>> journal = {};
  int _number = 0;
  @override
  Future<CurrentSessionDraft?> loadDraft() async => draft;
  @override
  Future<void> saveDraft(CurrentSessionDraft d) async {
    draft = CurrentSessionDraft.fromMap(d.toMap());
  }

  @override
  Future<List<SessionTemplate>> templates() async =>
      savedTemplates.values.toList();
  @override
  Future<void> saveTemplate(SessionTemplate t) async {
    savedTemplates[t.id] = t;
  }

  @override
  Future<void> deleteTemplate(String id) async {
    savedTemplates.remove(id);
  }

  @override
  Future<void> setDefault(String id) async {
    for (final t in savedTemplates.values.toList()) {
      final m = t.toMap();
      m['isDefault'] = id == t.id;
      savedTemplates[t.id] = SessionTemplate.fromMap(m);
    }
  }

  @override
  Future<int> nextNumber() async => _number + 1;
  @override
  Future<SessionRun> startRun(CurrentSessionDraft snapshot) async {
    final now = DateTime.now().toUtc();
    final r = SessionRun(
      id: newId(),
      displayNumber: ++_number,
      name: formatLocalDate(now),
      snapshot: CurrentSessionDraft.fromMap(snapshot.toMap()),
      startedAt: now,
      startedUtcOffsetMinutes: now.toLocal().timeZoneOffset.inMinutes,
      status: RunStatus.running,
    );
    savedRuns[r.id] = r;
    return r;
  }

  @override
  Future<void> checkpoint(SessionRun run, {String? event}) async {
    savedRuns[run.id] = run;
    if (event != null) {
      (journal[run.id] ??= []).add({
        'eventType': event,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'stepIndex': run.stepIndex,
        'phase': run.phase,
        'playheadMs': run.playheadMs,
        'elapsedMs': run.elapsedMs,
      });
    }
  }

  @override
  Future<List<SessionRun>> history() async => savedRuns.values.toList();
  @override
  Future<List<Map<String, dynamic>>> events(String runId) async =>
      journal[runId] ?? [];
  @override
  Future<void> editRun(String id, {String? name, String? notes}) async {
    final m = savedRuns[id]!.toMap();
    if (name != null) m['name'] = name;
    if (notes != null) m['userNotes'] = notes;
    savedRuns[id] = SessionRun.fromMap(m);
  }

  @override
  Future<void> deleteRun(String id) async {
    savedRuns.remove(id);
    journal.remove(id);
  }

  @override
  Future<void> interruptUnfinished() async {}
  @override
  Future<List<String>> references(String assetId) async => [];
  @override
  Future<void> reset() async {
    savedTemplates.clear();
    savedRuns.clear();
    journal.clear();
    draft = null;
    _number = 0;
  }
}
