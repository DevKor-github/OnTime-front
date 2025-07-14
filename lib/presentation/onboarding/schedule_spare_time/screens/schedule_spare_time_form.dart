import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time/components/shcedule_spare_time_field.dart';

class ScheduleSpareTimeForm extends StatefulWidget {
  const ScheduleSpareTimeForm({
    super.key,
  });

  @override
  State<ScheduleSpareTimeForm> createState() => _ScheduleSpareTimeFormState();
}

class _ScheduleSpareTimeFormState extends State<ScheduleSpareTimeForm> {
  Duration spareTime = Duration(minutes: 30);
  final Duration lowerBound = Duration(minutes: 0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: AppLocalizations.of(context)!.setSpareTimeTitle,
      subTitle: RichText(
        text: TextSpan(
          text: '${AppLocalizations.of(context)!.setSpareTimeDescription}\n',
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.outline,
          ),
          children: [
            TextSpan(
              text: AppLocalizations.of(context)!.setSpareTimeWarning,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: ScheduleSpareTimeField(
        lowerBound: lowerBound,
        spareTime: spareTime,
        onSpareTimeDecreased: () {
          setState(() {
            spareTime -= Duration(minutes: 10);
          });
        },
        onSpareTimeIncreased: () {
          setState(() {
            spareTime += Duration(minutes: 10);
          });
        },
      ),
    );
  }
}
