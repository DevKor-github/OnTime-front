import 'package:flutter/material.dart';

class CreateIconButton extends StatelessWidget {
  const CreateIconButton({
    super.key,
    required this.onCreationRequested,
  });

  final VoidCallback onCreationRequested;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      style: ButtonStyle(
        backgroundColor:
            WidgetStateProperty.all<Color>(colorScheme.surfaceContainerHigh),
      ),
      onPressed: () {
        onCreationRequested();
      },
      color: colorScheme.onPrimary,
      icon: Icon(Icons.add),
      padding: EdgeInsets.zero,
      iconSize: 30.0,
    );
  }
}
