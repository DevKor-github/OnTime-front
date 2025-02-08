import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:http/http.dart' as http;
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/preparation/bloc/alarm_screen_bloc.dart';
import 'package:on_time_front/presentation/preparation/screens/early_late_screen.dart';
import 'dart:convert';

import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/presentation/preparation/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/preparation/components/alarm_graph_component.dart';

import 'package:on_time_front/utils/time_format.dart';

class AlarmScreen extends StatefulWidget {
  final ScheduleEntity schedule; // 스케줄 데이터를 받음

  const AlarmScreen({
    super.key,
    required this.schedule,
  });

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  // 서버 통신용
  PreparationEntity? preparationEntity;
  late final PreparationRemoteDataSource preparationRemoteDataSource;

  // 준비 과정 목록 저장 변수
  List<PreparationStepEntity> preparationSteps = [];

  // 각 준비 단계의 경과 시간을 초 단위로 관리 (ui에서 필요함)
  List<int> elapsedTimes = [];

  int currentIndex = 0;
  int remainingTime = 0;

  int totalPreparationTime = 0; // 전체 준비 시간의 초기값. 기준 용. 변하지 않음.
  int totalRemainingTime = 0; // 타이머 용 전체 준비 시간. 시간에 따라 차감

  // 그래프 진행률 관련
  late List<double> preparationRatios;
  late List<bool> preparationCompleted;

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double currentProgress = 0.0; // 현재 진행률

  late bool isLate = false;

  // 준비과정 타이머
  Timer? preparationTimer;

  // 전체 시간 타이머 (~뒤에 나가야 해요)
  Timer? fullTimeTimer;

  // 전체시간 = 약속시간 - (이동시간 + 여유시간 + 현재시간)
  late int fullTime;

  @override
  void initState() {
    super.initState();

    // final dio = AppDio();
    preparationRemoteDataSource = PreparationRemoteDataSourceImpl(Dio());

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

  Future<void> fetchPreparations() async {
    try {
      final scheduleId = widget.schedule.id;
      final PreparationEntity fetchedData = await preparationRemoteDataSource
          .getPreparationByScheduleId(scheduleId);

      setState(() {
        preparationEntity = fetchedData;
        preparationSteps = fetchedData.preparationStepList;
        // 각 준비 단계에 대한 경과 시간 초기값 0으로 초기화 (서버에서 받아온 정보만 저장)
        elapsedTimes = List<int>.filled(preparationSteps.length, 0);
      });

      print("Fetched preparation steps: $preparationSteps");

      initializePreparationProcess();
    } catch (e) {
      print('Error fetching preparation data: $e');
      setState(() {
        preparationEntity = PreparationEntity(preparationStepList: []);
      });
    }
  }

  void initializePreparationProcess() {
    preparationRatios = [];
    preparationCompleted = List.filled(preparationSteps.length, false);

    // 전체 준비시간 타이머 초기화
    initializeTotalTime();

    // 준비과정 시간 비율 계산
    calculatePreparationRatios();

    // FullTime 타이머 시작
    startFullTimeTimer();

    // 첫 준비 과정 시작
    startPreparation();
  }

  // 전체 준비 시간 초기화
  void initializeTotalTime() {
    totalPreparationTime = preparationSteps.fold<int>(
      0,
      (sum, prep) => sum + prep.preparationTime.inSeconds,
    );
    totalRemainingTime = totalPreparationTime; // 초기 전체 시간 설정
  }

  // Fulltime 계산
  void calculateFullTime() {
    // 현재 시간
    final DateTime now = DateTime.now();

    // 여유시간
    final Duration spareTime = widget.schedule.scheduleSpareTime;

    // 약속시간
    final DateTime scheduleTime = widget.schedule.scheduleTime;

    // 이동시간
    final Duration moveTime = widget.schedule.moveTime;

    final Duration remainingDuration =
        scheduleTime.difference(now) - moveTime - spareTime;

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
    preparationRatios.clear(); // 기존에 저장된 비율이 있다면 초기화
    for (var step in preparationSteps) {
      final int prepTime = step.preparationTime.inSeconds; // Duration을 초 단위로 변환
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
      if (status == AnimationStatus.completed && mounted) {
        // 준비 종료 후 EarlyLateScreen으로 이동
        // context.go('/earlyLate', extra: fullTime);

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
    if (currentIndex < preparationSteps.length) {
      setState(() {
        // 준비과정 남은 시간 (감소)
        remainingTime =
            preparationSteps[currentIndex].preparationTime.inSeconds;

        // 각 준비과정 누적 시간 (증가)
        elapsedTimes[currentIndex] = 0;
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
            elapsedTimes[currentIndex] = elapsedTimes[currentIndex] + 1;
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
    if (currentIndex == preparationSteps.length - 1) {
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

    if (currentIndex + 1 < preparationSteps.length) {
      setState(() {
        currentIndex++;
      });

      startPreparation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 데이터가 준비되지 않았을 때 로딩 중 상태 처리
    if (preparationSteps.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPreparation = preparationSteps[currentIndex];

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
                  painter: AlarmGraphComponent(
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
                        currentPreparation.preparationName, // 준비 과정 이름
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
                    preparations: preparationSteps,
                    currentIndex: currentIndex,
                    onSkip: skipCurrentPreparation,
                    elapsedTimes: elapsedTimes,
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
