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

part 'auth_event.dart';
part 'auth_state.dart';

@Injectable()
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._streamUserUseCase, this._signOutUseCase, this._loadUserUseCase,
      this._getNearestUpcomingScheduleUseCase, this._navigationService)
      : super(AuthState(user: const UserEntity.empty())) {
    on<AuthUserSubscriptionRequested>(_appUserSubscriptionRequested);
    on<AuthSignOutPressed>(_appLogoutPressed);
    on<AuthUpcomingScheduleSubscriptionRequested>(
      _appUpcomingScheduleSubscriptionRequested,
    );
    on<AuthUpcomingScheduleReceived>(
      _appUpcomingScheduleReceived,
    );
    on<AuthPreparationStarted>(
      _appPreparationStarted,
    );
  }

  final StreamUserUseCase _streamUserUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetNearestUpcomingScheduleUseCase _getNearestUpcomingScheduleUseCase;
  final NavigationService _navigationService;
  Timer? _timer;
  StreamSubscription<ScheduleWithPreparationEntity?>?
      _upcomingScheduleSubscription;

  Future<void> _appUserSubscriptionRequested(
    AuthUserSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) {
    _loadUserUseCase();
    return emit.onEach(
      _streamUserUseCase.call(),
      onData: (user) async {
        emit(
          state.copyWith(
            user: user,
            status: user.map<AuthStatus>(
              (entity) => entity.isOnboardingCompleted
                  ? AuthStatus.authenticated
                  : AuthStatus.onboardingNotCompleted,
              empty: (_) => AuthStatus.unauthenticated,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 0));
        if (state.status == AuthStatus.authenticated) {
          add(const AuthUpcomingScheduleSubscriptionRequested());
        }
      },
      onError: addError,
    );
  }

  void _appLogoutPressed(
    AuthSignOutPressed event,
    Emitter<AuthState> emit,
  ) {
    _signOutUseCase();
  }

  /// This method is called when the user is authenticated and the app is
  /// waiting for the nearest upcoming schedule.
  FutureOr<void> _appUpcomingScheduleSubscriptionRequested(
      AuthUpcomingScheduleSubscriptionRequested event,
      Emitter<AuthState> emit) async {
    await _upcomingScheduleSubscription?.cancel();
    _upcomingScheduleSubscription = _getNearestUpcomingScheduleUseCase()
        .listen((schedule) => add(AuthUpcomingScheduleReceived(schedule)));
  }

  /// This method is called when the nearest upcoming schedule is received.
  void _appUpcomingScheduleReceived(
      AuthUpcomingScheduleReceived event, Emitter<AuthState> emit) {
    final nearestUpcomingSchedule = event.nearestUpcomingSchedule;

    // If the app is in preparation started state, we only need to update the schedule.
    if (state.status == AuthStatus.preparationStarted) {
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
          status: AuthStatus.authenticated,
        ),
      );
      return;
    }

    // If the preparation is ongoing, we need to update the state
    if (_isPreparationOnGoing(nearestUpcomingSchedule)) {
      emit(
        state.copyWith(
          status: AuthStatus.preparationStarted,
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
      add(AuthPreparationStarted(nearestUpcomingSchedule));
    });
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
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
      AuthPreparationStarted event, Emitter<AuthState> emit) async {
    _navigationService.push('/scheduleStart', extra: event.schedule);
    emit(
      state.copyWith(
        status: AuthStatus.preparationStarted,
        schedule: event.schedule,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _upcomingScheduleSubscription?.cancel();
    return super.close();
  }
}
