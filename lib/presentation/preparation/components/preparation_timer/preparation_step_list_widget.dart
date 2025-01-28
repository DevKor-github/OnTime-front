import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_timer/preparation_step_tile.dart';

class PreparationStepListWidget extends StatelessWidget {
  final List<dynamic> preparations; // 준비 과정 데이터
  final int currentIndex; // 현재 실행 중인 준비 과정 인덱스
  final Function onSkip; // "단계 건너뛰기" 콜백

  const PreparationStepListWidget({
    super.key,
    required this.preparations,
    required this.currentIndex,
    required this.onSkip,
  });

  String formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes분 $remainingSeconds초';
    } else if (minutes > 0) {
      return '$minutes분';
    } else {
      return '$remainingSeconds초';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 329,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: preparations.length,
          itemBuilder: (context, index) {
            final preparation = preparations[index];
            final stepNumber = index + 1;

            // 마지막 항목 판별
            final bool isLastItem = (index == preparations.length - 1);

            // 각 목록 별 누적 시간
            final int elapsed = preparation['elapsedTime'] ?? 0;

            // 각 목록 별 상태(done, now, yet)
            final String state;
            if (index < currentIndex) {
              state = 'done';
            } else if (index == currentIndex) {
              state = 'now';
            } else {
              state = 'yet';
            }

            return PreparationStepTile(
              stepIndex: stepNumber,
              preparationName: preparation['preparationName'],
              preparationTime: formatTime(
                preparation['preparationTime'] * 60,
              ),
              state: state,
              onSkip: state == 'now' ? () => onSkip() : null,
              elapsedTime: elapsed,
              isLastItem: isLastItem,
            );
          },
        ),
      ),
    );
  }
}
