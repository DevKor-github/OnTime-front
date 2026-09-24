import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onNextPageButtonClicked,
    required this.onPreviousPageButtonClicked,
    required this.isNextButtonEnabled,
    this.title,
    this.actionLabel,
    this.showAction = true,
  });

  final void Function()? onNextPageButtonClicked;
  final void Function()? onPreviousPageButtonClicked;
  final String? title;
  final String? actionLabel;
  final bool showAction;
  final bool isNextButtonEnabled; // 버튼 활성화 여부

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 18,
            color: colorScheme.outlineVariant,
          ),
          onPressed: onPreviousPageButtonClicked,
        ),
        Expanded(
          child: Center(
            child: Text(
              title ?? AppLocalizations.of(context)!.addAppointment,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: showAction ? 20 : 18),
            ),
          ),
        ),
        // 다음 페이지 버튼
        // 버튼 활성화 여부에 따라 색상 변화 추후 추가 가능
        if (!showAction)
          const SizedBox(width: 48)
        else
          TextButton(
            onPressed: isNextButtonEnabled ? onNextPageButtonClicked : null,
            child: Text(actionLabel ?? AppLocalizations.of(context)!.next),
          ),
      ],
    );
  }
}
