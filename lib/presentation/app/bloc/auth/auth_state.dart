part of 'auth_bloc.dart';

enum AuthStatus {
  authenticated,
  unauthenticated,
  onboardingNotCompleted,
}

class AuthState extends Equatable {
  AuthState({UserEntity user = const UserEntity.empty()})
      : this._(
          status: user.map<AuthStatus>(
            (entity) => entity.isOnboardingCompleted
                ? AuthStatus.unauthenticated
                : AuthStatus.onboardingNotCompleted,
            empty: (_) => AuthStatus.unauthenticated,
          ),
          user: user,
        );

  const AuthState._(
      {required this.status,
      this.user = const UserEntity.empty(),
      this.schedule});

  final AuthStatus status;
  final UserEntity user;
  final ScheduleWithPreparationEntity? schedule;

  AuthState copyWith(
      {AuthStatus? status,
      UserEntity? user,
      ScheduleWithPreparationEntity? schedule}) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  List<Object> get props => [status, user];
}
