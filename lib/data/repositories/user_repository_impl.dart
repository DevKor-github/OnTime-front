import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final AuthenticationRemoteDataSource _authenticationRemoteDataSource;
  final TokenLocalDataSource _tokenLocalDataSource;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
    forceCodeForRefreshToken: true,
  );
  late final _userStreamController = BehaviorSubject<UserEntity>.seeded(
    const UserEntity.empty(),
  );

  @override
  GoogleSignIn get googleSignIn => _googleSignIn;

  UserRepositoryImpl(
      this._authenticationRemoteDataSource, this._tokenLocalDataSource);

  @override
  Future<UserEntity> getUser() async {
    try {
      final user = await _authenticationRemoteDataSource.getUser();
      _userStreamController.add(user);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final result =
          await _authenticationRemoteDataSource.signIn(email, password);
      await _tokenLocalDataSource.storeTokens(result.$2);
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
          await _authenticationRemoteDataSource.signUp(email, password, name);
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(result.$1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _tokenLocalDataSource.deleteToken();
    _userStreamController.add(const UserEntity.empty());
  }

  @override
  Future<void> signInWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken != null) {
        final signInWithGoogleRequestModel = SignInWithGoogleRequestModel(
          idToken: idToken,
          refreshToken: '',
        );
        await _tokenLocalDataSource.deleteToken();
        final result = await _authenticationRemoteDataSource
            .signInWithGoogle(signInWithGoogleRequestModel);
        await _tokenLocalDataSource.storeTokens(result.$2);
        _userStreamController.add(result.$1);
      } else {
        throw Exception('Access Token is null');
      }
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) async {
    try {
      final signInWithAppleRequestModel = SignInWithAppleRequestModel(
        idToken: idToken,
        authCode: authCode,
        fullName: fullName,
        email: email,
      );
      await _tokenLocalDataSource.deleteToken();
      final result = await _authenticationRemoteDataSource
          .signInWithApple(signInWithAppleRequestModel);
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(result.$1);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _authenticationRemoteDataSource.deleteUser();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteGoogleUser() async {
    try {
      await _authenticationRemoteDataSource.deleteGoogleMe();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAppleUser() async {
    try {
      await _authenticationRemoteDataSource.deleteAppleMe();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> postFeedback(String message) async {
    try {
      await _authenticationRemoteDataSource.postFeedback(message);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String?> getUserSocialType() async {
    try {
      return await _authenticationRemoteDataSource.getUserSocialType();
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<UserEntity> get userStream =>
      _userStreamController.asBroadcastStream();
}
