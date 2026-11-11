import 'package:flutter/material.dart';

import '../services/diary_controller.dart';
import '../services/alchemist_api.dart';
import '../models/session_plan.dart';
import 'design.dart';

/// Phone-side verification of real SDK identity and server authority. No token,
/// subject or third-party email is displayed or copied into diagnostic output.
class ServerAuthorizationScreen extends StatefulWidget {
  const ServerAuthorizationScreen({super.key, required this.diary});
  final DiaryController diary;
  @override
  State<ServerAuthorizationScreen> createState() =>
      _ServerAuthorizationScreenState();
}

class _ServerAuthorizationScreenState extends State<ServerAuthorizationScreen> {
  bool busy = false;
  String? error;
  Map<String, dynamic>? result;

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() => run(() async {
    final d = widget.diary, api = widget.diary.api!;
    if (!d.authenticated) {
      throw const FormatException('Сначала войдите через Google');
    }
    final response = await AlchemistApi(
      api.base,
      identityScope: () => api.readerScope,
      credential: api.verifiedIdentityToken,
    ).call('auth.verifyPilot', {'requestId': newId()});
    if (mounted) setState(() => result = response);
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.diary,
    builder: (context, _) {
      final d = widget.diary, role = d.api?.verifiedRole;
      final title = role == 'MASTER'
          ? 'Мастер'
          : role == 'CLIENT'
          ? 'Клиент'
          : 'Гость';
      return LeatherScaffold(
        title: 'Подключение и права',
        child: ListView(
          children: [
            Text(
              'Сервер Проекта Алхимик',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Роль, подтверждённая сервером: $title'),
            const SizedBox(height: 12),
            const Text(
              'Вход использует обычный Google Sign-In. Разрешение на ваш Google Диск приложению не требуется.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || d.authorBusy
                  ? null
                  : () => run(() async {
                      result = null;
                      if (d.authenticated) {
                        await d.logout();
                      } else {
                        await d.signInAuthor();
                      }
                    }),
              icon: Icon(d.authenticated ? Icons.logout : Icons.login),
              label: Text(
                d.authenticated ? 'Выйти из Google' : 'Войти через Google',
              ),
            ),
            if (d.error != null)
              Text(d.error!, style: const TextStyle(color: neonPink)),
            const SizedBox(height: 16),
            const Text(
              'Проверка прав создаёт и закрывает только собственную закрытую контрольную публикацию мастера. Для клиента проверяется отказ в публикации. Личные файлы и записи сохраняются. Проверка может занять несколько минут.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || !d.authenticated ? null : check,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Проверить права на сервере'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: neonPink)),
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  result!['masterPublicationVerified'] == true
                      ? 'Сервер подтвердил права мастера: контрольная публикация прошла и закрыта.'
                      : result!['clientPublicationDenied'] == true
                      ? 'Сервер подтвердил роль клиента и запрет публикации.'
                      : 'Проверка ещё не подтверждена сервером.',
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Результат проверки хранится на сервере без токенов. После проверки владельца повторите вход и проверку с другим Google-аккаунтом. Это не заменяет приёмку модуля на двух телефонах.',
            ),
          ],
        ),
      );
    },
  );
}
