import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Bloc import 추가

class PreparationStepListWidget extends StatefulWidget {
  final List<PreparationStepEntity> preparations; // 준비 과정 데이터
  final Function onSkip; // "단계 건너뛰기" 콜백

  const PreparationStepListWidget({
    super.key,
    required this.preparations,
    required this.onSkip,
  });

  @override
  State<PreparationStepListWidget> createState() =>
      _PreparationStepListWidgetState();
}

class _PreparationStepListWidgetState extends State<PreparationStepListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentStep();
    });
  }

  // 스크롤을 해당 위치로 이동하는 메서드
  void _scrollToCurrentStep() {
    final currentStepIndex = context.read<AlarmTimerBloc>().currentStepIndex;

    if (currentStepIndex >= 0 &&
        currentStepIndex < widget.preparations.length) {
      const double tileHeight = 135.0; // 각 타일의 높이
      final double topOffset = 15.0; // Positioned의 top 값
      final double listPaddingTop =
          MediaQuery.of(context).size.height * 0.05; // 리스트 상단 여백

      // 스크롤 위치를 계산
      double scrollOffset =
          (currentStepIndex * tileHeight) - topOffset - listPaddingTop;

      // 스크롤 가능한 최대 범위를 가져옴
      final double maxScrollExtent = _scrollController.position.maxScrollExtent;

      // 마지막 항목이 리스트 상단에 맞춰질 수 있도록 스크롤 위치를 보정
      scrollOffset = scrollOffset.clamp(0.0, maxScrollExtent);

      // 스크롤 애니메이션 적용
      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
      builder: (context, timerState) {
        if (timerState is AlarmTimerRunInProgress ||
            timerState is AlarmTimerInitial) {
          return Center(
            child: SizedBox(
              width: 329,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.preparations.length,
                itemBuilder: (context, index) {
                  final preparation = widget.preparations[index];

                  final PreparationStateEnum preparationState =
                      context.read<AlarmTimerBloc>().preparationStates[index];
                  final int elapsedTime =
                      context.read<AlarmTimerBloc>().elapsedTimes[index];

                  final bool isLastItem =
                      (index == widget.preparations.length - 1);

                  return PreparationStepTile(
                    key: Key('$index'),
                    stepIndex: index + 1,
                    preparationName: preparation.preparationName,
                    preparationTime:
                        formatTime(preparation.preparationTime.inSeconds),
                    preparationState: preparationState,
                    elapsedTime: elapsedTime,
                    isLastItem: isLastItem,
                    onSkip: preparationState == PreparationStateEnum.now
                        ? () {
                            context
                                .read<AlarmTimerBloc>()
                                .add(TimerStepSkipped());
                          }
                        : null,
                  );
                },
              ),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
