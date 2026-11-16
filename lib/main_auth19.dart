import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth19/auth_coordinator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Auth19Screen()));
}

/// Isolated diagnostic entrypoint. Never initializes the real library or queue.
class Auth19Screen extends StatefulWidget {
  const Auth19Screen({super.key});
  @override
  State<Auth19Screen> createState() => _Auth19ScreenState();
}

class _Auth19ScreenState extends State<Auth19Screen> {
  final auth = AuthCoordinator();
  StreamSubscription<Auth19Snapshot>? subscription;
  String notice = '';
  @override
  void initState() {
    super.initState();
    subscription = auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    }, onError: (Object _) {});
    unawaited(
      auth.initialize(
        projectRef: const String.fromEnvironment('SULFI_AUTH19_PROJECT_REF'),
        publishableKey: const String.fromEnvironment(
          'SULFI_AUTH19_PUBLISHABLE_KEY',
        ),
      ),
    );
  }

  Future<void> login({bool switchAccount = false}) async {
    try {
      final uri = await auth.beginGoogleSignIn(switchAccount: switchAccount);
      if (uri != null &&
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('browser');
      }
    } catch (_) {
      if (mounted) {
        setState(() => notice = 'Вход не запущен. Проверьте OWNER_SETUP_19.');
      }
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    unawaited(auth.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Auth19 · изолированный прототип')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(auth.enabled ? 'Тестовый профиль .auth19' : 'Feature flag OFF'),
          Text('Состояние: ${auth.snapshot.state.name}'),
          Text(auth.snapshot.code),
          const Text(
            'Роли MASTER и доступ к GAS не подключены. Личная библиотека не открывается.',
          ),
          FilledButton(
            onPressed: auth.enabled ? login : null,
            child: const Text('Войти через Google'),
          ),
          TextButton(
            onPressed: auth.enabled ? () => login(switchAccount: true) : null,
            child: const Text('Сменить тестовый аккаунт'),
          ),
          TextButton(
            onPressed: auth.enabled ? auth.restore : null,
            child: const Text('Проверить сессию без выбора аккаунта'),
          ),
          TextButton(
            onPressed: auth.enabled ? auth.logout : null,
            child: const Text('Локальный выход'),
          ),
          TextButton(
            onPressed: auth.enabled ? auth.cancelLogin : null,
            child: const Text('Отменить незавершённый вход'),
          ),
          Text(notice),
        ],
      ),
    ),
  );
}
