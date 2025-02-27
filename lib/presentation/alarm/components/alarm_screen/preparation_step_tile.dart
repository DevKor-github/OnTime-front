import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PreparationStepTile extends StatefulWidget {
  final int stepIndex;
  final String preparationName;
  final String preparationTime;
  final String preparationState;
  final int elapsedTime;
  final bool isLastItem;
  final VoidCallback? onSkip;

  const PreparationStepTile({
    super.key,
    required this.stepIndex,
    required this.preparationName,
    required this.preparationTime,
    required this.preparationState,
    required this.elapsedTime,
    required this.isLastItem,
    this.onSkip,
  });

  @override
  _PreparationStepTileState createState() => _PreparationStepTileState();
}

class _PreparationStepTileState extends State<PreparationStepTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // AnimationController 초기화
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
      builder: (context, timerState) {
        String displayTime;

        // 상태에 따라 타이머 시간 업데이트
        if (widget.preparationState == 'yet') {
          // 준비 전: 목표 시간 표시
          displayTime = widget.preparationTime;
        } else if (widget.preparationState == 'now') {
          // 진행 중: elapsedTime (누적 시간 타이머)
          displayTime = formatElapsedTime(widget.elapsedTime);

          // 타이머가 진행 중인 상태일 때, timerState를 통해 실시간 업데이트된 elapsedTime을 표시
          if (timerState is AlarmTimerRunInProgress) {
            displayTime =
                formatElapsedTime(timerState.preparationStepelapsedTime);
          }
        } else {
          // 완료된 상태: 완료된 누적 시간 표시
          displayTime = formatElapsedTime(widget.elapsedTime);
        }

        // 좌측 순서 및 체크 표시
        Widget circleContent;
        if (widget.preparationState == 'done') {
          circleContent = const Icon(Icons.check);
        } else {
          circleContent = Text(
            '${widget.stepIndex}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff212F6F),
            ),
          );
        }

        // 건너뛰기 버튼
        Widget? skipButton;
        if (widget.preparationState == 'now' && widget.onSkip != null) {
          skipButton = Builder(builder: (context) {
            return Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 326,
                height: 53,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xffDCE3FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onSkip?.call();
                  },
                  child: const Text(
                    '이 단계 건너 뛰기',
                    style: TextStyle(
                      color: Color(0xff212F6F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center, // 텍스트 중앙 정렬
                  ),
                ),
              ),
            );
          });
        }

        final boxChild = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xffDCE3FF),
                      ),
                    ),
                    circleContent,
                  ],
                ),
                const SizedBox(width: 20),
                SizedBox(
                  height: 31,
                  child: Text(
                    widget.preparationName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 31,
                  child: Text(
                    displayTime,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff5C79FB),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value, // 애니메이션 효과
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: Duration(milliseconds: 300),
                curve: Curves.ease,
                child: Container(
                  width: 358,
                  height:
                      (widget.preparationState == 'now' && skipButton != null)
                          ? 135
                          : 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    border: (widget.preparationState == 'now')
                        ? Border.all(color: Color(0xff5C79FB), width: 2)
                        : null,
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        boxChild,
                        if (skipButton != null) ...[
                          const SizedBox(height: 20),
                          Expanded(child: skipButton),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              // 점선
              if (!widget.isLastItem)
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: DottedLine(
                    direction: Axis.vertical,
                    lineLength: 23,
                    lineThickness: 3,
                    dashColor: const Color(0xff5C79FB),
                    dashLength: 4,
                    dashGapLength: 5,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
