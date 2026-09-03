import 'package:flutter/material.dart';

/// Dialog yang lebar/tingginya mengikuti isi, dibatasi ukuran layar.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;

  static BoxConstraints batas(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return BoxConstraints(
      maxWidth: size.width - 48,
      maxHeight: size.height - 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: title,
      content: content,
      actions: actions,
      titlePadding: titlePadding,
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: batas(context),
    );
  }
}
