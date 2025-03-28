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
      onData: (user) {
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
        if (user != UserEntity.empty()) {
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

  FutureOr<void> _appUpcomingScheduleSubscriptionRequested(
      AppUpcomingScheduleSubscriptionRequested event,
      Emitter<AppState> emit) async {
    _getNearestUpcomingScheduleUseCase()
        .listen((schedule) => add(AppUpcomingScheduleReceived(schedule)));
  }

  void _appUpcomingScheduleReceived(
      AppUpcomingScheduleReceived event, Emitter<AppState> emit) {
    final nearestUpcomingSchedule = event.nearestUpcomingSchedule;

    if (state.status == AppStatus.preparationStarted) {
      return;
    }

    if (nearestUpcomingSchedule == null ||
        nearestUpcomingSchedule.scheduleTime.isBefore(DateTime.now())) {
      emit(
        state.copyWith(
          status: AppStatus.authenticated,
        ),
      );
      return;
    }
    if (_isPreparationOnGoing(nearestUpcomingSchedule)) {
      emit(
        state.copyWith(
          status: AppStatus.preparationStarted,
          schedule: nearestUpcomingSchedule,
        ),
      );
      return;
    }

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
