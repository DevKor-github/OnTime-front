import 'package:flutter/material.dart';

class PreparationStep extends StatelessWidget {
  final String preparationName; // 준비 과정 이름
  final String preparationTime; // 준비 과정 시간 (분/초로 포맷)
  final String state;

  const PreparationStep({
    super.key,
    required this.preparationName,
    required this.preparationTime,
    required this.state,
  });

  // 상태에 따른 원 색상 및 테두리 반환
  BoxDecoration getCircleDecoration() {
    switch (state) {
      case 'prev':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xff5C79FB),
            width: 1,
          ),
        );

      case 'now':
        return const BoxDecoration(
          color: Color(0xff5C79FB),
          shape: BoxShape.circle,
        );

      case 'done':
        return const BoxDecoration(
          color: Color(0xffB0C4FB),
          shape: BoxShape.circle,
        );

      default:
        return BoxDecoration();
    }
  }

  // 상태에 따른 텍스트 색상 반환
  Color getTextColor() {
    switch (state) {
      case 'prev':
        return Colors.grey;

      case 'now':
        return const Color(0xff5C79FB);

      case 'done':
        return const Color(0xffB0C4FB);

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 329,
      height: 50,
      child: Stack(
        children: [
          // 그림자 애니메이션
          if (state == 'now')
            AnimatedOpacity(
              opacity: state == 'now' ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16, // 위아래 퍼짐
                      offset: const Offset(10, 2),
                    ),
                  ],
                ),
              ),
            ),
          // 실제 컴포넌트 내용
          Align(
            alignment: Alignment.center,
            child: Row(
              children: [
                // 원 컴포넌트
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 10,
                  height: 10,
                  decoration: getCircleDecoration(),
                ),
                const SizedBox(width: 6), // 간격
                // 텍스트와 시간
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                    decoration: BoxDecoration(
                      color: state == 'now' ? Colors.white : null,
                      borderRadius:
                          BorderRadius.circular(state == 'now' ? 8 : 0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 9),
                      child: Row(
                        children: [
                          // 준비 과정 이름
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                            style: TextStyle(
                              color: getTextColor(),
                              fontSize: state == 'now' ? 15 : 13,
                              fontWeight: state == 'now'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            child: Text(preparationName),
                          ),
                          const Spacer(),
                          // 준비 시간
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.ease,
                            style: TextStyle(
                              color: getTextColor(),
                              fontSize: state == 'now' ? 15 : 13,
                              fontWeight: state == 'now'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            child: Text(preparationTime),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
