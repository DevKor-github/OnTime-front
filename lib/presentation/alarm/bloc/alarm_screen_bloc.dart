library;

import 'dart:async';
import 'package:bloc/bloc.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

part 'alarm_screen_event.dart';
part 'alarm_screen_state.dart';

class AlarmScreenBloc extends Bloc<AlarmScreenEvent, AlarmScreenState> {
  final String scheduleId;
  final ScheduleEntity schedule;
  final PreparationRemoteDataSource preparationRemoteDataSource;

  Timer? preparationTimer;
  Timer? fullTimeTimer;

  // 내부 상태 변수
  List<PreparationStepEntity> preparationSteps = [];
  List<int> elapsedTimes = [];
  int currentIndex = 0;
  int remainingTime = 0;
  int totalPreparationTime = 0;
  int totalRemainingTime = 0;
  double progress = 0.0;
  List<double> preparationRatios = [];
  List<bool> preparationCompleted = [];
  int fullTime = 0;
  bool isLate = false;

  AlarmScreenBloc({
    required this.scheduleId,
    required this.schedule,
    required this.preparationRemoteDataSource,
  }) : super(AlarmScreenInitial()) {
    on<AlarmScreenFetchPreparation>(_onFetchPreparation);
    on<AlarmScreenStartPreparation>(_onStartPreparation);
    on<AlarmScreenTick>(_onTick);
    on<AlarmScreenSkipPreparation>(_onSkipPreparation);
    on<AlarmScreenMoveToNextPreparation>(_onMoveToNextPreparation);
    on<AlarmScreenFinalizePreparation>(_onFinalizePreparation);
  }

  Future<void> _onFetchPreparation(
      AlarmScreenFetchPreparation event, Emitter<AlarmScreenState> emit) async {
    emit(AlarmScreenLoading());
    try {
      final PreparationEntity preparationEntity =
          await preparationRemoteDataSource
              .getPreparationByScheduleId(event.scheduleId);
      preparationSteps = preparationEntity.preparationStepList;
      elapsedTimes = List<int>.filled(preparationSteps.length, 0);
      totalPreparationTime = preparationSteps.fold(
          0, (sum, step) => sum + step.preparationTime.inSeconds);
      totalRemainingTime = totalPreparationTime;
      preparationCompleted = List<bool>.filled(preparationSteps.length, false);

      _calculatePreparationRatios();

      _calculateFullTime(schedule);

      remainingTime = preparationSteps[currentIndex].preparationTime.inSeconds;

      emit(AlarmScreenLoaded(
        preparationSteps: preparationSteps,
        elapsedTimes: elapsedTimes,
        currentIndex: currentIndex,
        remainingTime: remainingTime,
        totalPreparationTime: totalPreparationTime,
        totalRemainingTime: totalRemainingTime,
        progress: progress,
        preparationRatios: preparationRatios,
        preparationCompleted: preparationCompleted,
        fullTime: fullTime,
        isLate: isLate,
      ));
      add(const AlarmScreenStartPreparation());
    } catch (e) {
      emit(AlarmScreenError(e.toString()));
    }
  }

  Future<void> _onStartPreparation(
      AlarmScreenStartPreparation event, Emitter<AlarmScreenState> emit) async {
    if (currentIndex < preparationSteps.length) {
      remainingTime = preparationSteps[currentIndex].preparationTime.inSeconds;
      elapsedTimes[currentIndex] = 0;
      preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingTime > 0) {
          remainingTime--;
          totalRemainingTime--;
          elapsedTimes[currentIndex] += 1;
          progress = 1.0 - (totalRemainingTime / totalPreparationTime);
          add(const AlarmScreenTick());
        } else {
          timer.cancel();
          preparationCompleted[currentIndex] = true;
          add(const AlarmScreenMoveToNextPreparation());
        }
      });
    }
  }

  Future<void> _onTick(
      AlarmScreenTick event, Emitter<AlarmScreenState> emit) async {
    emit(AlarmScreenLoaded(
      preparationSteps: preparationSteps,
      elapsedTimes: elapsedTimes,
      currentIndex: currentIndex,
      remainingTime: remainingTime,
      totalPreparationTime: totalPreparationTime,
      totalRemainingTime: totalRemainingTime,
      progress: progress,
      preparationRatios: preparationRatios,
      preparationCompleted: preparationCompleted,
      fullTime: fullTime,
      isLate: isLate,
    ));
  }

  Future<void> _onSkipPreparation(
      AlarmScreenSkipPreparation event, Emitter<AlarmScreenState> emit) async {
    // 현재 타이머 취소
    preparationTimer?.cancel();

    // 현재 단계의 남은 시간을 차감하고 완료 처리
    totalRemainingTime -= remainingTime;
    preparationCompleted[currentIndex] = true;

    // 건너뛰기 시, currentIndex를 바로 증가시키고 다음 단계의 remainingTime 계산
    if (currentIndex + 1 < preparationSteps.length) {
      currentIndex++;
      // 다음 단계의 준비 시간
      remainingTime = preparationSteps[currentIndex].preparationTime.inSeconds;
      // 진행률 업데이트
      progress = 1.0 - (totalRemainingTime / totalPreparationTime);

      // 상태를 한 번에 업데이트하여 UI에 반영
      emit(AlarmScreenLoaded(
        preparationSteps: preparationSteps,
        elapsedTimes: elapsedTimes,
        currentIndex: currentIndex,
        remainingTime: remainingTime,
        totalPreparationTime: totalPreparationTime,
        totalRemainingTime: totalRemainingTime,
        progress: progress,
        preparationRatios: preparationRatios,
        preparationCompleted: preparationCompleted,
        fullTime: fullTime,
        isLate: isLate,
      ));

      // 다음 단계 시작 이벤트를 발생시켜 타이머 재시작
      add(const AlarmScreenStartPreparation());
    } else {
      // 만약 현재 단계가 마지막 단계라면, 바로 준비 종료 이벤트 처리
      add(const AlarmScreenFinalizePreparation());
    }
  }

  Future<void> _onMoveToNextPreparation(AlarmScreenMoveToNextPreparation event,
      Emitter<AlarmScreenState> emit) async {
    preparationTimer?.cancel();
    if (currentIndex + 1 < preparationSteps.length) {
      currentIndex++;
      add(const AlarmScreenStartPreparation());
    } else {
      add(const AlarmScreenFinalizePreparation());
    }
  }

  Future<void> _onFinalizePreparation(AlarmScreenFinalizePreparation event,
      Emitter<AlarmScreenState> emit) async {
    preparationTimer?.cancel();
    fullTimeTimer?.cancel();

    progress = 1.0;

    emit(AlarmScreenLoaded(
      preparationSteps: preparationSteps,
      elapsedTimes: elapsedTimes,
      currentIndex: currentIndex,
      remainingTime: remainingTime,
      totalPreparationTime: totalPreparationTime,
      totalRemainingTime: totalRemainingTime,
      progress: progress,
      preparationRatios: preparationRatios,
      preparationCompleted: preparationCompleted,
      fullTime: fullTime,
      isLate: isLate,
    ));

    // 애니메이션 완료용 딜레이
    await Future.delayed(const Duration(milliseconds: 550));

    emit(AlarmScreenFinalized(fullTime));
  }

  void _calculatePreparationRatios() {
    int cumulativeTime = 0;
    preparationRatios.clear();
    for (var step in preparationSteps) {
      final int prepTime = step.preparationTime.inSeconds;
      preparationRatios.add(cumulativeTime / totalPreparationTime);
      cumulativeTime += prepTime;
    }
  }

  void _calculateFullTime(ScheduleEntity schedule) {
    final DateTime now = DateTime.now();
    final Duration spareTime = schedule.scheduleSpareTime;
    final DateTime scheduleTime = schedule.scheduleTime;
    final Duration moveTime = schedule.moveTime;

    // 약속시간 - (현재시간 + 이동시간 + 여유시간) 계산
    final Duration remainingDuration =
        scheduleTime.difference(now) - moveTime - spareTime;

    fullTime = remainingDuration.inSeconds;

    if (fullTime < 0) {
      isLate = true;
    }
  }

  @override
  Future<void> close() {
    preparationTimer?.cancel();
    fullTimeTimer?.cancel();
    return super.close();
  }
}
