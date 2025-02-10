import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class AuthenticationRepository {
  Stream<UserEntity> get userStream;

  Future<void> signUp(
      {required String email, required String password, required String name});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> signInWithGoogle();

  Future<void> getUser();
}
