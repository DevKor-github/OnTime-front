import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/presentation/shared/components/modal_component.dart';

class ScheduleStartScreen extends StatefulWidget {
  final ScheduleEntity schedule;

  const ScheduleStartScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleStartScreen> createState() => _ScheduleStartScreenState();
}

class _ScheduleStartScreenState extends State<ScheduleStartScreen> {
  void _showModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ModalComponent(
          leftPressed: () {
            Navigator.of(context).pop();
            context.go('/home');
          },
          rightPressed: () => Navigator.of(context).pop(),
          modalTitleText: '정말 나가시겠어요?',
          modalDetailText: '이 화면을 나가면\n함께 약속을 준비할 수 없게 돼요.',
          leftButtonText: '나갈래요',
          leftButtonColor: Theme.of(context).colorScheme.surfaceContainerLow,
          leftButtonTextColor: Theme.of(context).colorScheme.outline,
          rightButtonText: '있을래요',
          rightButtonColor: Theme.of(context).colorScheme.primary,
          rightButtonTextColor: Theme.of(context).colorScheme.onPrimary,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.schedule.scheduleName,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff5C79FB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.schedule.place.placeName,
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
                        padding: const EdgeInsets.only(top: 50),
                        child: SvgPicture.asset(
                          'characters/character.svg',
                          package: 'assets',
                          width: 204,
                          height: 269,
                        ),
                      ),
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
                    context.go('/alarmScreen', extra: widget.schedule);
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _showModal(context),
            ),
          ),
        ],
      ),
    );
  }
}
