import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class ScheduleDetail extends StatefulWidget {
  ScheduleDetail(
      {super.key, required this.schedule, this.onDeleted, this.onEdit});

  final ScheduleEntity schedule;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  final meatballsIcon = SvgPicture.asset(
    'assets/meatballs.svg',
  );

  @override
  State<ScheduleDetail> createState() => _ScheduleDetailState();
}

class _ScheduleDetailState extends State<ScheduleDetail> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            onPressed: () {
              widget.onEdit?.call();
              Navigator.pop(context);
            },
            trailingIcon: CupertinoIcons.square_pencil_fill,
            child: const Text('Edit'),
          ),
          CupertinoContextMenuAction(
            onPressed: () {
              widget.onDeleted?.call();
              Navigator.pop(context);
            },
            isDestructiveAction: true,
            trailingIcon: CupertinoIcons.delete,
            child: const Text('Delete'),
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          width: MediaQuery.of(context).size.width - 32,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.schedule.scheduleName,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      widget.schedule.scheduleTime.toString(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      widget.schedule.place.placeName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
