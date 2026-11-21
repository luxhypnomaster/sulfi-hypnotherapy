import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/vitrine_config.dart';

import 'support/task21_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final advanced in [false, true]) {
    test(
      '21 cold settings after lost commit response and applied refresh recover original receipt without new revision (concurrent=$advanced)',
      () async {
        final server = await Server21.open();
        addTearDown(server.close);
        final app = await App21.open(server);
        try {
          final runtime = app.c.metadata!;
          await runtime.gateway.negotiate();
          final settings = runtime.settings;
          await settings.save(const VitrineConfig(entrySeconds: 13));
          await server.call('control.mode', {'mode': 'lostConfigOnce'});
          await expectLater(settings.publish(), throwsA(isA<Exception>()));
          final unknown = await settings.load();
          expect(unknown['published'], null);
          if (advanced) {
            final prepared = await server.call('vitrine.configPrepare', {
              'scope': 'master:public',
              'requestId': 'another_prepare',
              'expectedRevision': 1,
              'config': const VitrineConfig(entrySeconds: 15).toMap(),
            });
            await server.call('vitrine.configCommit', {
              'scope': 'master:public',
              'requestId': 'another_commit',
              'prepareId': prepared['prepareId'],
            });
          }
          final current = advanced ? 2 : 1;
          final cold = runtime.settings;
          await cold.refreshApplied();
          expect((await cold.load())['appliedRevision'], current);
          await cold.publish();
          final recovered = await cold.load();
          expect(recovered['requestId'], unknown['requestId']);
          expect(recovered['publishedRevision'], 1);
          expect(recovered['receipt']['requestId'], unknown['requestId']);
          expect(
            (await server.call(
              'control.state',
              {},
            ))['configHead']['configRevision'],
            current,
          );
          expect(recovered['appliedRevision'], current);
          if (!advanced) await cold.publish();
          expect(
            (await server.call(
              'control.state',
              {},
            ))['configHead']['configRevision'],
            current,
          );
        } finally {
          await app.close();
        }
      },
    );
  }
}
