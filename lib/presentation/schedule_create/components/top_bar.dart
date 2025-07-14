import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onNextPageButtonClicked,
    required this.onPreviousPageButtonClicked,
    required this.isNextButtonEnabled,
  });

  final void Function()? onNextPageButtonClicked;
  final void Function() onPreviousPageButtonClicked;
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
            color: colorScheme.outlineVariant,
          ),
          onPressed: () {
            onPreviousPageButtonClicked();
          },
        ),
        Expanded(
          child: Center(
              child: Text(AppLocalizations.of(context)!.addAppointment,
                  style: Theme.of(context).textTheme.titleLarge)),
        ),
        // 다음 페이지 버튼
        // 버튼 활성화 여부에 따라 색상 변화 추후 추가 가능
        TextButton(
          onPressed: onNextPageButtonClicked,
          child: Text(AppLocalizations.of(context)!.next),
        ),
      ],
    );
  }
}
