import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

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
      child: SwipeActionCell(
        key: ValueKey<String>(widget.schedule.id),
        backgroundColor: Colors.transparent,
        trailingActions: _buildSwipeActions(context),
        child: _buildScheduleContent(context),
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
      height: 82,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _ScheduleTimeColumn(
                  hour: widget.schedule.scheduleTime.hour,
                  period: "PM",
                ),
              ),
              const _VerticalDivider(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0) +
                      const EdgeInsets.only(top: 4.0),
                  child: _ScheduleDetailsColumn(
                    scheduleName: widget.schedule.scheduleName,
                    placeName: widget.schedule.place.placeName,
                  ),
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
      {required this.scheduleName, required this.placeName});

  final String scheduleName;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          scheduleName,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const _MapPinFillSvg(),
            Text(
              placeName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
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
