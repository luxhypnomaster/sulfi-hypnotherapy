import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/diary_layout.dart';

TextSpan diaryHeading(DiaryEntry e) => TextSpan(
  children: [
    TextSpan(
      text:
          'Запись ${e.number == null ? e.id : '№${e.number}'}\n${diaryDate(e.publishedAt ?? e.createdAt)}\n\n',
      style: const TextStyle(fontSize: 12, color: Color(0xFF5C4232)),
    ),
    TextSpan(
      text: '${e.message}\n\n',
      style: const TextStyle(
        color: Color(0xFFC00C71),
        fontWeight: FontWeight.w700,
      ),
    ),
  ],
);

/// Fits actual Flutter typography to the reader's available paper rectangle.
/// Cuts on grapheme boundaries and preserves every character of the body.
List<String> paginateDiary(
  DiaryEntry e,
  double width,
  double height,
  TextScaler scaler,
  TextStyle style,
) {
  final characters = e.body.characters.toList();
  final pages = <String>[];
  var start = 0;
  do {
    var low = start, high = characters.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final span = TextSpan(
        style: style,
        children: [
          if (pages.isEmpty) diaryHeading(e),
          TextSpan(text: characters.sublist(start, mid).join()),
        ],
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final fits = painter.height <= height;
      painter.dispose();
      if (fits) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    // For very large fonts a heading can fill a page; put body on page two.
    if (low == start && pages.isEmpty) {
      pages.add('');
      continue;
    }
    if (low == start) low = math.min(start + 1, characters.length);
    for (var cut = low; cut > math.max(start + 1, low - 60); cut--) {
      if (characters[cut - 1].trim().isEmpty) {
        low = cut;
        break;
      }
    }
    pages.add(characters.sublist(start, low).join());
    start = low;
  } while (start < characters.length);
  return pages;
}
