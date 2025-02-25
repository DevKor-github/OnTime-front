import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/alarm/screeens/loading_screen.dart';

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
                    child: Image.asset(
                      'assets/character.png',
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
                // 로딩 화면을 먼저 표시
                showDialog(
                  context: context,
                  barrierDismissible: false, // 사용자가 뒤로 가기 버튼을 눌러도 닫히지 않도록 설정
                  builder: (context) => const LoadingScreen(),
                );

                // 로딩 화면
                await Future.delayed(const Duration(seconds: 1));

                if (context.mounted) {
                  Navigator.pop(context); // 로딩 화면 제거
                  GoRouter.of(context).go('/alarmScreen', extra: schedule);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
