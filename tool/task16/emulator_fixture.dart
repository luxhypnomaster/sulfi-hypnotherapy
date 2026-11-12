// Synthetic Android QA precondition, serialized by the real application models.
// No database path argument, user data, credentials, roles or cloud writes.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';

Future<void> main(List<String> args) async {
  final fixture = File('scripts/task16_autonomous/fixture.json');
  if (args.contains('--check')) {
    final m = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    final audio = AudioAsset.fromMap(Map<String, Object?>.from(m['audio']));
    final draft = CurrentSessionDraft.fromMap(
      Map<String, dynamic>.from(m['draft']),
    );
    final template = SessionTemplate.fromMap(
      Map<String, dynamic>.from(m['template']),
    );
    final bytes = await File('test/fixtures/android_aac_isom.m4a')
        .readAsBytes();
    if (audio.contentHash != sha256.convert(bytes).toString() ||
        audio.fileSizeBytes != bytes.length ||
        canonicalContent(audio.toMap()) != canonicalContent(m['audio']) ||
        canonicalContent(draft.toMap()) != canonicalContent(m['draft']) ||
        canonicalContent(template.toMap()) != canonicalContent(m['template']) ||
        !draft.plan.hasExitAudio ||
        template.plan.steps.single.audioAssetId != audio.id) {
      throw StateError('Invalid synthetic emulator precondition');
    }
    stdout.writeln('EMULATOR_FIXTURE_REAL_MODEL_ROUNDTRIP=PASS');
    return;
  }
  final now = DateTime.utc(2026, 11, 11);
  final bytes = await File('test/fixtures/android_aac_isom.m4a').readAsBytes();
  final audio = AudioAsset(
    id: 'emulator-fixture',
    title: 'EMU AAC fixture',
    filePath: 'asset_emulator_fixture.m4a',
    durationMs: 12000,
    format: 'm4a',
    createdAt: now,
    category: AudioCategory.exit,
    fileSizeBytes: bytes.length,
    description: 'Synthetic test fixture, not therapy',
    section: LibrarySection.personal,
    origin: 'personal',
    contentHash: sha256.convert(bytes).toString(),
  );
  final plan = SessionPlan(
    steps: [
      SessionStep(
        id: 'emu-step',
        kind: StepKind.audio,
        title: audio.title,
        audioAssetId: audio.id,
        durationMs: audio.durationMs,
      ),
    ],
    exitStepId: 'emu-step',
  );
  final m = {
    'audio': audio.toMap(),
    'draft': CurrentSessionDraft(
      plan: plan,
      updatedAt: now,
      notes: 'EMULATOR ONLY',
    ).toMap(),
    'template': SessionTemplate(
      id: 'emu-template',
      name: 'EMU template',
      plan: plan,
      createdAt: now,
      updatedAt: now,
    ).toMap(),
  };
  await fixture.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(m)}\n',
  );
}
