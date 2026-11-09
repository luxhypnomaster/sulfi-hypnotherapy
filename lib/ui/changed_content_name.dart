import 'package:flutter/material.dart';

/// Presentation-only marker, never part of a stored title or fingerprint.
class ChangedContentName extends StatelessWidget {
  const ChangedContentName({
    super.key,
    required this.title,
    required this.changed,
    required this.style,
    this.markerKey,
    this.maxLines = 2,
  });
  final String title;
  final bool changed;
  final TextStyle style;
  final Key? markerKey;
  final int? maxLines;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    children: [
      Text(
        title,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
      ),
      if (changed)
        Text(
          '(Изменено)',
          key: markerKey,
          style: TextStyle(
            color: const Color(0xFFFFE66A),
            fontSize: style.fontSize,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );
}
