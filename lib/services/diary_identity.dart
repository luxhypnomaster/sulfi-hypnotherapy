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

/// Optional official SDK restoration, not an invented refresh-token endpoint.
abstract interface class RestorableDiaryIdentity {
  Future<DiaryIdentityResult?> restore();
}

class GoogleDiaryIdentity implements DiaryIdentity, RestorableDiaryIdentity {
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
      // Explicit account choice. Do not sign out another in-flight SDK session.
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
      throw DiaryApiException(
        'Не удалось войти через Google. Код SDK: ${e.code.name}. Проверьте сеть и настройку этой сборки.',
      );
    }
  }

  @override
  Future<DiaryIdentityResult?> restore() async {
    try {
      await _initialize();
      final pending = GoogleSignIn.instance.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      final account = pending == null ? null : await pending;
      final token = account?.authentication.idToken;
      if (account == null || token == null || token.isEmpty) return null;
      return DiaryIdentityResult(email: account.email, idToken: token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      throw DiaryApiException(
        'Не удалось восстановить вход Google. Код SDK: ${e.code.name}.',
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
