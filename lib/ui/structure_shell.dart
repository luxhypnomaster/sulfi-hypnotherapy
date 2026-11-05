import 'package:flutter/material.dart';

import 'design.dart';

/// Full usable width. Footer is outside the only scrolling surface.
class StructureShell extends StatelessWidget {
  const StructureShell({
    super.key,
    required this.title,
    required this.onBack,
    required this.summary,
    required this.child,
    required this.footer,
  });
  final String title;
  final VoidCallback onBack;
  final Widget summary, child, footer;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF14030D),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
        child: footer,
      ),
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF260416), Color(0xFF0E0209)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12, top: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: neonPink),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 23,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: neonLime,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 55, right: 16, top: 2),
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [neonLime, neonLime.withValues(alpha: 0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: neonLime.withValues(alpha: .25),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 12, 8),
              child: summary,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class StructureFooterButton extends StatelessWidget {
  const StructureFooterButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.add = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary, add;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: SizedBox(
      height: MediaQuery.textScalerOf(context).scale(16) > 24 ? 72 : 58,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: primary
              ? neonLime
              : add
              ? Colors.black
              : const Color(0xFF250719),
          foregroundColor: primary
              ? ink
              : add
              ? neonLime
              : const Color(0xFFF8EBF3),
          side: BorderSide(
            color: primary || add ? neonLime : neonPink,
            width: 1.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: label.contains('\n') ? 2 : 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    ),
  );
}
