import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

void main() {
  const edition = String.fromEnvironment('SULFI_EDITION');
  test(
    'build configuration fixes CLIENT independently of mutable settings',
    () async {
      final policy = AccessPolicy();
      if (edition == 'client') {
        expect(policy.clientEdition, isTrue);
        expect(policy.mode, LocalMode.client);
        await expectLater(
          policy.setMode(LocalMode.author),
          throwsA(isA<LibraryException>()),
        );
        expect(policy.mode, LocalMode.client);
      } else {
        expect(policy.clientEdition, isFalse);
        expect(policy.mode, LocalMode.author);
        await policy.setMode(LocalMode.client);
        expect(policy.mode, LocalMode.client);
      }
      policy.dispose();
    },
  );
}
