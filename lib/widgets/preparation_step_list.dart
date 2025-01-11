import 'package:flutter/material.dart';
import 'package:on_time_front/widgets/preparation_step_tile.dart';

class PreparationStepList extends StatelessWidget {
  final List<dynamic> preparations; // 준비 과정 데이터
  final int currentIndex; // 현재 실행 중인 준비 과정 인덱스
  final Function onSkip; // "단계 건너뛰기" 콜백

  const PreparationStepList({
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
          reverse: true,
          shrinkWrap: true,
          itemCount: preparations.length,
          itemBuilder: (context, index) {
            final reversedIndex = preparations.length - 1 - index;
            final preparation = preparations[reversedIndex];
            final stepNumber = reversedIndex + 1;

            final String state;
            if (reversedIndex < currentIndex) {
              state = 'done';
            } else if (reversedIndex == currentIndex) {
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
            );
          },
        ),
      ),
    );
  }
}
