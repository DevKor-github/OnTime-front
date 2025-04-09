import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class ModalComponent extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const ModalComponent({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: AlertDialog(
        shape: appTheme.dialogTheme.shape,
        backgroundColor: appTheme.dialogTheme.backgroundColor,
        title: title,
        titleTextStyle: appTheme.dialogTheme.titleTextStyle,
        content: content,
        contentTextStyle: appTheme.dialogTheme.contentTextStyle,
        actions: actions,
        actionsAlignment: MainAxisAlignment.spaceEvenly,
      ),
    );
  }
}
