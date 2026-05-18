import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/onboard_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';

void main() {
  test('LoadUserUseCase refreshes the current user', () async {
    final repository = _FakeUserRepository();

    await LoadUserUseCase(repository)();

    expect(repository.getUserCount, 1);
  });

  test('StreamUserUseCase exposes the repository user stream', () async {
    final repository = _FakeUserRepository();
    final user = _user('user-1');

    repository.emit(user);

    expect(await StreamUserUseCase(repository)().first, user);
  });

  test('OnboardUseCase creates defaults before refreshing the user', () async {
    final preparationRepository = _FakePreparationRepository();
    final userRepository = _FakeUserRepository();
    final preparation = _preparation('prep-1');

    await OnboardUseCase(preparationRepository, userRepository)(
      preparationEntity: preparation,
      spareTime: const Duration(minutes: 15),
      note: 'Need shoes',
    );

    expect(preparationRepository.createdDefaults, [
      (preparation, const Duration(minutes: 15), 'Need shoes'),
    ]);
    expect(userRepository.getUserCount, 1);
    expect(userRepository.events, ['getUser']);
  });
}

class _FakeUserRepository implements UserRepository {
  final _controller = Stream<UserEntity>.empty().asBroadcastStream();
  final emittedUsers = <UserEntity>[];
  final events = <String>[];
  int getUserCount = 0;

  @override
  Stream<UserEntity> get userStream async* {
    for (final user in emittedUsers) {
      yield user;
    }
    yield* _controller;
  }

  void emit(UserEntity user) {
    emittedUsers.add(user);
  }

  @override
  Stream<GoogleSignInAuthenticationEvent> get googleAuthenticationEvents =>
      const Stream.empty();

  @override
  bool get supportsGoogleAuthenticate => false;

  @override
  Future<GoogleSignInAccount> authenticateWithGoogle() =>
      throw UnimplementedError();

  @override
  Future<void> getUser() async {
    getUserCount += 1;
    events.add('getUser');
  }

  @override
  Future<void> initializeGoogleSignIn() async {}

  @override
  Future<void> deleteAppleUser({String? feedbackMessage}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteGoogleUser({String? feedbackMessage}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteUser({String? feedbackMessage}) =>
      throw UnimplementedError();

  @override
  Future<void> disconnectGoogleSignIn() => throw UnimplementedError();

  @override
  Future<String?> getUserSocialType() => throw UnimplementedError();

  @override
  Future<void> postFeedback(String message) => throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) => throw UnimplementedError();

  @override
  Future<void> signInWithGoogle(GoogleSignInAccount account) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) => throw UnimplementedError();
}

class _FakePreparationRepository implements PreparationRepository {
  final createdDefaults = <(PreparationEntity, Duration, String)>[];

  @override
  Stream<Map<String, PreparationEntity>> get preparationStream =>
      const Stream.empty();

  @override
  Future<void> createDefaultPreparation({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {
    createdDefaults.add((preparationEntity, spareTime, note));
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) => throw UnimplementedError();

  @override
  Future<PreparationEntity> getDefualtPreparation() =>
      throw UnimplementedError();

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) =>
      throw UnimplementedError();

  @override
  Future<void> updateDefaultPreparation(PreparationEntity preparationEntity) =>
      throw UnimplementedError();

  @override
  Future<void> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) => throw UnimplementedError();

  @override
  Future<void> updateSpareTime(Duration newSpareTime) =>
      throw UnimplementedError();
}

PreparationEntity _preparation(String id) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: id,
        preparationName: 'Pack',
        preparationTime: const Duration(minutes: 5),
      ),
    ],
  );
}

UserEntity _user(String id) {
  return UserEntity(
    id: id,
    email: '$id@example.com',
    name: 'Test User',
    spareTime: const Duration(minutes: 10),
    note: 'note',
    score: 1,
  );
}
