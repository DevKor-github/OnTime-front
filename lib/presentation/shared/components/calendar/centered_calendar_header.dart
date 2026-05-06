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
    return Padding(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = constraints.maxWidth < 260.0 ? 6.0 : 12.0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: spacing,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.4),
                  ),
                ),
                icon: leftIcon,
                onPressed: onLeftArrowTap,
              ),
              Flexible(
                child: Text(
                  DateFormat.yMMMM(AppLocalizations.of(context)!.localeName)
                      .format(focusedMonth),
                  style: titleTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.4),
                  ),
                ),
                icon: rightIcon,
                onPressed: onRightArrowTap,
              ),
            ],
          );
        },
      ),
    );
  }
}
