import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';

part 'app_event.dart';
part 'app_state.dart';

@Injectable()
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(this._streamUserUseCase, this._signOutUseCase, this._loadUserUseCase)
      : super(AppState(user: const UserEntity.empty())) {
    on<AppUserSubscriptionRequested>(_appUserSubscriptionRequested);
    on<AppSignOutPressed>(_appLogoutPressed);
  }

  final StreamUserUseCase _streamUserUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final SignOutUseCase _signOutUseCase;

  Future<void> _appUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    _loadUserUseCase();
    return emit.onEach(
      _streamUserUseCase.call(),
      onData: (user) => emit(
        state.copyWith(
          user: user,
          status: user.map(
              (e) => e.isOnboardingCompleted
                  ? AppStatus.authenticated
                  : AppStatus.onboardingNotCompleted,
              empty: (_) => AppStatus.unauthenticated),
        ),
      ),
      onError: addError,
    );
  }

  void _appLogoutPressed(
    AppSignOutPressed event,
    Emitter<AppState> emit,
  ) {
    _signOutUseCase();
  }
}
