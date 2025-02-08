import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_step_tile.dart';
import 'package:on_time_front/utils/time_format.dart';

class PreparationStepListWidget extends StatelessWidget {
  final List<PreparationStepEntity> preparations; // 준비 과정 데이터
  final List<int> elapsedTimes;
  final int currentIndex; // 현재 실행 중인 준비 과정 인덱스
  final Function onSkip; // "단계 건너뛰기" 콜백

  const PreparationStepListWidget({
    super.key,
    required this.preparations,
    required this.elapsedTimes,
    required this.currentIndex,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 329,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: preparations.length,
          itemBuilder: (context, index) {
            final step = preparations[index];
            final stepNumber = index + 1;

            // 마지막 항목 판별
            final bool isLastItem = (index == preparations.length - 1);

            // 각 목록 별 누적 시간
            final int elapsed = elapsedTimes[index];

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
              preparationName: step.preparationName,
              preparationTime: formatTime(
                step.preparationTime.inSeconds,
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
