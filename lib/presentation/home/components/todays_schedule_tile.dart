import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

enum TodayScheduleTileState { scheduled, active, completed }

class TodaysScheduleTile extends StatelessWidget {
  const TodaysScheduleTile({
    super.key,
    this.schedule,
    this.onTap,
    this.compact = false,
    this.state = TodayScheduleTileState.scheduled,
  });

  final ScheduleEntity? schedule;
  final VoidCallback? onTap;
  final bool compact;
  final TodayScheduleTileState state;

  @override
  Widget build(BuildContext context) {
    final empty = schedule == null;
    final background = switch (empty ? null : state) {
      null => const Color(0xfff3f3f3),
      TodayScheduleTileState.scheduled => const Color(0xffdde4ff),
      TodayScheduleTileState.active => AppColors.blue.shade600,
      TodayScheduleTileState.completed => AppColors.grey.shade400,
    };
    final foreground = switch (empty ? null : state) {
      null => AppColors.grey.shade700,
      TodayScheduleTileState.scheduled => AppColors.blue.shade700,
      TodayScheduleTileState.active ||
      TodayScheduleTileState.completed => Colors.white,
    };
    final textTheme = Theme.of(context).textTheme;
    final localizations = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: compact ? 48 : 54,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: empty
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  localizations.noAppointments,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(color: foreground),
                ),
              )
            : Row(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      _leadingText(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(color: foreground),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      schedule!.scheduleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _leadingText(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (state) {
      case TodayScheduleTileState.active:
        return localizations.preparationInProgress;
      case TodayScheduleTileState.completed:
        return localizations.done;
      case TodayScheduleTileState.scheduled:
        final date = schedule!.scheduleTime;
        final locale = localizations.localeName;
        if (locale.startsWith('ko')) {
          final dayPeriod = DateFormat('a', locale).format(date);
          final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
          final minute = date.minute == 0 ? '' : ' ${date.minute}분';
          return '${date.month}월 ${date.day}일 $dayPeriod $hour시$minute';
        }
        return '${DateFormat.MMMd(locale).format(date)} ${DateFormat.jm(locale).format(date)}';
    }
  }
}
