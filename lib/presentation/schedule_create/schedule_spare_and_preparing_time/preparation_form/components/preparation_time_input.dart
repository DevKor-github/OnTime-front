import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class PreparationTimeInput extends StatelessWidget {
  const PreparationTimeInput({
    super.key,
    required this.time,
    required this.onPreparationTimeChanged,
    this.onTap,
    this.onDisposed,
    this.hasError = false,
  });

  final Duration time;
  final ValueChanged<Duration>? onPreparationTimeChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDisposed;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = time.inMinutes < 0 ? 0 : time.inMinutes;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        GestureDetector(
          child: Container(
            width: 50 * scale,
            height: 30 * scale,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: hasError
                  ? Border.all(color: colorScheme.error, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${minutes.toString().padLeft(2, '0')} ${l10n.localeName.startsWith('ko') ? '분' : 'min'}',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          onTap: () {
            onTap?.call();
            context.showCupertinoMinutePickerModal(
              title: l10n.selectTime,
              initialValue: time,
              onSaved: (value) {
                onPreparationTimeChanged?.call(value);
              },
              onDisposed: onDisposed,
            );
          },
        ),
      ],
    );
  }
}
