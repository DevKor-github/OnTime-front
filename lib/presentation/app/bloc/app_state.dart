part of 'app_bloc.dart';

enum AppStatus {
  authenticated,
  unauthenticated,
  preparationStarted,
  onboardingNotCompleted,
}

class AppState extends Equatable {
  AppState({UserEntity user = const UserEntity.empty()})
      : this._(
          status: user.map<AppStatus>(
            (entity) => entity.isOnboardingCompleted
                ? AppStatus.unauthenticated
                : AppStatus.onboardingNotCompleted,
            empty: (_) => AppStatus.unauthenticated,
          ),
          user: user,
        );

  const AppState._(
      {required this.status,
      this.user = const UserEntity.empty(),
      this.schedule});

  final AppStatus status;
  final UserEntity user;
  final ScheduleWithPreparationEntity? schedule;

  AppState copyWith(
      {AppStatus? status,
      UserEntity? user,
      ScheduleWithPreparationEntity? schedule}) {
    return AppState._(
      status: status ?? this.status,
      user: user ?? this.user,
      schedule: schedule ?? this.schedule,
    );
  }

  @override
  List<Object> get props => [status, user];
}
