part of 'auth_bloc.dart';

enum AuthStatus { loading, authenticated, onboardingNotCompleted, recovery }

class AuthState extends Equatable {
  AuthState({UserEntity user = const UserEntity.empty()})
    : this._(
        status: user.map<AuthStatus>(
          (entity) => entity.isOnboardingCompleted
              ? AuthStatus.authenticated
              : AuthStatus.onboardingNotCompleted,
          empty: (_) => AuthStatus.onboardingNotCompleted,
        ),
        user: user,
      );

  const AuthState.loading()
    : this._(status: AuthStatus.loading, user: const UserEntity.empty());

  const AuthState.recovery()
    : this._(status: AuthStatus.recovery, user: const UserEntity.empty());

  const AuthState._({
    required this.status,
    this.user = const UserEntity.empty(),
  });

  final AuthStatus status;
  final UserEntity user;

  AuthState copyWith({AuthStatus? status, UserEntity? user}) {
    return AuthState._(status: status ?? this.status, user: user ?? this.user);
  }

  @override
  List<Object> get props => [status, user];
}
