import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/presentation/recurring/recurrence_occurrence_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/utils/duration_format.dart';

// Helper widget for swipe actions
class _SwipeActionContent extends StatelessWidget {
  const _SwipeActionContent({
    required this.icon,
    required this.color,
    required this.margin,
  });

  final Widget icon;
  final Color color;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: icon,
        ),
      ),
    );
  }
}

// Helper widget for vertical divider
class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(width: 1, color: theme.colorScheme.surfaceContainer);
  }
}

class ScheduleDetail extends StatefulWidget {
  ScheduleDetail({
    super.key,
    required this.schedule,
    this.preparationTime,
    this.isEarlyStarted = false,
    this.onDeleted,
    this.onEdit,
  });

  final ScheduleEntity schedule;
  final Duration? preparationTime;
  final bool isEarlyStarted;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  final meatballsIcon = SvgPicture.asset('meatballs.svg', package: 'assets');

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  static const double _actionWidth = 96.0;
  static const EdgeInsets _trailingActionMargin = EdgeInsets.only(
    left: 4.0,
    top: 4.0,
    bottom: 4.0,
  );

  String get _scheduleRenderKey => [
    widget.schedule.id,
    widget.schedule.scheduleName,
    widget.schedule.place.placeName,
    widget.schedule.scheduleTime.millisecondsSinceEpoch,
    widget.schedule.moveTime.inMinutes,
    widget.schedule.scheduleSpareTime?.inMinutes ?? -1,
    widget.schedule.doneStatus.name,
  ].join('|');

  @override
  Widget build(BuildContext context) {
    return SwipeActionCell(
      key: ValueKey<String>(_scheduleRenderKey),
      backgroundColor: Colors.transparent,
      trailingActions: _buildSwipeActions(context),
      child: _buildScheduleContent(context),
    );
  }

  List<SwipeAction> _buildSwipeActions(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canEdit = _canEdit(now);
    const canDelete =
        true; // Eligibility is checked from current data in confirmation.
    return [
      if (canDelete)
        SwipeAction(
          widthSpace: _actionWidth,
          onTap: (handler) async {
            await handler(false);
            widget.onDeleted?.call();
          },
          color: Colors.transparent,
          content: _SwipeActionContent(
            icon: const _TrashCanSvg(),
            color: theme.colorScheme.error,
            margin: _trailingActionMargin,
          ),
        ),
      if (canEdit)
        SwipeAction(
          widthSpace: _actionWidth,
          onTap: (handler) async {
            await handler(false);
            widget.onEdit?.call();
          },
          color: Colors.transparent,
          content: _SwipeActionContent(
            icon: const _EditPencilSvg(),
            color: theme.colorScheme.outline,
            margin: _trailingActionMargin,
          ),
        ),
    ];
  }

  bool _canEdit(DateTime now) {
    if (widget.schedule.isStarted ||
        widget.isEarlyStarted ||
        widget.schedule.preparationFrozen ||
        widget.schedule.doneStatus != ScheduleDoneStatus.notEnded ||
        widget.schedule.retainedRecurringReference) {
      return false;
    }
    final time = ScheduleTimeResolver.resolve(widget.schedule, nowUtc: now);
    if (time.instantUtc == null) {
      return true; // Keep correction/explanation reachable.
    }
    return widget.schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        !widget.schedule.retainedRecurringReference &&
        !_hasPreparationStarted(now) &&
        !time.instantUtc!.isBefore(now.toUtc());
  }

  bool _hasPreparationStarted(DateTime now) {
    if (widget.schedule.isStarted || widget.isEarlyStarted) {
      return true;
    }

    final preparationTime = widget.preparationTime;
    if (preparationTime == null) {
      return false;
    }

    final instant = ScheduleTimeResolver.resolve(
      widget.schedule,
      nowUtc: now,
    ).instantUtc;
    if (instant == null) return false;
    final preparationStartTime = instant.subtract(
      widget.schedule.moveTime +
          preparationTime +
          (widget.schedule.scheduleSpareTime ?? Duration.zero),
    );
    return !now.isBefore(preparationStartTime);
  }

  Widget _buildScheduleContent(BuildContext context) {
    final theme = Theme.of(context);
    final time = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: _ScheduleTimeColumn(scheduleTime: widget.schedule.scheduleTime),
    );
    final details = _ScheduleDetailsColumn(
      schedule: widget.schedule,
      placeName: widget.schedule.place.placeName,
      preparationTime: widget.preparationTime,
      onEdit: _canEdit(DateTime.now()) ? widget.onEdit : null,
      onDelete: widget.onDeleted,
    );
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 400 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [time, const Divider(), details],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                time,
                const _VerticalDivider(),
                Expanded(child: details),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleTimeColumn extends StatelessWidget {
  const _ScheduleTimeColumn({required this.scheduleTime});

  final DateTime scheduleTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          TimeOfDay.fromDateTime(scheduleTime).format(context),
          style: theme.textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ScheduleDetailsColumn extends StatelessWidget {
  const _ScheduleDetailsColumn({
    required this.schedule,
    required this.placeName,
    required this.preparationTime,
    this.onEdit,
    this.onDelete,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ScheduleEntity schedule;
  final String placeName;
  final Duration? preparationTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolution = ScheduleTimeResolver.resolve(
      schedule,
      nowUtc: DateTime.now(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Theme(
        data: Theme.of(context).copyWith(
          visualDensity: const VisualDensity(
            vertical: VisualDensity.minimumDensity,
          ),
          listTileTheme: const ListTileThemeData(
            dense: true,
            minVerticalPadding: 0,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: IconTheme(
          data: IconTheme.of(context).copyWith(size: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor:
                    theme.colorScheme.onSurfaceVariant, // Color when expanded
                // icon size provided by IconTheme above
                collapsedIconColor:
                    theme.colorScheme.onSurfaceVariant, // Color when collapsed
                title: Text(
                  schedule.scheduleName,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                childrenPadding: const EdgeInsets.only(top: 16.0),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const _MapPinFillSvg(),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          placeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                children: [
                  if (onDelete != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          )!.deleteScheduleConfirmAction,
                        ),
                      ),
                    ),
                  if (schedule.isRecurring)
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) => SizedBox(
                          height: MediaQuery.sizeOf(context).height * .94,
                          child: RecurrenceOccurrenceSheet(
                            schedule: schedule,
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
                        ),
                      ),
                      child: Text(
                        recurrenceText(context, '이번 회차 보기', 'View occurrence'),
                      ),
                    ),
                  Column(
                    children: [
                      _ScheduleInfoTile(
                        label: AppLocalizations.of(context)!.travelTime,
                        value: formatDuration(context, schedule.moveTime),
                      ),
                      _ScheduleInfoTile(
                        label: AppLocalizations.of(context)!.preparationTime,
                        value: preparationTime == null
                            ? '-'
                            : formatDuration(context, preparationTime!),
                      ),
                      _ScheduleInfoTile(
                        label: AppLocalizations.of(context)!.spareTime,
                        value: formatDuration(
                          context,
                          schedule.scheduleSpareTime ?? Duration.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ScheduleZonedTime(
                civil: CivilDateTime.fromFields(schedule.scheduleTime),
                timeZoneId: schedule.timeZoneId,
                resolution: resolution,
                style: theme.textTheme.bodySmall,
              ),
              if (resolution.instantUtc == null)
                Text(
                  recurrenceText(
                    context,
                    '시간대와 발생 시각을 확인해주세요.',
                    'Review the time zone and occurrence.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              if (schedule.retainedRecurringReference)
                Text(
                  recurrenceText(
                    context,
                    '이전 반복 구간의 보존 기록',
                    'Retained record from a closed recurrence',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              if (schedule.isRecurring)
                Text(
                  recurrenceText(context, '반복 일정', 'Recurring schedule'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (schedule.isRecurring &&
                  !schedule.isStarted &&
                  schedule.doneStatus == ScheduleDoneStatus.notEnded &&
                  resolution.isHistorical)
                Text(
                  recurrenceText(
                    context,
                    '진행 기록 없음',
                    'No preparation recorded',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleInfoTile extends StatelessWidget {
  const _ScheduleInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 18,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _MapPinFillSvg extends StatelessWidget {
  const _MapPinFillSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('map_pin_fill.svg', package: 'assets');
  }
}

class _TrashCanSvg extends StatelessWidget {
  const _TrashCanSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('trash_can.svg', package: 'assets');
  }
}

class _EditPencilSvg extends StatelessWidget {
  const _EditPencilSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('edit_pencil.svg', package: 'assets');
  }
}
