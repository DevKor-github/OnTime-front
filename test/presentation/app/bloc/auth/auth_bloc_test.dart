import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';

void main() {
  test('completed local profile is ready for the app', () {
    final state = AuthState(
      user: const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 10),
        note: '',
        isOnboardingCompleted: true,
      ),
    );

    expect(state.status, AuthStatus.authenticated);
  });

  test('empty or incomplete local profile starts onboarding', () {
    expect(AuthState().status, AuthStatus.onboardingNotCompleted);
    expect(
      AuthState(
        user: const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      ).status,
      AuthStatus.onboardingNotCompleted,
    );
  });
}
