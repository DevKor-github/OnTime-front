import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class CenteredCalendarHeader extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;
  final TextStyle titleTextStyle;
  final Widget leftIcon;
  final Widget rightIcon;

  const CenteredCalendarHeader({
    super.key,
    required this.focusedMonth,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    required this.titleTextStyle,
    required this.leftIcon,
    required this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.4),
              ),
            ),
            icon: leftIcon,
            onPressed: onLeftArrowTap,
          ),
          Text(
            DateFormat.yMMMM(AppLocalizations.of(context)!.localeName)
                .format(focusedMonth),
            style: textTheme.titleSmall,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.4),
              ),
            ),
            icon: rightIcon,
            onPressed: onRightArrowTap,
          ),
        ],
      ),
    );
  }
}
