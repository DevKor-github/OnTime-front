import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

@Injectable()
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc(this._getNearestUpcomingScheduleUseCase)
      : super(const ScheduleState.initial()) {
    on<ScheduleSubscriptionRequested>(_onSubscriptionRequested);
    on<ScheduleUpcomingReceived>(_onUpcomingReceived);
    on<ScheduleStarted>(_onScheduleStarted);
  }

  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;
  Timer? _scheduleStartTimer;
  String? _currentScheduleId;

  Future<void> _onSubscriptionRequested(
      ScheduleSubscriptionRequested event, Emitter<ScheduleState> emit) async {
    await _upcomingScheduleSubscription?.cancel();
    _upcomingScheduleSubscription =
        _getNearestUpcomingScheduleUseCase().listen((upcomingSchedule) {
      // ✅ Safety check: Only add events if bloc is still active
      if (!isClosed) {
        add(ScheduleUpcomingReceived(upcomingSchedule));
      }
    });
  }

  Future<void> _onUpcomingReceived(
      ScheduleUpcomingReceived event, Emitter<ScheduleState> emit) async {
    // Cancel any existing timer
    _scheduleStartTimer?.cancel();
    _scheduleStartTimer = null;

    if (event.upcomingSchedule == null ||
        event.upcomingSchedule!.scheduleTime.isBefore(DateTime.now())) {
      emit(const ScheduleState.notExists());
      _currentScheduleId = null;
    } else if (_isPreparationOnGoing(event.upcomingSchedule!)) {
      emit(ScheduleState.ongoing(event.upcomingSchedule!));
      _currentScheduleId = event.upcomingSchedule!.id;
      _startScheduleTimer(event.upcomingSchedule!);
    } else {
      emit(ScheduleState.upcoming(event.upcomingSchedule!));
      _currentScheduleId = event.upcomingSchedule!.id;
      _startScheduleTimer(event.upcomingSchedule!);
    }
  }

  Future<void> _onScheduleStarted(
      ScheduleStarted event, Emitter<ScheduleState> emit) async {
    // Only process if this event is for the current schedule
    if (state.schedule != null && state.schedule!.id == _currentScheduleId) {
      // Mark the schedule as started by updating the state
      emit(ScheduleState.started(state.schedule!));
    }
  }

  void _startScheduleTimer(ScheduleWithPreparationEntity schedule) {
    final now = DateTime.now();
    final scheduleTime = schedule.scheduleTime;

    // Calculate time until the next minute boundary at schedule time
    final targetTime = DateTime(
      scheduleTime.year,
      scheduleTime.month,
      scheduleTime.day,
      scheduleTime.hour,
      scheduleTime.minute,
      0, // Always trigger at 00 seconds
      0, // 0 milliseconds
    );

    // If the target time is in the past or now, don't set a timer
    if (targetTime.isBefore(now) || targetTime.isAtSameMomentAs(now)) {
      return;
    }

    final duration = targetTime.difference(now);

    _scheduleStartTimer = Timer(duration, () {
      // Only add event if bloc is still active and schedule ID matches
      if (!isClosed && _currentScheduleId == schedule.id) {
        add(const ScheduleStarted());
      }
    });
  }

  @override
  Future<void> close() {
    // ✅ Proper cleanup: Cancel subscription and timer before closing
    _upcomingScheduleSubscription?.cancel();
    _scheduleStartTimer?.cancel();
    return super.close();
  }

  bool _isPreparationOnGoing(
      ScheduleWithPreparationEntity nearestUpcomingSchedule) {
    return nearestUpcomingSchedule.preparationStartTime
            .isBefore(DateTime.now()) &&
        nearestUpcomingSchedule.scheduleTime.isAfter(DateTime.now());
  }
}
