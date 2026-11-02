import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/library_service.dart';
import 'services/preview_player.dart';
import 'ui/library_screen.dart';

ThemeData sulfiTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFFD553AC),
    brightness: Brightness.dark,
    surface: const Color(0xFF111827),
    primary: const Color(0xFFE28BC8),
    secondary: const Color(0xFFC7F36B),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: const Color(0xFF090E1B),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF090E1B),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
  );
}

class SulfiApp extends StatelessWidget {
  const SulfiApp({super.key, required this.library, required this.player});
  final LibraryService library;
  final PreviewPlayer player;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Сульфи — гипнотерапевт',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: sulfiTheme(),
    home: LibraryScreen(library: library, player: player),
  );
}
