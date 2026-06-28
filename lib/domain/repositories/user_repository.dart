import 'package:on_time_front/domain/entities/google_auth_credential.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class UserRepository {
  Stream<UserEntity> get userStream;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> signInWithGoogle(GoogleAuthCredential credential);

  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  });

  Future<void> getUser();

  Future<void> deleteUser({String? feedbackMessage});

  Future<void> deleteGoogleUser({String? feedbackMessage});

  Future<void> deleteAppleUser({String? feedbackMessage});

  Future<void> postFeedback(String message);

  Future<String?> getUserSocialType();

  Future<void> disconnectGoogleSignIn();
}
