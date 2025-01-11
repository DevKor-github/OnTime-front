import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';

class PreparationStepNewActive extends StatefulWidget {
  const PreparationStepNewActive({super.key});

  @override
  State<PreparationStepNewActive> createState() =>
      _PreparationStepNewActiveState();
}

class _PreparationStepNewActiveState extends State<PreparationStepNewActive> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 358,
          height: 135,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: Color(0xff5C79FB), width: 2),
              color: Colors.white,
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xffDCE3FF),
                            ),
                          ),
                          AnimatedDefaultTextStyle(
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff212F6F)),
                            duration: Duration(),
                            // child: Text("2"),
                            child: Icon(Icons.check),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: SizedBox(
                          height: 31,
                          child: Text(
                            '헤어',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                      SizedBox(
                        height: 31,
                        child: Text(
                          '20분',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff5C79FB),
                          ),
                        ),
                      )
                    ],
                  ),
                  // Button
                  Padding(
                    padding: EdgeInsets.only(top: 20),
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
                          // 필요한 동작
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
                  )
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 30),
          child: DottedLine(
            direction: Axis.vertical,
            lineLength: 23,
            lineThickness: 3,
            dashColor: Color(0xff5C79FB),
            dashLength: 4,
            dashGapLength: 5,
          ),
        )
      ],
    );
  }
}
