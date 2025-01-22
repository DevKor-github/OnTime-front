import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';

class PreparationStepTileTest extends StatefulWidget {
  final int stepIndex;
  final String preparationName;
  final String preparationTime;
  final String state;
  final VoidCallback? onSkip;
  final int? previousElapsedTime;

  const PreparationStepTileTest({
    super.key,
    required this.stepIndex,
    required this.preparationName,
    required this.preparationTime,
    required this.state,
    this.onSkip,
    this.previousElapsedTime,
  });

  @override
  _PreparationStepTileTestState createState() =>
      _PreparationStepTileTestState();
}

class _PreparationStepTileTestState extends State<PreparationStepTileTest> {
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
                widget.preparationTime, // yet 상태에서는 지정된 시간 표시
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
