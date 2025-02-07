import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';
import 'package:rxdart/subjects.dart';

@Injectable(as: AuthenticationRepository)
class AuthenticationRepositoryImpl implements AuthenticationRepository {
  final AuthenticationRemoteDataSource authenticationRemoteDataSource;
  final TokenLocalDataSource tokenLocalDataSource;
  late final _userStreamController = BehaviorSubject<UserEntity>.seeded(
    const UserEntity.empty(),
  );

  AuthenticationRepositoryImpl(
      this.authenticationRemoteDataSource, this.tokenLocalDataSource);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final result =
          await authenticationRemoteDataSource.signIn(email, password);
      await tokenLocalDataSource.storeToken(result.$2);
      _userStreamController.add(result.$1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signUp(
      {required String email,
      required String password,
      required String name}) async {
    try {
      final result =
          await authenticationRemoteDataSource.signUp(email, password, name);
      await tokenLocalDataSource.storeToken(result.$2);
      _userStreamController.add(result.$1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await tokenLocalDataSource.deleteToken();
    _userStreamController.add(const UserEntity.empty());
  }

  @override
  Future<void> signInWithGoogle() async {
    final GoogleSignIn _googleSignIn =
        GoogleSignIn(scopes: ['email', 'profile']);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? accessToken = googleAuth.accessToken;
        debugPrint('Access Token: $accessToken');
        debugPrint('idToken: ${googleAuth.idToken}');
        if (accessToken != null) {
        } else {
          throw Exception('Access Token is null');
        }
      } else {
        throw Exception('Google User is null');
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  @override
  Stream<UserEntity> get userStream =>
      _userStreamController.asBroadcastStream();
}
