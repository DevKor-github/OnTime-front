import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';

part 'app_event.dart';
part 'app_state.dart';

@Injectable()
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(this._streamUserUseCase, this._signOutUseCase, this._loadUserUseCase,
      this._getNearestUpcomingScheduleUseCase, this._navigationService)
      : super(AppState(user: const UserEntity.empty())) {
    on<AppUserSubscriptionRequested>(_appUserSubscriptionRequested);
    on<AppSignOutPressed>(_appLogoutPressed);
    on<AppUpcomingScheduleSubscriptionRequested>(
      _appUpcomingScheduleSubscriptionRequested,
    );
    on<AppUpcomingScheduleReceived>(
      _appUpcomingScheduleReceived,
    );
    on<AppPreparationStarted>(
      _appPreparationStarted,
    );
  }

  final StreamUserUseCase _streamUserUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  Timer? _timer;

  Future<void> _appUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    _loadUserUseCase();
    return emit.onEach(
      _streamUserUseCase.call(),
      onData: (user) async {
        emit(
          state.copyWith(
            user: user,
            status: user.map<AppStatus>(
              (entity) => entity.isOnboardingCompleted
                  ? AppStatus.authenticated
                  : AppStatus.onboardingNotCompleted,
              empty: (_) => AppStatus.unauthenticated,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 0));
        if (state.status == AppStatus.authenticated) {
          add(const AppUpcomingScheduleSubscriptionRequested());
        }
      },
      onError: addError,
    );
  }

  void _appLogoutPressed(
    AppSignOutPressed event,
    Emitter<AppState> emit,
  ) {
    _signOutUseCase();
  }

  /// This method is called when the user is authenticated and the app is
  /// waiting for the nearest upcoming schedule.
  FutureOr<void> _appUpcomingScheduleSubscriptionRequested(
      AppUpcomingScheduleSubscriptionRequested event,
      Emitter<AppState> emit) async {
    _getNearestUpcomingScheduleUseCase()
        .listen((schedule) => add(AppUpcomingScheduleReceived(schedule)));
  }

  /// This method is called when the nearest upcoming schedule is received.
  void _appUpcomingScheduleReceived(
      AppUpcomingScheduleReceived event, Emitter<AppState> emit) {
    final nearestUpcomingSchedule = event.nearestUpcomingSchedule;

    // If the app is in preparation started state, we only need to update the schedule.
    if (state.status == AppStatus.preparationStarted) {
      emit(
        state.copyWith(
          schedule: nearestUpcomingSchedule,
        ),
      );
      return;
    }

    // If there is no upcoming schedule or the schedule is in the past, the app
    if (nearestUpcomingSchedule == null ||
        nearestUpcomingSchedule.scheduleTime.isBefore(DateTime.now())) {
      emit(
        state.copyWith(
          status: AppStatus.authenticated,
        ),
      );
      return;
    }

    // If the preparation is ongoing, we need to update the state
    if (_isPreparationOnGoing(nearestUpcomingSchedule)) {
      emit(
        state.copyWith(
          status: AppStatus.preparationStarted,
          schedule: nearestUpcomingSchedule,
        ),
      );
      return;
    }

    // If the preparation is not ongoing, we need to set a timer for the preparation start time
    final durationUntilSchedule =
        nearestUpcomingSchedule.preparationStartTime.difference(DateTime.now());
    assert(!durationUntilSchedule.isNegative);
    _timer?.cancel();
    _timer = Timer(durationUntilSchedule, () {
      add(AppPreparationStarted(nearestUpcomingSchedule));
    });
    emit(
      state.copyWith(
        status: AppStatus.authenticated,
      ),
    );
  }

  bool _isPreparationOnGoing(
      ScheduleWithPreparationEntity nearestUpcomingSchedule) {
    return nearestUpcomingSchedule.preparationStartTime
            .isBefore(DateTime.now()) &&
        nearestUpcomingSchedule.scheduleTime.isAfter(DateTime.now());
  }

  void _appPreparationStarted(
      AppPreparationStarted event, Emitter<AppState> emit) async {
    _navigationService.push('/scheduleStart', extra: event.schedule);
    emit(
      state.copyWith(
        status: AppStatus.preparationStarted,
        schedule: event.schedule,
      ),
    );
  }
}
