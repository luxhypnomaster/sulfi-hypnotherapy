import 'dart:async';
import 'dart:io';

import 'diary_api.dart';

/// Public, bounded error information. Never serialize an SDK/socket exception.
class AlchemistFailure extends DiaryApiException {
  const AlchemistFailure(
    super.message,
    this.status,
    this.code, [
    super.kind = DiaryFailure.network,
    this.retryable = false,
  ]);
  final int status;
  final String code;
  final bool retryable;

  static AlchemistFailure from(Object error) {
    if (error is AlchemistFailure) return error;
    if (error is SocketException) {
      return const AlchemistFailure(
        'Сеть или DNS недоступны. Данные сохранены; повторите после подключения.',
        0,
        'NETWORK_DNS_OR_SOCKET',
        DiaryFailure.network,
        true,
      );
    }
    if (error is HttpException) {
      return const AlchemistFailure(
        'Соединение оборвалось. Подтверждённый прогресс сохранён.',
        0,
        'NETWORK_CONNECTION_ABORT',
        DiaryFailure.network,
        true,
      );
    }
    if (error is TimeoutException) {
      return const AlchemistFailure(
        'Сервер не ответил вовремя. Результат будет сверен при повторе.',
        0,
        'NETWORK_TIMEOUT',
        DiaryFailure.network,
        true,
      );
    }
    if (error is DiaryApiException &&
        error.kind == DiaryFailure.authorization) {
      return AlchemistFailure(error.message, 401, 'AUTH_REQUIRED', error.kind);
    }
    return const AlchemistFailure(
      'Не удалось завершить операцию. Черновик и исходные файлы сохранены.',
      0,
      'LOCAL_OPERATION_FAILED',
      DiaryFailure.invalidData,
    );
  }

  static AlchemistFailure server(int status, String code) {
    if (status == 401) {
      return AlchemistFailure(
        code == 'TOKEN_AUDIENCE_INVALID'
            ? 'Google-вход не соответствует настройке сервера. Код: TOKEN_AUDIENCE_INVALID.'
            : code == 'IDENTITY_REVOKED'
            ? 'Доступ аккаунта отозван сервером. Нужна проверка владельцем.'
            : 'Нужно подтвердить Google-вход. Черновики и переданные части сохранены.',
        status,
        code,
        DiaryFailure.authorization,
      );
    }
    if (status == 403) {
      return AlchemistFailure(
        'Сервер не разрешил это действие для вашей роли.',
        status,
        code,
        DiaryFailure.blocked,
      );
    }
    if (status == 409 || status == 412) {
      return AlchemistFailure(
        'Версия на сервере изменилась. Сверьте изменения перед повтором.',
        status,
        code,
        DiaryFailure.conflict,
      );
    }
    return AlchemistFailure(
      status == 429
          ? 'Достигнут лимит запросов. Передача приостановлена; повторите позже.'
          : 'Сервер временно недоступен. Данные и прогресс сохранены.',
      status,
      code,
      DiaryFailure.network,
      status == 429 || status >= 500,
    );
  }
}
