import 'package:flutter/material.dart';

enum AppSnackBarTone { merah, hijau, kuning }

void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppSnackBarTone warna = AppSnackBarTone.merah,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final bg = switch (warna) {
    AppSnackBarTone.merah => Colors.red,
    AppSnackBarTone.hijau => Colors.green,
    AppSnackBarTone.kuning => Colors.yellow.shade700,
  };
  final fg = warna == AppSnackBarTone.kuning ? Colors.black : Colors.white;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(fontWeight: FontWeight.bold, color: fg),
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}
