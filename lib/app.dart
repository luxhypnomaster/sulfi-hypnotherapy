import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/library_service.dart';
import 'services/preview_player.dart';
import 'services/session_controller.dart';
import 'services/session_transport.dart';
import 'ui/home_screen.dart';
import 'ui/design.dart';
import 'ui/session_scope.dart';
import 'ui/preview_bar.dart';

ThemeData sulfiTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: neonPink,
    brightness: Brightness.dark,
    surface: const Color(0xFF1B0C17),
    primary: neonPink,
    secondary: neonLime,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: ink,
    appBarTheme: const AppBarTheme(backgroundColor: ink, centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF180A13),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: const BorderSide(color: Color(0xFF762047)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF762047)),
        borderRadius: BorderRadius.circular(8),
      ),
      fillColor: const Color(0xFF22101B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
  );
}

class SulfiApp extends StatefulWidget {
  const SulfiApp({
    super.key,
    required this.library,
    required this.player,
    required this.controller,
    this.transportFactory,
  });
  final LibraryService library;
  final PreviewPlayer player;
  final SessionController controller;
  final SessionTransport Function()? transportFactory;

  @override
  State<SulfiApp> createState() => _SulfiAppState();
}

class _SulfiAppState extends State<SulfiApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  LibraryService get library => widget.library;
  PreviewPlayer get player => widget.player;
  SessionController get controller => widget.controller;
  SessionTransport Function()? get transportFactory => widget.transportFactory;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    title: 'Сульфи — Самогипноз',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: sulfiTheme(),
    builder: (context, child) => _PreviewOverlay(
      child: SessionScope(
        controller: controller,
        player: player,
        child: GlobalPreviewScope(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final active =
                  player.current != null &&
                  player.current?.id != 'unsaved-take';
              final inset = active
                  ? MediaQuery.viewInsetsOf(context).bottom
                  : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: Column(
                  children: [
                    Expanded(
                      child: active
                          ? MediaQuery.removeViewInsets(
                              context: context,
                              removeBottom: true,
                              child: child!,
                            )
                          : child!,
                    ),
                    if (active)
                      SafeArea(
                        top: false,
                        child: PreviewBar(
                          key: const Key('global-preview-bar'),
                          player: player,
                          library: library,
                          compact: true,
                          global: true,
                          navigatorKey: navigatorKey,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
    home: HomeScreen(
      controller: controller,
      player: player,
      transportFactory: transportFactory,
    ),
  );
}

class _PreviewOverlay extends StatefulWidget {
  const _PreviewOverlay({required this.child});
  final Widget child;
  @override
  State<_PreviewOverlay> createState() => _PreviewOverlayState();
}

class _PreviewOverlayState extends State<_PreviewOverlay> {
  late final entry = OverlayEntry(
    builder: (_) =>
        Material(type: MaterialType.transparency, child: widget.child),
  );
  @override
  void didUpdateWidget(_PreviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [entry]);
  @override
  void dispose() {
    entry.remove();
    entry.dispose();
    super.dispose();
  }
}
