import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class CreateIconButton extends StatelessWidget {
  const CreateIconButton({super.key, required this.onCreationRequested});

  final VoidCallback onCreationRequested;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)?.addPreparationStep,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: onCreationRequested,
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.grey[250],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.add, size: 24, color: AppColors.grey.shade700),
      ),
    );
  }
}
