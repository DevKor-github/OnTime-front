import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/delete_user_use_case.dart';

void main() {
  test('deletes normal accounts with feedback', () async {
    final repository = _FakeUserRepository(socialType: null);
    final useCase = DeleteUserUseCase(repository);

    await useCase('Too many notifications');

    expect(repository.deletedNormalFeedback, 'Too many notifications');
    expect(repository.deletedGoogleFeedback, isNull);
    expect(repository.deletedAppleFeedback, isNull);
  });

  test('deletes Google accounts through the Google revoke endpoint', () async {
    final repository = _FakeUserRepository(socialType: 'GOOGLE');
    final useCase = DeleteUserUseCase(repository);

    await useCase('Switching apps');

    expect(repository.deletedGoogleFeedback, 'Switching apps');
    expect(repository.didDisconnectGoogleSignIn, isTrue);
    expect(repository.deletedNormalFeedback, isNull);
  });

  test('deletes Apple accounts through the Apple revoke endpoint', () async {
    final repository = _FakeUserRepository(socialType: 'apple');
    final useCase = DeleteUserUseCase(repository);

    await useCase('Fresh start');

    expect(repository.deletedAppleFeedback, 'Fresh start');
    expect(repository.deletedNormalFeedback, isNull);
  });
}

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({required this.socialType});

  final String? socialType;
  String? deletedNormalFeedback;
  String? deletedGoogleFeedback;
  String? deletedAppleFeedback;
  bool didDisconnectGoogleSignIn = false;

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  GoogleSignIn get googleSignIn => throw UnimplementedError();

  @override
  Future<void> deleteAppleUser({String? feedbackMessage}) async {
    deletedAppleFeedback = feedbackMessage;
  }

  @override
  Future<void> deleteGoogleUser({String? feedbackMessage}) async {
    deletedGoogleFeedback = feedbackMessage;
  }

  @override
  Future<void> deleteUser({String? feedbackMessage}) async {
    deletedNormalFeedback = feedbackMessage;
  }

  @override
  Future<void> disconnectGoogleSignIn() async {
    didDisconnectGoogleSignIn = true;
  }

  @override
  Future<String?> getUserSocialType() async => socialType;

  @override
  Future<void> getUser() => throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();
}
