import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/ui/session_scope.dart';

import 'task15_fixture.dart';

bool _fonts = false;
Future<void> io15(WidgetTester t) async {
  for (var i = 0; i < 32; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 8)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}

Future<void> show15(
  WidgetTester t,
  Fixture15 f,
  Widget page, {
  Size size = const Size(412, 915),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(top: 24, bottom: 20);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  if (!_fonts) {
    final sdk = File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent;
    for (final font in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = (await t.runAsync(
        () =>
            File('${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
                .readAsBytes(),
      ))!;
      await (FontLoader(
        font.$1,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    _fonts = true;
  }
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: sulfiTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => SessionScope(
        controller: f.c,
        player: f.player,
        child: RepaintBoundary(
          key: const Key('task15-capture'),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
      home: page,
    ),
  );
  await io15(t);
}

Future<void> capture15(WidgetTester t, String name) async {
  const output = String.fromEnvironment('SULFI_TASK15_SCREENSHOTS');
  if (output.isEmpty) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('task15-capture')),
  );
  void repaint(RenderObject n) {
    n.visitChildren(repaint);
    n.markNeedsPaint();
  }

  repaint(boundary);
  await t.pump();
  await t.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}
