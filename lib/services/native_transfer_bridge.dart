import 'dart:io';

import 'package:flutter/services.dart';

import 'alchemist_api.dart';
import 'alchemist_diary_api.dart';
import 'alchemist_errors.dart';
import 'diary_api.dart';

/// Small platform authority bridge. No task payload/receipt is duplicated here.
class NativeTransferBridge {
  static const channel = MethodChannel('ru.sulfi/transfers18');
  static bool get available => Platform.isAndroid;

  static Future<void> authorize(
    AlchemistApi api,
    DiaryApi? identity, {
    String networkPolicy = 'any',
  }) async {
    final scope = api.currentIdentityScope ?? 'public';
    final public = scope == 'public';
    String? token;
    if (!public) {
      if (identity is! AlchemistDiaryApi) {
        throw const FormatException('Google-сессия недоступна');
      }
      token = await identity.verifiedIdentityToken();
      if (scope != identity.readerScope) {
        throw const AlchemistFailure(
          'Аккаунт изменился.',
          401,
          'ACCOUNT_CHANGED',
        );
      }
    }
    await channel.invokeMethod('authorize', {
      'endpoint': api.endpoint.toString(),
      'scope': scope,
      'ownerBinding': public ? 'public' : api.ownerBinding,
      'role': public ? 'PUBLIC' : identity!.verifiedRole,
      'expiresAt': public
          ? DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch
          : identity!.identityExpiresAt!.millisecondsSinceEpoch,
      'token': token,
      'networkPolicy': networkPolicy,
    });
  }

  static Future<void> start() async {
    final state = await channel.invokeMethod<String>('start');
    if (state == 'WAITING_POLICY') {
      throw const AlchemistFailure(
        'Android отложил передачу. Задача сохранена в очереди.',
        0,
        'WAITING_POLICY',
      );
    }
  }

  static Future<void> revoke() async {
    if (available) await channel.invokeMethod('revoke');
  }

  static Future<void> control(String name, String action, String owner) async {
    await channel.invokeMethod('control', {
      'name': name,
      'action': action,
      'ownerBinding': owner,
    });
  }
}
