import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingConfig {
  static const telegram = String.fromEnvironment(
    'BOOKING_TELEGRAM_URL',
    defaultValue: 'https://t.me/LuchikLuxxx',
  );
  static const email = String.fromEnvironment(
    'BOOKING_EMAIL',
    defaultValue: 'luxhypnomaster@gmail.com',
  );
  static const enabled = bool.fromEnvironment(
    'BOOKING_ENABLED',
    defaultValue: true,
  );
  static const label = 'Записаться к мастеру';
}

Future<void> showBooking(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text(BookingConfig.label),
    children: [
      if (BookingConfig.enabled && BookingConfig.telegram.isNotEmpty)
        SimpleDialogOption(
          child: const Text('Telegram'),
          onPressed: () async {
            final uri = Uri.tryParse(BookingConfig.telegram);
            if (uri == null ||
                uri.scheme != 'https' ||
                !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              if (context.mounted) {
                await Clipboard.setData(
                  const ClipboardData(text: BookingConfig.telegram),
                );
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована.')),
                );
              }
            }
          },
        ),
      if (BookingConfig.enabled && BookingConfig.email.isNotEmpty)
        SimpleDialogOption(
          child: const Text('Электронная почта'),
          onPressed: () async {
            if (!await launchUrl(
              Uri(
                scheme: 'mailto',
                path: BookingConfig.email,
                queryParameters: {'subject': 'Запись на консультацию'},
              ),
              mode: LaunchMode.externalApplication,
            )) {
              await Clipboard.setData(
                const ClipboardData(text: BookingConfig.email),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Адрес скопирован: ${BookingConfig.email}'),
                  ),
                );
              }
            }
          },
        ),
      if (!BookingConfig.enabled ||
          BookingConfig.telegram.isEmpty && BookingConfig.email.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Контакты пока не настроены.'),
        ),
      if (BookingConfig.email.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Email пока не указан.'),
        ),
    ],
  ),
);
