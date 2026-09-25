import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

/// Explains existing date grouping without changing any schedule or query.
class DateBasisInfo extends StatelessWidget {
  const DateBasisInfo({super.key, required this.home});
  final bool home;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final caption = home
        ? l.zonedTimeHomeDateBasis
        : l.zonedTimeCalendarDateBasis;
    return TextButton.icon(
      key: ValueKey(home ? 'home-date-basis' : 'calendar-date-basis'),
      style: TextButton.styleFrom(alignment: Alignment.centerLeft),
      icon: const Icon(Icons.info_outline, size: 18),
      label: Text(caption, style: Theme.of(context).textTheme.bodySmall),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l.zonedTimeDateBasisTitle),
          content: Text(l.zonedTimeDateBasisDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.ok),
            ),
          ],
        ),
      ),
    );
  }
}
