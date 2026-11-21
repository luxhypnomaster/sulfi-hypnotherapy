import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import '../models/vitrine_config.dart';

/// Pure slide-boundary state machine; no network, audio, read marks or timers.
/// Widget supplies the clock and one cancellable timer, fake clock in tests.
class DiaryCarousel {
  DiaryCarousel({this.config = const VitrineConfig()}) {
    config.validate();
  }
  VitrineConfig config;
  List<DiaryEntry> _entries = [], _slides = [];
  List<DiaryEntry>? _pending;
  VitrineConfig? _pendingConfig;
  int _index = -1, _pinCursor = 0;
  final _shown = <String>{};
  String _token(DiaryEntry e) => '${e.id}|${DiaryPublication.of(e).cycle}';
  DiaryEntry? get current =>
      _index < 0 || _slides.isEmpty ? null : _slides[_index];
  bool get hasEntries => _entries.isNotEmpty || (_pending?.isNotEmpty ?? false);
  Duration get duration => Duration(
    seconds: current == null ? config.splashSeconds : config.entrySeconds,
  );

  void update(
    Iterable<DiaryEntry> entries,
    DateTime now,
    bool Function(DiaryEntry) isRead, {
    VitrineConfig? nextConfig,
  }) {
    final ready = entries
        .where((e) => DiaryPublication.of(e).active(e, now) && !isRead(e))
        .toList();
    if (nextConfig != null) {
      nextConfig.validate();
      _pendingConfig = nextConfig;
    }
    final was = current;
    final valid = ready
        .where(
          (e) =>
              e.id == was?.id &&
              DiaryPublication.of(e).cycle == DiaryPublication.of(was!).cycle,
        )
        .firstOrNull;
    if (was != null && valid == null) {
      // Revocation / expiry / read / account switch is immediate, never wait7s.
      _entries = ready;
      _pending = null;
      _slides = _cycle(ready);
      _index = -1;
      _shown.clear();
    } else if (_entries.isEmpty && was == null) {
      _entries = ready;
      _slides = _cycle(ready);
      _pending = null;
    } else {
      _pending = ready; // collapse any number of refreshes into one boundary.
    }
  }

  void advance() {
    final oldId = current?.id;
    if (_pendingConfig != null) {
      config = _pendingConfig!;
      _pendingConfig = null;
    }
    if (_pending != null) {
      _entries = _pending!;
      _pending = null;
      // Preserve the rest of this cycle where possible; append new ready posts.
      final remaining = _index < 0
          ? <DiaryEntry>[]
          : _slides.skip(_index + 1).toList();
      final ids = remaining.map((e) => e.id).toSet();
      _slides = [
        ...remaining.where((e) => _entries.any((v) => v.id == e.id)),
        ..._cycle(_entries)
            .where((e) => !ids.contains(e.id) && !_shown.contains(_token(e))),
      ];
      _index = -1;
      if (_slides.isEmpty && oldId != null) {
        _shown.clear();
        return; // End of full cycle still gets its splash after a quiet refresh.
      }
      if (config.splashMode == VitrineSplashMode.betweenEntries &&
          oldId != null) {
        return;
      }
    } else if (current != null &&
        config.splashMode == VitrineSplashMode.betweenEntries) {
      _slides = _slides.skip(_index + 1).toList();
      _index = -1;
      if (_slides.isEmpty) {
        _shown.clear();
      }
      return;
    }
    if (_slides.isEmpty) _slides = _cycle(_entries);
    if (_slides.isEmpty) {
      _index = -1;
      return;
    }
    _index++;
    if (_index >= _slides.length) {
      _slides = _cycle(_entries);
      _index = -1;
      _shown.clear();
    } else if (current != null) {
      _shown.add(_token(current!));
    }
  }

  List<DiaryEntry> _cycle(List<DiaryEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) {
        final n = DiaryPublication.of(b).activatedAt
            .compareTo(DiaryPublication.of(a).activatedAt);
        return n == 0 ? a.id.compareTo(b.id) : n;
      });
    final high = sorted
        .where((e) => DiaryPublication.of(e).highPriority)
        .toList();
    final normal = sorted
        .where((e) => !DiaryPublication.of(e).highPriority)
        .toList();
    final ordered = <DiaryEntry>[];
    while (high.isNotEmpty || normal.isNotEmpty) {
      for (var i = 0; i < config.highWeight && high.isNotEmpty; i++) {
        ordered.add(high.removeAt(0));
      }
      for (var i = 0; i < config.normalWeight && normal.isNotEmpty; i++) {
        ordered.add(normal.removeAt(0));
      }
    }
    final pins = sorted
        .where(
          (e) =>
              e.extra['publication'] is Map &&
              (e.extra['publication'] as Map)['pinned'] == true,
        )
        .toList();
    if (pins.isEmpty || pins.length == entries.length) return ordered;
    final result = <DiaryEntry>[];
    var regular = 0;
    for (final e in ordered) {
      // N=1 is bounded to one extra pin between base entries: never starve.
      if (regular >= (config.pinnedEveryNth - 1).clamp(1, 1000)) {
        final pin = pins[_pinCursor++ % pins.length];
        if (result.lastOrNull?.id != pin.id && e.id != pin.id) result.add(pin);
        regular = 0;
      }
      result.add(e);
      regular++;
    }
    return result;
  }
}
