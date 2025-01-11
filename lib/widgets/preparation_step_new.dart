import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';

class PreparationStepNew extends StatefulWidget {
  const PreparationStepNew({super.key});

  @override
  State<PreparationStepNew> createState() => _PreparationStepNewState();
}

class _PreparationStepNewState extends State<PreparationStepNew> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 358,
          height: 62,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
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
                      ),
                    ],
                  ),
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
