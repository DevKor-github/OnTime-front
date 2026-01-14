import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';

abstract interface class UserRepository {
  Stream<Result<UserEntity, Failure>> get userStream;

  GoogleSignIn get googleSignIn;

  Future<Result<Unit, Failure>> signUp(
      {required String email, required String password, required String name});

  Future<Result<Unit, Failure>> signIn(
      {required String email, required String password});

  Future<Result<Unit, Failure>> signOut();

  Future<Result<Unit, Failure>> signInWithGoogle(GoogleSignInAccount account);

  Future<Result<Unit, Failure>> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  });

  Future<Result<Unit, Failure>> getUser();

  Future<Result<Unit, Failure>> deleteUser();

  Future<Result<Unit, Failure>> deleteGoogleUser();

  Future<Result<Unit, Failure>> deleteAppleUser();

  Future<Result<Unit, Failure>> postFeedback(String message);

  Future<Result<String?, Failure>> getUserSocialType();

  Future<Result<Unit, Failure>> disconnectGoogleSignIn();
}
