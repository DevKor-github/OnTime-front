import 'dart:async';

import 'package:on_time_front/presentation/recurring/recurrence_occurrence_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/utils/duration_format.dart';
import 'package:intl/intl.dart';

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
            borderRadius: BorderRadius.circular(8),
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
    this.referenceDate,
    this.onDeleted,
    this.onEdit,
  });

  final ScheduleEntity schedule;
  final Duration? preparationTime;
  final bool isEarlyStarted;
  final DateTime? referenceDate;
  final VoidCallback? onEdit;
  final FutureOr<void> Function()? onDeleted;

  final meatballsIcon = SvgPicture.asset('meatballs.svg', package: 'assets');

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  bool _expanded = false;

  DateTime get _now => widget.referenceDate ?? DateTime.now();
  double get _actionGap => _expanded ? 10 : 8;

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SwipeActionCell(
        key: ValueKey<String>(_scheduleRenderKey),
        backgroundColor: Colors.transparent,
        trailingActions: _buildSwipeActions(context),
        child: _buildScheduleContent(context),
      ),
    );
  }

  List<SwipeAction> _buildSwipeActions(BuildContext context) {
    final now = _now;
    final canEdit =
        widget.schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        !_hasPreparationStarted(now) &&
        !widget.schedule.occurrenceInstantUtc.isBefore(now.toUtc());
    final canDelete = widget.schedule.doneStatus == ScheduleDoneStatus.notEnded;
    return [
      if (canDelete)
        SwipeAction(
          widthSpace: _expanded ? 92 : 94,
          onTap: (handler) async {
            await widget.onDeleted?.call();
            if (mounted) await handler(false);
          },
          color: Colors.transparent,
          content: _SwipeActionContent(
            icon: const _TrashCanSvg(),
            color: const Color(0xffbf2e22),
            margin: EdgeInsets.only(left: _actionGap, right: _expanded ? 0 : 4),
          ),
        ),
      if (canEdit)
        SwipeAction(
          widthSpace: _expanded ? 92 : 90,
          onTap: (handler) async {
            await handler(false);
            widget.onEdit?.call();
          },
          color: Colors.transparent,
          content: _SwipeActionContent(
            icon: const _EditPencilSvg(),
            color: const Color(0xff545454),
            margin: EdgeInsets.only(left: _actionGap),
          ),
        ),
    ];
  }

  bool _hasPreparationStarted(DateTime now) {
    if (widget.schedule.isStarted || widget.isEarlyStarted) {
      return true;
    }

    final preparationTime = widget.preparationTime;
    if (preparationTime == null) {
      return false;
    }

    final preparationStartTime = widget.schedule.occurrenceInstantUtc.subtract(
      widget.schedule.moveTime +
          preparationTime +
          (widget.schedule.scheduleSpareTime ?? Duration.zero),
    );
    return !now.isBefore(preparationStartTime);
  }

  Widget _buildScheduleContent(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.schedule;
    final canEdit =
        schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        !_hasPreparationStarted(_now) &&
        !schedule.occurrenceInstantUtc.isBefore(_now.toUtc());
    final canDelete = schedule.doneStatus == ScheduleDoneStatus.notEnded;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final sourceLayout = textScale <= 1.01 && !schedule.isRecurring;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          schedule.scheduleName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          maxLines: sourceLayout ? 1 : null,
          overflow: sourceLayout ? TextOverflow.ellipsis : null,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 18, height: 19, child: _MapPinFillSvg()),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                schedule.place.placeName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.colorScheme.outline,
                ),
                maxLines: sourceLayout ? 1 : null,
                overflow: sourceLayout ? TextOverflow.ellipsis : null,
              ),
            ),
          ],
        ),
        if (schedule.isRecurring) ...[
          Text(
            recurrenceText(context, '반복 일정', 'Recurring schedule'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (!schedule.isStarted &&
              canDelete &&
              schedule.occurrenceInstantUtc.isBefore(_now.toUtc()))
            Text(
              recurrenceText(context, '진행 기록 없음', 'No preparation recorded'),
              style: theme.textTheme.bodySmall,
            ),
        ],
        if (_expanded) ...[
          const SizedBox(height: 16),
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
                    onEdit: canEdit ? widget.onEdit : null,
                    onDelete: canDelete ? widget.onDeleted : null,
                  ),
                ),
              ),
              child: Text(
                recurrenceText(context, '이번 회차 보기', 'View occurrence'),
              ),
            ),
          _ScheduleInfoTile(
            label: AppLocalizations.of(context)!.travelTime,
            value: formatDuration(context, schedule.moveTime),
          ),
          const SizedBox(height: 8),
          _ScheduleInfoTile(
            label: AppLocalizations.of(context)!.preparationTime,
            value: widget.preparationTime == null
                ? '-'
                : formatDuration(context, widget.preparationTime!),
          ),
          const SizedBox(height: 8),
          _ScheduleInfoTile(
            label: AppLocalizations.of(context)!.spareTime,
            value: formatDuration(
              context,
              schedule.scheduleSpareTime ?? Duration.zero,
            ),
          ),
        ],
      ],
    );
    return Material(
      key: ValueKey('schedule_card_${schedule.id}'),
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _expanded ? 192 : 82,
              maxHeight: sourceLayout
                  ? (_expanded ? 192 : 82)
                  : double.infinity,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 70,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat(
                              'h:mm',
                              'en',
                            ).format(schedule.scheduleTime),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 16,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            DateFormat('a', 'en').format(schedule.scheduleTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: _VerticalDivider(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(21, 15, 12, 15),
                      child: Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 8),
                          RotatedBox(
                            quarterTurns: _expanded ? 2 : 0,
                            child: SvgPicture.asset(
                              'calendar_chevron_down.svg',
                              package: 'assets',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    final style = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.4,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: style?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 18),
        Flexible(child: Text(value, style: style)),
      ],
    );
  }
}

class _MapPinFillSvg extends StatelessWidget {
  const _MapPinFillSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('calendar_map_pin.svg', package: 'assets');
  }
}

class _TrashCanSvg extends StatelessWidget {
  const _TrashCanSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('calendar_trash.svg', package: 'assets');
  }
}

class _EditPencilSvg extends StatelessWidget {
  const _EditPencilSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('calendar_edit.svg', package: 'assets');
  }
}
