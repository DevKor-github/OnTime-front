import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class PreparationStepListWidget extends StatefulWidget {
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

  @override
  void didUpdateWidget(covariant PreparationStepListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrentStep();
    }
  }

  void _scrollToCurrentStep() {
    if (widget.currentIndex >= 0 &&
        widget.currentIndex < widget.preparations.length) {
      const double tileHeight = 135.0; // 각 타일의 높이
      final double topOffset = 15.0; // Positioned의 top 값
      final double listPaddingTop =
          MediaQuery.of(context).size.height * 0.05; // 리스트 상단 여백

      // 스크롤 위치를 계산
      double scrollOffset =
          (widget.currentIndex * tileHeight) - topOffset - listPaddingTop;

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
    return Center(
      child: SizedBox(
        width: 329,
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: widget.preparations.length,
          itemBuilder: (context, index) {
            final step = widget.preparations[index];
            final stepNumber = index + 1;

            // 마지막 항목 판별
            final bool isLastItem = (index == widget.preparations.length - 1);

            // 각 목록 별 누적 시간
            final int elapsed = widget.elapsedTimes[index];

            // 각 목록 별 상태(done, now, yet)
            final String state;
            if (index < widget.currentIndex) {
              state = 'done';
            } else if (index == widget.currentIndex) {
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
              onSkip: state == 'now' ? () => widget.onSkip() : null,
              elapsedTime: elapsed,
              isLastItem: isLastItem,
            );
          },
        ),
      ),
    );
  }
}
