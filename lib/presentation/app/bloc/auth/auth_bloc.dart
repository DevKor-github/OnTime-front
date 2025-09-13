import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@Injectable()
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._streamUserUseCase, this._signOutUseCase, this._loadUserUseCase,
      this._scheduleBloc)
      : super(AuthState(user: const UserEntity.empty())) {
    on<AuthUserSubscriptionRequested>(_appUserSubscriptionRequested);
    on<AuthSignOutPressed>(_appLogoutPressed);
  }

  final StreamUserUseCase _streamUserUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final SignOutUseCase _signOutUseCase;
  final ScheduleBloc _scheduleBloc;
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
          _scheduleBloc.add(const ScheduleSubscriptionRequested());
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

  @override
  Future<void> close() {
    _timer?.cancel();
    _upcomingScheduleSubscription?.cancel();
    return super.close();
  }
}
