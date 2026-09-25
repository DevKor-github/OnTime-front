import 'package:flutter/material.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_time_save_review.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';

Future<bool?> showScheduleTimeSaveReview({
  required BuildContext context,
  required ScheduleTimeSaveReview review,
}) => showDialog<bool>(
  context: context,
  builder: (context) {
    final l = AppLocalizations.of(context)!;
    final original = review.original;
    return AlertDialog(
      scrollable: true,
      title: Text(l.zonedTimeReviewTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.zonedTimeReviewDescription),
          if (original != null) ...[
            const SizedBox(height: 16),
            Text(
              l.zonedTimeBefore,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ScheduleZonedTime(
              civil: CivilDateTime.fromFields(original.scheduleTime),
              timeZoneId: original.timeZoneId,
              resolution: ScheduleTimeResolver.resolve(
                original,
                nowUtc: review.reviewedAtUtc,
              ),
              showInstant: true,
            ),
          ],
          const SizedBox(height: 16),
          Text(l.zonedTimeAfter, style: Theme.of(context).textTheme.titleSmall),
          ScheduleZonedTime(
            civil: CivilDateTime.fromFields(review.proposed.scheduleTime),
            timeZoneId: review.proposed.timeZoneId,
            resolution: review.resolution,
            showInstant: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('schedule-time-review-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.zonedTimeConfirmSave),
        ),
      ],
    );
  },
);
