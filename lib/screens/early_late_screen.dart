import 'package:flutter/material.dart';
import 'package:on_time_front/screens/early_late_messages.dart';
import 'package:on_time_front/widgets/button.dart';

class EarlyLateScreen extends StatefulWidget {
  final int earlyLateTime;
  const EarlyLateScreen({super.key, required this.earlyLateTime});

  @override
  State<EarlyLateScreen> createState() => _EarlyLateScreenState();
}

class _EarlyLateScreenState extends State<EarlyLateScreen> {
  List<bool> checklistStates = [false, false, false];

  late bool isLate;
  late int minuteValue;
  late String earlylateMessage;

  @override
  void initState() {
    super.initState();

    // 지각 여부 확인
    isLate = widget.earlyLateTime < 0;

    int absSeconds = widget.earlyLateTime.abs();
    minuteValue = (absSeconds / 60).ceil();

    // 지각/일찍 준비 문구 결정
    if (isLate) {
      // 지각
      earlylateMessage = getLateMessage();
    } else {
      // 일찍 준비
      earlylateMessage = getEarlyMessage(minuteValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final Color textColor =
        isLate ? const Color(0xffFF6953) : const Color(0xff5C79FB);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.1),
                child: Center(
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formatTime(widget.earlyLateTime),
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            TextSpan(
                              text: isLate ? ' 지각했어요' : ' 일찍 준비했어요',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      SizedBox(
                        width: 292,
                        child: Text(
                          earlylateMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.02),
                child: Image.asset(
                  'lib/images/ontime_mascot.png',
                  width: 150,
                  height: 150,
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
              Center(
                child: SizedBox(
                  width: screenWidth * 0.9,
                  height: screenHeight * 0.35,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xffF6F6F6),
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20), // 내부 여백
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
                        children: [
                          const Text(
                            '나가기 전에 확인하세요',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(
                              checklistStates.length,
                              (index) => Padding(
                                padding: EdgeInsets.only(
                                    bottom: screenHeight * 0.01),
                                child: _buildChecklistItem(
                                  index,
                                  "확인할 항목 ${index + 1}",
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Positioned를 이용한 버튼 배치
          Positioned(
            bottom: 20, // 하단에서 20px 떨어짐
            left: 0,
            right: 0,
            child: Center(
              child: Button(
                text: '까먹지 않고 출발',
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatTime(int seconds) {
    var time = seconds.abs();

    final int hours = time ~/ 3600;
    final int minutes = (time % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '$hours시간 $minutes분';
    } else {
      return '$minutes분';
    }
  }

  /// 체크리스트 아이템
  Widget _buildChecklistItem(int index, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          checklistStates[index] = !checklistStates[index]; // 체크 상태 토글
        });
      },
      child: Row(
        children: [
          // 체크박스 컨테이너
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(
                color: const Color(0xff5C79FB),
                width: 2,
              ),
              borderRadius: BorderRadius.all(Radius.circular(5)),
              color: checklistStates[index]
                  ? const Color(0xff5C79FB)
                  : Colors.transparent,
            ),
            child: checklistStates[index]
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          SizedBox(width: 15),
          // 체크박스 텍스트
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: checklistStates[index]
                  ? const Color(0xff5C79FB)
                  : Colors.black,
              decoration: checklistStates[index]
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
