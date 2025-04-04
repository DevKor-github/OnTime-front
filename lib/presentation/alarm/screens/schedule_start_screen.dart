import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/presentation/shared/components/button.dart';

class ScheduleStart extends StatelessWidget {
  final ScheduleEntity schedule;

  const ScheduleStart({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    schedule.scheduleName,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff5C79FB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    schedule.place.placeName,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '지금 준비 시작 안하면 늦어요!',
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SvgPicture.asset(
                      'characters/character.svg',
                      package: 'assets',
                      width: 204,
                      height: 269,
                    ),
                  )
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Button(
              text: '준비 시작',
              onPressed: () async {
                context.go('/alarmScreen', extra: schedule);
              },
            ),
          ),
        ],
      ),
    );
  }
}
