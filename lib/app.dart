import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/library_service.dart';
import 'services/preview_player.dart';
import 'services/session_controller.dart';
import 'services/session_transport.dart';
import 'ui/home_screen.dart';
import 'ui/design.dart';

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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF22101B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
  );
}

class SulfiApp extends StatelessWidget {
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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Сульфи — гипнотерапевт',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: sulfiTheme(),
    home: HomeScreen(
      controller: controller,
      player: player,
      transportFactory: transportFactory,
    ),
  );
}
