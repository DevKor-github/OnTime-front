import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_template.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';

// Helper widget for swipe actions
class _SwipeActionContent extends StatelessWidget {
  const _SwipeActionContent({
    required this.icon,
    required this.color,
  });

  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Padding(
        padding: const EdgeInsets.all(29.0),
        child: icon,
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
    return Container(
      width: 1,
      height: 56, // Matches typical ListTile/ExpansionTile height
      color: theme.colorScheme.surfaceContainer,
    );
  }
}

class ScheduleDetail extends StatefulWidget {
  ScheduleDetail(
      {super.key, required this.schedule, this.onDeleted, this.onEdit});

  final ScheduleEntity schedule;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  final meatballsIcon = SvgPicture.asset(
    'meatballs.svg',
    package: 'assets',
  );

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwipeActionCell(
            key: ValueKey<String>(widget.schedule.id),
            backgroundColor: Colors.transparent,
            trailingActions: _buildSwipeActions(context),
            child: _buildScheduleContent(context),
          ),
        ],
      ),
    );
  }

  List<SwipeAction> _buildSwipeActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      SwipeAction(
        onTap: (controller) => widget.onDeleted?.call(),
        color: Colors.transparent,
        content: _SwipeActionContent(
          icon: const _TrashCanSvg(),
          color: theme.colorScheme.error,
        ),
      ),
      SwipeAction(
        widthSpace: 96,
        onTap: (controller) => widget.onEdit?.call(),
        color: Colors.transparent,
        content: _SwipeActionContent(
          icon: const _EditPencilSvg(),
          color: theme.colorScheme.outline,
        ),
      ),
    ];
  }

  Widget _buildScheduleContent(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Container(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _ScheduleTimeColumn(
                  hour: widget.schedule.scheduleTime.hour,
                  period: "PM",
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: _ScheduleDetailsColumn(
                  schedule: widget.schedule,
                  placeName: widget.schedule.place.placeName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTimeColumn extends StatelessWidget {
  const _ScheduleTimeColumn({required this.hour, required this.period});

  final int hour;
  final String period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          hour.toString(),
          style: theme.textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          period,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ScheduleDetailsColumn extends StatelessWidget {
  const _ScheduleDetailsColumn(
      {required this.schedule, required this.placeName});

  final ScheduleEntity schedule;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(vertical: 2.0),
        childrenPadding: const EdgeInsets.all(20.0),
        shape: const Border(),
        collapsedShape: const Border(),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(
          schedule.scheduleName,
          style: theme.textTheme.titleLarge,
        ),
        subtitle: Row(
          children: [
            const _MapPinFillSvg(),
            const SizedBox(width: 4),
            Text(
              placeName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        children: [
          Column(
            children: [
              ScheduleInfoTile(
                label: '이동시간',
                value:
                    '${schedule.moveTime.inHours}시간 ${schedule.moveTime.inMinutes - schedule.moveTime.inHours * 60}분',
              ),
              //TODO: add preparation time
              ScheduleInfoTile(
                label: '여유시간',
                value: '${schedule.scheduleSpareTime?.inMinutes}분',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ScheduleInfoTile extends StatelessWidget {
  const ScheduleInfoTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyExtraSmall.copyWith(
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: textTheme.bodySmall,
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
    return SvgPicture.asset(
      'map_pin_fill.svg',
      package: 'assets',
    );
  }
}

class _TrashCanSvg extends StatelessWidget {
  const _TrashCanSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'trash_can.svg',
      package: 'assets',
    );
  }
}

class _EditPencilSvg extends StatelessWidget {
  const _EditPencilSvg();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'edit_pencil.svg',
      package: 'assets',
    );
  }
}
