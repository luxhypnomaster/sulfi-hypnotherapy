import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Separate protocol22 canonical form. Protocol21's integer-only wire stays
/// unchanged. Ratings use at most3decimal places; integer doubles normalize.
String canonical22(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map) {
      return {
        for (final k in v.keys.cast<String>().toList()..sort())
          k: normalize(v[k]),
      };
    }
    if (v is List) return v.map(normalize).toList();
    if (v is double) {
      if (!v.isFinite || (v * 1000 - (v * 1000).round()).abs() > .000001) {
        throw const FormatException('INVALID_CANONICAL22');
      }
      return v == v.truncateToDouble() ? v.toInt() : v;
    }
    return v;
  }

  return jsonEncode(normalize(value));
}

String digest22(Object? v) =>
    sha256.convert(utf8.encode(canonical22(v))).toString();

String ratingKey22(Map t) =>
    '${t['type']}:${t['contentId']}:${t['ratingEpochId']}';

void verifyRatings22(Map head, Map snapshot) {
  if (head['schemaVersion'] != 22 ||
      snapshot['schemaVersion'] != 22 ||
      head['scope'] != 'ratings:public' ||
      snapshot['scope'] != head['scope'] ||
      head['ratingsRevision'] is! int ||
      head['ratingsRevision'] < 1 ||
      head['ratingsRevision'] != snapshot['ratingsRevision'] ||
      head['ratingsSnapshotHash'] != digest22(snapshot) ||
      head['policyHash'] != snapshot['policyHash'] ||
      snapshot['items'] is! List) {
    throw const FormatException('RATINGS_VERIFY_FAILED');
  }
  final keys = <String>{};
  for (final raw in snapshot['items'] as List) {
    final s = raw as Map, t = s['target'] as Map;
    if (!['COURSE', 'PROGRAM', 'MODULE', 'TRACK'].contains(t['type']) ||
        !keys.add(ratingKey22(t))) {
      throw const FormatException('RATING_TARGET');
    }
    for (final name in ['consumerDirect', 'professionalDirect']) {
      final c = s[name] as Map, n = c['n'];
      if (n is! int ||
          n < 0 ||
          n == 0 && c['mean'] != null ||
          n > 0 && (c['mean'] is! num || c['mean'] < 1 || c['mean'] > 5) ||
          c['distribution'] is! List ||
          (c['distribution'] as List).length != 5 ||
          (c['distribution'] as List).any((v) => v is! int || v < 0) ||
          (c['distribution'] as List).fold<int>(0, (a, b) => a + (b as int)) !=
              n) {
        throw const FormatException('RATING_COHORT');
      }
    }
    // No production coefficients are approved in22. Experimental scores never
    // enter a client-facing overlay, even if a malicious peer supplies a hash.
    if (s['weighted']?['status'] != 'NOT_CALIBRATED' ||
        s['weighted']?['value'] != null) {
      throw const FormatException('UNAPPROVED_WEIGHTED_RATING');
    }
  }
}

String directLabel22(Map? cohort) {
  if (cohort == null || cohort['n'] == 0 || cohort['mean'] == null) {
    return 'Нет оценок';
  }
  return '${(cohort['mean'] as num).toStringAsFixed(1).replaceAll('.', ',')} · N=${cohort['n']}${cohort['n'] == 1 ? ' · предварительно' : ''}';
}
