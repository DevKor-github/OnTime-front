import 'dart:async';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:on_time_front/presentation/preparation/screens/early_late_screen.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_timer/button.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_timer/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_timer/arc_painter_no_marker.dart';

import 'package:on_time_front/utils/time_format.dart';

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> schedule; // 스케줄 데이터를 받음

  const AlarmScreen({
    super.key,
    required this.schedule,
  });

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late List<dynamic> preparations = [];

  // 그래프 진행률 관련
  late List<double> preparationRatios;
  late List<bool> preparationCompleted;

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double currentProgress = 0.0; // 현재 진행률

  late bool isLate = false;

  int currentIndex = 0;
  int remainingTime = 0;

  int totalPreparationTime = 0; // 전체 준비 시간의 초기값. 기준 용. 변하지 않음.
  int totalRemainingTime = 0; // 타이머 용 전체 준비 시간. 시간에 따라 차감

  // 준비과정 타이머
  Timer? preparationTimer;

  // 전체 시간 타이머 (~뒤에 나가야 해요)
  Timer? fullTimeTimer;

  // 전체시간 = 약속시간 - (이동시간 + 여유시간 + 현재시간)
  late int fullTime;

  @override
  void initState() {
    super.initState();

    // 준비과정 가져오기
    fetchPreparations();

    // FullTime 계산 초기화
    calculateFullTime();

    // AnimationController 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
        setState(() {
          currentProgress = _progressAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    preparationTimer?.cancel();
    fullTimeTimer?.cancel();
    super.dispose();
  }

  // 서버에서 준비과정 가져오기
  Future<void> fetchPreparations() async {
    try {
      // final response = await http.get(
      //   Uri.parse('http://ejun.kro.kr:8888/preparationuser/show/all'),
      //   headers: {
      //     'accept': 'application/json',
      //     'Authorization':
      //         'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTc3MzU0Nzk3NywiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.JAEIeG6HdfpbJJ2d-NVzw8Kb3PobxaaW0pgoMaId3cviJ18B1nug7brMcFMUook2Dxq5Q-NijM_FMiaQTpdz0w',
      //   },
      // );

      final scheduleId = widget.schedule['scheduleId'];
      final response = await http.get(
        Uri.parse(
            'http://ejun.kro.kr:8888/schedule/get/preparation/$scheduleId'),
        headers: {
          'accept': 'application/json',
          'Authorization':
              'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTc3MzU0Nzk3NywiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.JAEIeG6HdfpbJJ2d-NVzw8Kb3PobxaaW0pgoMaId3cviJ18B1nug7brMcFMUook2Dxq5Q-NijM_FMiaQTpdz0w',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            preparations = List<Map<String, dynamic>>.from(data['data']);
          });

          for (var prep in preparations) {
            prep['elapsedTime'] = 0;
          }

          preparationRatios = [];
          preparationCompleted = List.filled(preparations.length, false);

          // 전체 준비시간 타이머 초기화
          initializeTotalTime();

          // 준비과정 시간 비율 계산
          calculatePreparationRatios();

          // FullTime 타이머 시작
          startFullTimeTimer();

          // 첫 준비 과정 시작
          startPreparation();
        } else {
          throw Exception('Data fetch failedL ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching preparation data: $e');
      setState(() {
        preparations = [];
      });
    }
  }

  // 전체 준비 시간 초기화
  void initializeTotalTime() {
    totalPreparationTime = preparations.fold<int>(
      0,
      (sum, prep) => sum + (prep['preparationTime'] as int) * 60,
    );
    totalRemainingTime = totalPreparationTime; // 초기 전체 시간 설정
  }

  // Fulltime 계산
  void calculateFullTime() {
    // 현재 시간
    final DateTime now = DateTime.now();

    // 여유시간
    final Duration spareTime =
        Duration(minutes: widget.schedule['scheduleSpareTime']);

    // 약속시간
    final DateTime scheduleTime =
        DateTime.parse(widget.schedule['scheduleTime']);

    // 이동시간
    final int moveTime = widget.schedule['moveTime'];

    final Duration remainingDuration =
        scheduleTime.difference(now) - Duration(minutes: moveTime) - spareTime;

    fullTime = remainingDuration.inSeconds.toInt();

    if (fullTime < 0) {
      isLate = true;
    }
  }

  // 전체 시간 타이머
  void startFullTimeTimer() {
    fullTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fullTime--;
      if (fullTime < 0) {
        isLate = true;
      }
    });
  }

  void calculatePreparationRatios() {
    int cumulativeTime = 0;
    for (var preparation in preparations) {
      final int prepTime = preparation['preparationTime'] * 60;
      preparationRatios.add(cumulativeTime / totalPreparationTime);
      cumulativeTime += prepTime;
    }
  }

  // 준비 종료 (준비 종료 버튼 클릭 시 호출)
  void finalizePreparation() {
    preparationTimer?.cancel();
    fullTimeTimer?.cancel();

    // 그래프 0으로 줄이기
    setState(() {
      updateProgress(1.0);
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 준비 종료 후 EarlyLateScreen으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EarlyLateScreen(
              earlyLateTime: fullTime,
            ),
          ),
        );
      }
    });
  }

  // 진행률 애니메이션 갱신
  void updateProgress(double newProgress) {
    _progressAnimation = Tween<double>(
      begin: currentProgress, // 현재 진행 상태에서 시작
      end: newProgress, // 다음 목표 진행 상태로 끝
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController
      ..reset()
      ..forward().then((_) {
        setState(() {
          currentProgress = newProgress;
        });
      });
  }

  // 준비 과정 시작
  void startPreparation() {
    if (currentIndex < preparations.length) {
      setState(() {
        // 준비과정 남은 시간 (감소)
        remainingTime = preparations[currentIndex]['preparationTime'] * 60;

        // 각 준비과정 누적 시간 (증가)
        preparations[currentIndex]['elapsedTime'] = 0;
      });

      // 타이머 시작
      preparationTimer =
          Timer.periodic(const Duration(seconds: 1), (preparationTimer) {
        if (remainingTime > 0) {
          setState(() {
            // 준비과정 남은 시간 차감
            remainingTime--;
            totalRemainingTime--;
            updateProgress(1.0 - (totalRemainingTime / totalPreparationTime));

            // 준비과정 누적 시간 증가
            preparations[currentIndex]['elapsedTime'] =
                (preparations[currentIndex]['elapsedTime'] as int) + 1;
          });
        } else {
          preparationTimer.cancel(); // 타이머 종료
          preparationCompleted[currentIndex] = true; // 해당 준비 과정 완료 표시
          moveToNextPreparation(); // 다음 준비 과정으로 이동
        }
      });
    }
  }

  // 건너뛰기
  void skipCurrentPreparation() {
    preparationTimer?.cancel();

    // 마지막 목록시 즉시 채워지는 효과
    if (currentIndex == preparations.length - 1) {
      final newProgress = 1.0;
      setState(() {
        updateProgress(newProgress);
      });

      _animationController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            totalRemainingTime -= remainingTime;
            preparationCompleted[currentIndex] = true;
            remainingTime = 0;
          });
          finalizePreparation();
        }
      });
    } else {
      // 건너뛰기 시 그래프 채워짐
      setState(() {
        totalRemainingTime -= remainingTime;
        preparationCompleted[currentIndex] = true;
        remainingTime = 0;
        updateProgress(1.0 - (totalRemainingTime / totalPreparationTime));
      });
      moveToNextPreparation();
    }
  }

  // 다음 준비 과정 시작
  void moveToNextPreparation() {
    preparationTimer?.cancel();

    if (currentIndex + 1 < preparations.length) {
      setState(() {
        currentIndex++;
      });

      startPreparation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 데이터가 준비되지 않았을 때 로딩 중 상태 처리
    if (preparations.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPreparation = preparations[currentIndex];

    return Scaffold(
      backgroundColor: Color(0xff5C79FB),
      body: Column(
        children: [
          // (1) 상단 여백 + 텍스트
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: Column(
              children: [
                Text(
                  isLate
                      ? '지각이에요!'
                      : '${formatTime(fullTime)} 뒤에 나가야 해요', // 총 준비 시간 표시
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // 타이머 그래프
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(230, 115), // 호의 크기 조정
                  painter: ArcPainterNoMarker(
                    progress: currentProgress,
                    preparationRatios: preparationRatios,
                    preparationCompleted: preparationCompleted,
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentPreparation['preparationName'], // 준비 과정 이름
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffDCE3FF)),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Text(
                        formatTimeTimer(remainingTime), // 남은 시간 표시
                        style: const TextStyle(
                          fontSize: 35,
                          color: Color(0xffFFFFFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 110),

          // 화면 하단 - 목록 표시 및 종료 버튼
          Expanded(
            child: Stack(
              children: [
                // 하단 배경
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffF6F6F6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                ),
                // 준비 과정 목록
                Positioned(
                  top: 15,
                  left: MediaQuery.of(context).size.width * 0.06,
                  right: MediaQuery.of(context).size.width * 0.06,
                  bottom: 100,
                  child: PreparationStepListWidget(
                    preparations: preparations,
                    currentIndex: currentIndex,
                    onSkip: skipCurrentPreparation,
                  ),
                ),

                // 하단 준비 종료 버튼
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 90,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Button(
                            text: '준비 종료',
                            onPressed: () {
                              finalizePreparation();
                            },
                          ),
                        ),
                      )
                    ],
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
