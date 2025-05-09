import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';

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
        return _ScheduleStartScreenModal();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
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
      ),
    );
  }
}

class _ScheduleStartScreenModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomAlertDialog(
      title: const Text(
        '정말 나가시겠어요?',
      ),
      content: const Text(
        '이 화면을 나가면\n함께 약속을 준비할 수 없게 돼요',
      ),
      actions: [
        ModalButton(
          onPressed: () => context.go('/home'),
          text: '나갈래요',
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          textColor: Theme.of(context).colorScheme.outline,
        ),
        ModalButton(
          onPressed: () => Navigator.pop(context),
          text: '있을래요',
          color: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ],
    );
  }
}
