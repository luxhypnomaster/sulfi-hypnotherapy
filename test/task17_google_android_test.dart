// SDK Dart boundary, not real Google or physical Android authentication.
import 'package:flutter_test/flutter_test.dart';
// The transitive packages are intentionally the pinned Android SDK under test.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_android/google_sign_in_android.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_android/src/messages.g.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class CredentialBoundary extends GoogleSignInApi {
  final requests = <GetCredentialRequestParams>[];
  @override
  Future<GetCredentialResult> getCredential(
    GetCredentialRequestParams params,
  ) async {
    requests.add(params);
    return GetCredentialFailure(type: GetCredentialFailureType.noCredential);
  }
}

void main() {
  test('17 SDK automatic recovery never falls back to unapproved accounts; explicit button remains separate', () async {
    final boundary = CredentialBoundary();
    final sdk = GoogleSignInAndroid(api: boundary);
    await sdk.init(
      const InitParameters(serverClientId: 'controlled-public-id'),
    );
    expect(
      await sdk.attemptLightweightAuthentication(
        const AttemptLightweightAuthenticationParameters(),
      ),
      isNull,
    );
    expect(boundary.requests, hasLength(1));
    final automatic = boundary.requests.single;
    expect(automatic.useButtonFlow, false);
    expect(automatic.googleIdOptionParams.filterToAuthorized, true);
    expect(automatic.googleIdOptionParams.autoSelectEnabled, true);
    await expectLater(
      sdk.authenticate(const AuthenticateParameters()),
      throwsA(isA<GoogleSignInException>()),
    );
    expect(boundary.requests, hasLength(2));
    expect(boundary.requests.last.useButtonFlow, true);
  });
}
