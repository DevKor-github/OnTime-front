import 'dart:async';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  static const _googleServerClientId =
      '456571312261-5kuf2r6i5i7lqjr7qealv06sdgkn3hcp.apps.googleusercontent.com';
  static const _googleScopes = ['email', 'profile'];

  final AuthenticationRemoteDataSource _authenticationRemoteDataSource;
  final TokenLocalDataSource _tokenLocalDataSource;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleSignInInitialization;
  late final _userStreamController = BehaviorSubject<UserEntity>.seeded(
    const UserEntity.empty(),
  );

  @override
  Stream<GoogleSignInAuthenticationEvent> get googleAuthenticationEvents =>
      _googleSignIn.authenticationEvents;

  @override
  bool get supportsGoogleAuthenticate => _googleSignIn.supportsAuthenticate();

  UserRepositoryImpl(
    this._authenticationRemoteDataSource,
    this._tokenLocalDataSource,
  );

  @override
  Future<void> initializeGoogleSignIn() {
    return _googleSignInInitialization ??= _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    final lightweightAuthentication = _googleSignIn
        .attemptLightweightAuthentication();
    if (lightweightAuthentication != null) {
      unawaited(
        lightweightAuthentication.catchError((Object error) {
          AppLogger.debug('Google lightweight sign-in failed: $error');
          return null;
        }),
      );
    }
  }

  @override
  Future<GoogleSignInAccount> authenticateWithGoogle() async {
    await initializeGoogleSignIn();
    return _googleSignIn.authenticate(scopeHint: _googleScopes);
  }

  @override
  Future<UserEntity> getUser() async {
    try {
      final user = await _authenticationRemoteDataSource.getUser();
      _userStreamController.add(user);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _tokenLocalDataSource.deleteToken();
        _userStreamController.add(const UserEntity.empty());
        return const UserEntity.empty();
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final result = await _authenticationRemoteDataSource.signIn(
        email,
        password,
      );
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(result.$1);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final passwordError = PasswordPolicy.validate(password);
    if (passwordError != null) {
      throw ArgumentError.value(password, 'password', passwordError.name);
    }
    try {
      final result = await _authenticationRemoteDataSource.signUp(
        email,
        password,
        name,
      );
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
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Google ID Token is null');
      }
      final signInWithGoogleRequestModel = SignInWithGoogleRequestModel(
        idToken: idToken,
        refreshToken: '',
      );
      await _tokenLocalDataSource.deleteToken();
      final result = await _authenticationRemoteDataSource.signInWithGoogle(
        signInWithGoogleRequestModel,
      );
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(result.$1);
    } catch (error) {
      AppLogger.debug('Google Sign-In failed errorType=${error.runtimeType}');
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
      final result = await _authenticationRemoteDataSource.signInWithApple(
        signInWithAppleRequestModel,
      );
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(result.$1);
    } catch (error) {
      AppLogger.debug('Apple Sign-In failed errorType=${error.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser({String? feedbackMessage}) async {
    try {
      await _authenticationRemoteDataSource.deleteUser(
        feedbackMessage: feedbackMessage,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteGoogleUser({String? feedbackMessage}) async {
    try {
      await _authenticationRemoteDataSource.deleteGoogleMe(
        feedbackMessage: feedbackMessage,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAppleUser({String? feedbackMessage}) async {
    try {
      await _authenticationRemoteDataSource.deleteAppleMe(
        feedbackMessage: feedbackMessage,
      );
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
  Future<void> disconnectGoogleSignIn() async {
    try {
      await _googleSignIn.disconnect();
      AppLogger.debug('Google Sign-In disconnected');
    } catch (error) {
      AppLogger.debug(
        'Google Sign-In disconnect failed errorType=${error.runtimeType}',
      );
    }
  }

  @override
  Stream<UserEntity> get userStream =>
      _userStreamController.asBroadcastStream();
}
