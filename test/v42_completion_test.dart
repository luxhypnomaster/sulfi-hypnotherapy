import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/ui/run_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_screen.dart';

import 'support/fakes.dart';
import 'support/session_transport_fake.dart';
import 'v41_player_test.dart' show Fixture;

void main() {
  Future<void> drain(WidgetTester t) async {
    await t.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await t.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
  }

  for (final early in [true, false]) {
    testWidgets(
      early
          ? 'L08: confirmed stop opens history highlighting saved Interrupted run'
          : 'L09: natural finish opens history with Completed run and actual events',
      (t) async {
        final f = (await t.runAsync(
          () => Fixture.create(workTracks: 1, exit: false),
        ))!;
        await t.runAsync(f.engine.interrupt);
        await t.runAsync(f.controller.reload);
        final transport = TestTransport();
        t.view.physicalSize = const Size(412, 915);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          SulfiApp(
            library: f.controller.library,
            player: MemoryPlayer(),
            controller: f.controller,
            transportFactory: () => transport,
          ),
        );
        await drain(t);
        await t.tap(find.text('НАЧАТЬ ТРАНСФОРМАЦИЮ'));
        await drain(t);
        final engine = t.widget<RunScreen>(find.byType(RunScreen)).engine;
        final runId = engine.run!.id;
        if (early) {
          await t.tap(find.text('Закончить сеанс'));
          await drain(t);
          await t.tap(find.text('Закончить сейчас'));
          await drain(t);
        } else {
          for (var i = 0; i < 10 && engine.active; i++) {
            transport.completed = true;
            await t.runAsync(() async {
              engine.tick();
              await engine.flush();
            });
            await drain(t);
          }
        }
        expect(find.byType(HistoryScreen), findsOneWidget);
        expect(find.byKey(ValueKey('history-$runId')), findsOneWidget);
        final run = f.controller.runs.firstWhere((r) => r.id == runId);
        expect(run.status, early ? RunStatus.interrupted : RunStatus.completed);
        expect(
          run.completedStepIds.length,
          early ? 0 : run.snapshot.plan.steps.length,
        );
        expect(
          run.snapshot.plan.fingerprint,
          engine.run!.snapshot.plan.fingerprint,
        );
        await t.pumpWidget(const SizedBox());
        await t.runAsync(f.close);
      },
    );
  }
}
