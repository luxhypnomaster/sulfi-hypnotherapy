import '../models/diary_publication.dart' show diaryEntryLabel;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';

const diaryTextStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  fontSize: 16,
  height: 1.35,
  letterSpacing: 0,
  color: Color(0xFFF8EDF2),
);
const diaryTitleStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  fontSize: 21,
  height: 1.2,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w700,
  color: Color(0xFFFFEDF7),
);
const diaryMessageStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  fontSize: 17,
  height: 1.25,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w700,
  color: Color(0xFFFF168F),
);
const diaryMetaStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  fontSize: 12,
  height: 1.3,
  color: Color(0xFFA6FF2E),
);
String diaryDate(DateTime date) {
  final d = date.toLocal();
  const days = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  String n(int v) => v.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]}, ${n(d.day)}.${n(d.month)}.${d.year} · ${n(d.hour)}:${n(d.minute)}';
}

String diaryMeta(DiaryEntry e) =>
    '${diaryEntryLabel(e)} · ${diaryDate(e.createdAt)}';
double diaryMeasure(
  String text,
  double width,
  TextScaler scaler,
  TextStyle style,
) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    locale: const Locale('ru'),
  )..layout(maxWidth: math.max(1, width));
  final height = p.height;
  p.dispose();
  return height;
}

class DiaryHeaderSize {
  DiaryHeaderSize(DiaryEntry e, double w, TextScaler s)
    : meta = diaryMeasure(diaryMeta(e), w, s, diaryMetaStyle),
      title = diaryMeasure(e.displayTitle, w - 20, s, diaryTitleStyle),
      message = diaryMeasure(e.message, w - 24, s, diaryMessageStyle);
  final double meta, title, message;
  double get height => meta + title + message + 78;
}

class DiaryFragment {
  const DiaryFragment(
    this.block, {
    this.text,
    this.offset = 0,
    this.end = 0,
    required this.height,
  });
  final DiaryBlock block;
  final String? text;
  final int offset, end;
  final double height;
}

class DiaryPageLayout {
  DiaryPageLayout(this.fragments);
  final List<DiaryFragment> fragments;
}

class DiaryAnchor {
  const DiaryAnchor(this.blockId, this.offset);
  final String blockId;
  final int offset;
}

class DiaryLayout {
  DiaryLayout(this.pages, this.header);
  final List<DiaryPageLayout> pages;
  final DiaryHeaderSize header;
  int pageFor(DiaryAnchor? anchor) {
    if (anchor == null) return 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].fragments.any(
        (f) =>
            f.block.id == anchor.blockId &&
            (f.text == null ||
                (anchor.offset >= f.offset && anchor.offset < f.end)),
      )) {
        return i;
      }
    }
    return 0;
  }
}

/// Every fragment uses precisely the same styles, widths and heights as reader.
/// Media stays atomic; text offsets are UTF-16 boundaries of whole graphemes.
Future<DiaryLayout> layoutDiary(
  DiaryEntry e,
  double width,
  double height,
  TextScaler scaler,
) async {
  final w = math.max(1.0, width), h = math.max(1.0, height);
  final header = DiaryHeaderSize(e, w, scaler);
  final pages = <DiaryPageLayout>[DiaryPageLayout([])];
  var remaining = h - header.height;
  void next() {
    pages.add(DiaryPageLayout([]));
    remaining = h;
  }

  for (final block in e.blocks) {
    if (block.type != DiaryBlockType.text) {
      final double caption = block.caption.isEmpty
          ? 0
          : diaryMeasure(block.caption, w - 16, scaler, diaryMetaStyle) + 8;
      final double target = block.type == DiaryBlockType.audio
          ? math.max(112.0, scaler.scale(16) * 4 + 48)
          : math.min(h * .65, w * (block.height ?? 1) / (block.width ?? 1)) +
                caption;
      if (target > remaining &&
          (pages.last.fragments.isNotEmpty || pages.length == 1)) {
        next();
      }
      final size = block.type == DiaryBlockType.image
          ? math.max(caption + 48, math.min(target, h))
          : target;
      pages.last.fragments.add(DiaryFragment(block, height: size));
      remaining -= size + 12;
      continue;
    }
    final chars = block.text.characters.toList();
    var start = 0, codeOffset = 0;
    while (start < chars.length) {
      if (remaining < scaler.scale(16) * 1.35 &&
          (pages.last.fragments.isNotEmpty || pages.length == 1)) {
        next();
      }
      final estimate = math.max(512, (w / 8 * h / 20 * 4).ceil());
      var low = start, high = math.min(chars.length, start + estimate);
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        if (diaryMeasure(
              chars.sublist(start, mid).join(),
              w,
              scaler,
              diaryTextStyle,
            ) <=
            remaining) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      if (low == start) {
        if (pages.last.fragments.isNotEmpty || pages.length == 1) {
          next();
          continue;
        }
        low =
            start +
            1; // Extreme accessibility: a scrollable page, guaranteed progress.
      } else if (low < chars.length) {
        // Prefer paragraph boundaries in the final third, then whitespace.
        var boundary = -1;
        for (var i = low; i > start + (low - start) * 2 ~/ 3; i--) {
          if (chars[i - 1] == '\n') {
            boundary = i;
            break;
          }
        }
        if (boundary < 0) {
          for (var i = low; i > math.max(start, low - 40); i--) {
            if (chars[i - 1].trim().isEmpty) {
              boundary = i;
              break;
            }
          }
        }
        if (boundary > start) low = boundary;
      }
      final text = chars.sublist(start, low).join();
      final size = diaryMeasure(text, w, scaler, diaryTextStyle);
      pages.last.fragments.add(
        DiaryFragment(
          block,
          text: text,
          offset: codeOffset,
          end: codeOffset + text.length,
          height: size,
        ),
      );
      codeOffset += text.length;
      start = low;
      remaining -= size;
      if (start < chars.length) next();
      if (pages.length % 10 == 0) await Future<void>.delayed(Duration.zero);
    }
    remaining -= 12;
  }
  return DiaryLayout(pages, header);
}
