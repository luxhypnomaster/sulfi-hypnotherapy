import 'package:google_sign_in/google_sign_in.dart';

import 'diary_api.dart';

/// The SDK authenticates the account; the server independently verifies its JWT.
/// Neither passwords nor manually copied credentials are accepted by the UI.
class DiaryIdentityResult {
  const DiaryIdentityResult({required this.email, required this.idToken});
  final String email, idToken;
}

abstract interface class DiaryIdentity {
  Future<DiaryIdentityResult> signIn();
  Future<void> signOut();
}

class GoogleDiaryIdentity implements DiaryIdentity {
  GoogleDiaryIdentity({required this.serverClientId});
  final String serverClientId;
  Future<void>? _initialization;

  Future<void> _initialize() {
    if (!RegExp(r'^[\w-]+\.apps\.googleusercontent\.com$')
        .hasMatch(serverClientId)) {
      throw const DiaryApiException(
        'Вход Google ещё не настроен в этой сборке. Чтение дневника доступно без входа.',
      );
    }
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
  }

  @override
  Future<DiaryIdentityResult> signIn() async {
    try {
      await _initialize();
      // Authentication tokens are snapshots, not refreshable access tokens.
      // Reauthenticate only on explicit author actions, never when reading.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const DiaryApiException(
          'Google не подтвердил вход. Повторите попытку.',
        );
      }
      return DiaryIdentityResult(email: account.email, idToken: token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const DiaryApiException('Вход отменён.');
      }
      // SDK exception details can contain sensitive provider diagnostics.
      throw const DiaryApiException(
        'Не удалось войти через Google. Проверьте сеть и настройку этой сборки.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialization != null) {
      await _initialization;
      await GoogleSignIn.instance.signOut();
    }
  }
}
