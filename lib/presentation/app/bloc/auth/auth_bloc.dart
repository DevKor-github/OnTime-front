import 'dart:async';
import 'package:on_time_front/core/services/runtime_privacy_migration.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@Injectable()
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._streamUserUseCase,
    this._loadUserUseCase,
    this._scheduleBloc,
    this._reconcileAlarmsUseCase, [
    this._privacyMigration,
  ]) : super(const AuthState.loading()) {
    on<AuthUserSubscriptionRequested>(_appUserSubscriptionRequested);
  }

  final StreamUserUseCase _streamUserUseCase;
  final LoadUserUseCase _loadUserUseCase;
  final ScheduleBloc _scheduleBloc;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;
  final RuntimePrivacyMigration? _privacyMigration;
  Timer? _timer;

  Future<void> _appUserSubscriptionRequested(
    AuthUserSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _loadUserUseCase();
    } catch (error, stackTrace) {
      if (_privacyMigration != null) {
        try {
          await RuntimePrivacyMigration.clearLegacyWithoutDatabase();
        } catch (cleanupError, cleanupStack) {
          addError(cleanupError, cleanupStack);
        }
      }
      addError(error, stackTrace);
      emit(const AuthState.recovery());
      return;
    }

    try {
      await _privacyMigration?.run();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const AuthState.recovery());
      return;
    }

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
              empty: (_) => AuthStatus.onboardingNotCompleted,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 0));
        if (state.status == AuthStatus.authenticated) {
          _scheduleBloc.add(const ScheduleSubscriptionRequested());
          requestAlarmReconciliation(_reconcileAlarmsUseCase);
        }
      },
      onError: addError,
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
