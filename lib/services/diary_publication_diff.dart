import 'dart:convert';

import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import '../models/content_revision.dart';

class DiaryDiffPlan {
  DiaryDiffPlan(this.newDigests, this.retainedDigests);
  final Set<String> newDigests, retainedDigests;
  int get mediaUploads => newDigests.length;
  factory DiaryDiffPlan.between(
    DiaryEntry? previous,
    DiaryEntry next, {
    Set<String> existingBlobs = const {},
  }) {
    Set<String> hashes(DiaryEntry? e) =>
        e?.blocks.where((b) => b.media != null).map((b) {
          final h = b.media!.hash;
          if (h == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(h)) {
            throw const FormatException('Вложению нужен проверенный SHA-256');
          }
          return h;
        }).toSet() ??
        {};
    final before = hashes(previous), after = hashes(next);
    return DiaryDiffPlan(
      Set.unmodifiable(after.difference({...before, ...existingBlobs})),
      Set.unmodifiable({...before, ...after}),
    );
  }
}

/// Future contract only. Never passed to the legacy Apps Script client.
/// No local paths, arbitrary locators, author drafts or reader state are public.
Map<String, dynamic> diaryPublicManifest(DiaryEntry e) {
  final map = Map<String, dynamic>.from(e.toMap(public: true));
  map['publication'] = DiaryPublication.of(e).toMap();
  map['contentLinks'] = e.contentLinks.map((l) => l.toMap()).toList();
  map['blocks'] = e.blocks.where((b) => b.substantive).map((b) {
    final m = Map<String, dynamic>.from(b.toMap(public: true));
    if (b.media != null) {
      final media = b.media!;
      if (media.hash == null ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(media.hash!)) {
        throw const FormatException('Нет SHA-256 вложения');
      }
      m['media'] = {
        'assetId': media.assetId,
        'mime': media.mime,
        'bytes': media.bytes,
        'hash': media.hash,
      };
    }
    return m;
  }).toList();
  map.remove('body'); // One ordered block representation.
  // Explicit compatibility namespace; unknown private root fields never leak.
  if (e.extra['publicExtensions'] is Map) {
    map['publicExtensions'] = e.extra['publicExtensions'];
  }
  return Map<String, dynamic>.from(jsonDecode(canonicalContent(map)));
}
