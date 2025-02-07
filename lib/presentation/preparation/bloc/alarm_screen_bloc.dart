import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

part 'alarm_screen_event.dart';
part 'alarm_screen_state.dart';

class AlarmScreenBloc extends Bloc<AlarmScreenEvent, AlarmScreenState> {
  int fullTime = 0;
  bool isLate = false;
  Timer? fullTimeTimer;

  double currentProgress = 0.0;
  int currentIndex = 0;
  int remainingTime = 0;
  int totalRemainingTime = 0;
  int totalPreparationTime = 0;
  Timer? preparationTimer;

  late List<dynamic> preparations;
  late List<bool> preparationCompleted;

  AlarmScreenBloc() : super(AlarmScreenInitial()) {
    on<InitializeTotalTime>((event, emit) {
      int totalPreparationTime = event.preparations.fold<int>(
        0,
        (sum, prep) => sum + (prep['preparationTime'] as int) * 60,
      );
      emit(TotalTimeInitialized(totalPreparationTime, totalPreparationTime));
    });

    on<CalculateFullTime>((event, emit) {
      final DateTime now = DateTime.now();
      final Duration spareTime =
          Duration(minutes: event.schedule['scheduleSpareTime']);
      final DateTime scheduleTime =
          DateTime.parse(event.schedule['scheduleTime']);
      final int moveTime = event.schedule['moveTime'];

      final Duration remainingDuration = scheduleTime.difference(now) -
          Duration(minutes: moveTime) -
          spareTime;

      fullTime = remainingDuration.inSeconds.toInt();
      isLate = fullTime < 0;

      emit(FullTimeCalculated(fullTime, isLate));
    });

    on<StartFullTimeTimer>((event, emit) {
      fullTimeTimer?.cancel();
      fullTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        fullTime--;
        if (fullTime < 0) {
          isLate = true;
        }
        emit(FullTimeTimerUpdated(fullTime, isLate));
      });
    });

    on<CalculatePreparationRatios>((event, emit) {
      List<double> preparationRatios = [];
      int cumulativeTime = 0;

      for (var preparation in event.preparations) {
        final int prepTime = preparation['preparationTime'] * 60;
        preparationRatios.add(cumulativeTime / event.totalPreparationTime);
        cumulativeTime += prepTime;
      }

      emit(PreparationRatiosCalculated(preparationRatios));
    });

    on<FinalizePreparation>((event, emit) {
      preparationTimer?.cancel();
      fullTimeTimer?.cancel();
      emit(ProgressUpdated(1.0));
    });

    on<UpdateProgress>((event, emit) {
      currentProgress = event.newProgress;
      emit(ProgressUpdated(currentProgress));
    });

    on<StartPreparation>((event, emit) {
      if (currentIndex < preparations.length) {
        remainingTime = preparations[currentIndex]['preparationTime'] * 60;
        preparations[currentIndex]['elapsedTime'] = 0;

        preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (remainingTime > 0) {
            remainingTime--;
            totalRemainingTime--;
            add(UpdateProgress(
                1.0 - (totalRemainingTime / totalPreparationTime)));

            preparations[currentIndex]['elapsedTime'] =
                (preparations[currentIndex]['elapsedTime'] as int) + 1;

            emit(PreparationStarted(remainingTime, totalRemainingTime));
          } else {
            timer.cancel();
            preparationCompleted[currentIndex] = true;
            add(MoveToNextPreparation());
          }
        });
      }
    });

    on<SkipCurrentPreparation>((event, emit) {
      preparationTimer?.cancel();

      if (currentIndex == preparations.length - 1) {
        add(UpdateProgress(1.0));

        totalRemainingTime -= remainingTime;
        preparationCompleted[currentIndex] = true;
        remainingTime = 0;

        add(FinalizePreparation());
      } else {
        totalRemainingTime -= remainingTime;
        preparationCompleted[currentIndex] = true;
        remainingTime = 0;
        add(UpdateProgress(1.0 - (totalRemainingTime / totalPreparationTime)));

        add(MoveToNextPreparation());
      }

      emit(PreparationSkipped());
    });

    on<MoveToNextPreparation>((event, emit) {
      preparationTimer?.cancel();

      if (currentIndex + 1 < preparations.length) {
        currentIndex++;
        add(StartPreparation());
      }

      emit(NextPreparationStarted());
    });

    on<FetchPreparations>((event, emit) async {
      emit(PreparationsLoading());

      try {
        final response = await http.get(
          Uri.parse(
              'https://ontime.devkor.club/schedule/get/preparation/${event.scheduleId}'),
          headers: {
            'accept': 'application/json',
            'Authorization':
                'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTczODg0NTU4NywiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.TkX8dJDrHkaV5Cs-DHqQ7Jq9tP7tBAXeeWlVH3avFDkZCNyVLh6j766Bn73KNwPDIbKU06jXxFhmghKjW48_pw',
          },
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            List<Map<String, dynamic>> preparations =
                List<Map<String, dynamic>>.from(data['data']);

            for (var prep in preparations) {
              prep['elapsedTime'] = 0;
            }

            emit(PreparationsLoaded(preparations));

            // BLoC 내에서 자동으로 초기화 이벤트 호출
            add(InitializeTotalTime(preparations));
            add(CalculatePreparationRatios(
                preparations,
                preparations.fold(
                    0,
                    (sum, prep) =>
                        sum + (prep['preparationTime'] as int) * 60)));
            add(StartFullTimeTimer());
            add(StartPreparation());
          } else {
            throw Exception('Data fetch failed: ${data['message']}');
          }
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        emit(PreparationsError('Error fetching preparation data: $e'));
      }
    });
  }

  @override
  Future<void> close() {
    fullTimeTimer?.cancel();
    preparationTimer?.cancel();
    return super.close();
  }
}
