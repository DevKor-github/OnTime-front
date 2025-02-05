// alarm_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'alarm_event.dart';
import 'alarm_state.dart';

class AlarmBloc extends Bloc<AlarmEvent, AlarmState> {
  late int totalPreparationTime;
  late int totalRemainingTime;
  late double currentProgress;
  late Timer preparationTimer;
  late int remainingTime;
  late List<dynamic> preparations;
  late int currentIndex;

  AlarmBloc() : super(AlarmInitialState());

  Stream<AlarmState> _mapStartPreparationToState(
      StartPreparationEvent event) async* {
    // 준비 상태로 전환
    yield AlarmPreparingState(
      preparations: event.preparations,
      currentProgress: 0.0,
      remainingTime: 0,
    );
  }

  Stream<AlarmState> _mapPreparationInProgressToState(
      PreparationInProgressEvent event) async* {
    // 준비 진행 중 상태로 전환
    yield AlarmInProgressState(
      currentProgress: event.currentProgress,
      remainingTime: event.remainingTime,
    );
  }

  Stream<AlarmState> _mapFinalizePreparationToState() async* {
    // 준비 완료 상태로 전환
    yield AlarmFinalizedState(resultMessage: '준비 완료!');
  }
}
