import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';

class PreparationStepTile extends StatefulWidget {
  final int stepIndex;
  final String preparationName;
  final String preparationTime;
  final String state;
  final VoidCallback? onSkip;
  final int? previousElapsedTime;

  const PreparationStepTile({
    super.key,
    required this.stepIndex,
    required this.preparationName,
    required this.preparationTime,
    required this.state,
    this.onSkip,
    this.previousElapsedTime,
  });

  @override
  _PreparationStepTileState createState() => _PreparationStepTileState();
}

class _PreparationStepTileState extends State<PreparationStepTile> {
  Timer? timer;
  int elapsedSeconds = 0; // 이 컴포넌트의 누적 시간
  late int preparationTimeInSeconds; // 각 과정 별 지정된 준비 시간

  @override
  void initState() {
    super.initState();

    preparationTimeInSeconds = _convertTimeToSeconds(widget.preparationTime);

    // state가 'done'인 경우 이전에 저장된 시간을 불러옴
    if (widget.state == 'done' && widget.previousElapsedTime != null) {
      elapsedSeconds = widget.previousElapsedTime!;
    }

    // state가 'now'인 경우 타이머 시작
    if (widget.state == 'now') {
      startTimer();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedSeconds++;
        // 지정된 준비 시간을 초과하면 타이머를 멈추고 다음 단계로 이동
        if (elapsedSeconds >= preparationTimeInSeconds) {
          timer.cancel();
          if (widget.onSkip != null) {
            widget.onSkip!();
          }
        }
      });
    });
  }

  int _convertTimeToSeconds(String time) {
    final List<String> parts = time.split(RegExp(r'[^\d+]'));
    final int minutes = int.tryParse(parts[0]) ?? 0;
    final int seconds = int.tryParse(parts[1]) ?? 0;
    return (minutes * 60) + seconds;
  }

  String _formatElapsedTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes분 $remainingSeconds초';
  }

// 좌측 순서 및 체크 표시
  @override
  Widget build(BuildContext context) {
    Widget circleContent;
    if (widget.state == 'done') {
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
    if (widget.state == 'now' && widget.onSkip != null) {
      skipButton = Align(
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
            onPressed: widget.onSkip,
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
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 31,
              child: Text(
                widget.state == 'now'
                    ? _formatElapsedTime(elapsedSeconds) // 실시간 타이머 표시
                    : (widget.state == 'done'
                        ? _formatElapsedTime(elapsedSeconds) // 완료된 시간 표시
                        : widget.preparationTime), // yet 상태에서는 지정된 시간 표시
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 358,
          height: (widget.state == 'now' && skipButton != null) ? 135 : 62,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              border: (widget.state == 'now')
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
                    Flexible(
                      child: skipButton,
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
        // 점선
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
    );
  }
}
