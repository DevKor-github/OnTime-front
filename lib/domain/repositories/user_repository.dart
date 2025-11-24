import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class UserRepository {
  Stream<UserEntity> get userStream;

  GoogleSignIn get googleSignIn;

  Future<void> signUp(
      {required String email, required String password, required String name});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> signInWithGoogle(GoogleSignInAccount account);

  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  });

  Future<void> getUser();

  Future<void> deleteUser();

  Future<void> deleteGoogleUser();

  Future<void> deleteAppleUser();

  Future<void> postFeedback(String message);

  Future<String?> getUserSocialType();

  Future<void> disconnectGoogleSignIn();
}
