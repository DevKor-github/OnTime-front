import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

@Injectable()
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(this._authenticationRepository)
      : super(AppState(user: const UserEntity.empty())) {
    on<AppUserSubscriptionRequested>(_appUserSubscriptionRequested);
    on<AppLogoutPressed>(_appLogoutPressed);
  }

  final AuthenticationRepository _authenticationRepository;

  Future<void> _appUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    return emit.onEach(
      _authenticationRepository.userStream,
      onData: (user) => emit(
        state.copyWith(
          user: user,
        ),
      ),
      onError: addError,
    );
  }

  void _appLogoutPressed(
    AppLogoutPressed event,
    Emitter<AppState> emit,
  ) {
    _authenticationRepository.signOut();
  }
}
