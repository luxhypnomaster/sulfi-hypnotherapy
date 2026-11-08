import 'package:flutter/services.dart';

/// SAF transfers paths, never multi-gigabyte byte arrays over the platform channel.
class DeviceFiles {
  static const channel = MethodChannel('ru.sulfi/device_files');
  static Future<bool> save(String path) async =>
      await channel.invokeMethod<bool>('saveZip', {'path': path}) ?? false;
  static Future<String?> open() => channel.invokeMethod<String>('openZip');
  static Future<int> freeBytes() async =>
      (await channel.invokeMethod<num>('freeBytes'))!.toInt();
  static Future<Map<String, dynamic>> diagnostics() async =>
      Map<String, dynamic>.from(
        (await channel.invokeMapMethod('diagnostics'))!,
      );
  static Future<void> keepAwake(bool enabled) async {
    try {
      await channel.invokeMethod('keepAwake', enabled);
    } on MissingPluginException {
      /* Widget tests have no Android window. */
    }
  }
}
