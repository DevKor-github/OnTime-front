import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/data/errors/exception_to_failure_mapper.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final AuthenticationRemoteDataSource _authenticationRemoteDataSource;
  final TokenLocalDataSource _tokenLocalDataSource;
  final ErrorLoggerService _errorLogger;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
    forceCodeForRefreshToken: true,
  );
  late final _userStreamController =
      BehaviorSubject<Result<UserEntity, Failure>>.seeded(
    Success(const UserEntity.empty()),
  );

  @override
  GoogleSignIn get googleSignIn => _googleSignIn;

  UserRepositoryImpl(
    this._authenticationRemoteDataSource,
    this._tokenLocalDataSource,
    ErrorLoggerService errorLoggerService,
  ) : _errorLogger = errorLoggerService;

  @override
  Future<Result<Unit, Failure>> getUser() async {
    try {
      final user = await _authenticationRemoteDataSource.getUser();
      _userStreamController.add(Success(user));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getUser');
      _userStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> signIn(
      {required String email, required String password}) async {
    try {
      final result =
          await _authenticationRemoteDataSource.signIn(email, password);
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(Success(result.$1));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'signIn');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> signUp(
      {required String email,
      required String password,
      required String name}) async {
    try {
      final result =
          await _authenticationRemoteDataSource.signUp(email, password, name);
      await _tokenLocalDataSource.storeTokens(result.$2);
      _userStreamController.add(Success(result.$1));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'signUp');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> signOut() async {
    try {
      await _tokenLocalDataSource.deleteToken();
      _userStreamController.add(Success(const UserEntity.empty()));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'signOut');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> signInWithGoogle(
      GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      if (idToken != null) {
        final signInWithGoogleRequestModel = SignInWithGoogleRequestModel(
          idToken: idToken,
          refreshToken: accessToken ?? '',
        );
        await _tokenLocalDataSource.deleteToken();
        final result = await _authenticationRemoteDataSource
            .signInWithGoogle(signInWithGoogleRequestModel);
        await _tokenLocalDataSource.storeTokens(result.$2);
        _userStreamController.add(Success(result.$1));
        return Success(unit);
      } else {
        final failure = ValidationFailure(
          code: 'GOOGLE_ID_TOKEN_NULL',
          message: 'Google idToken is null.',
        );
        await _errorLogger.log(failure, hint: 'signInWithGoogle');
        return Err(failure);
      }
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'signInWithGoogle');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> signInWithApple({
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
      _userStreamController.add(Success(result.$1));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'signInWithApple');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> deleteUser() async {
    try {
      await _authenticationRemoteDataSource.deleteUser();
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'deleteUser');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> deleteGoogleUser() async {
    try {
      await _authenticationRemoteDataSource.deleteGoogleMe();
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'deleteGoogleUser');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> deleteAppleUser() async {
    try {
      await _authenticationRemoteDataSource.deleteAppleMe();
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'deleteAppleUser');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> postFeedback(String message) async {
    try {
      await _authenticationRemoteDataSource.postFeedback(message);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'postFeedback');
      return Err(failure);
    }
  }

  @override
  Future<Result<String?, Failure>> getUserSocialType() async {
    try {
      final value = await _authenticationRemoteDataSource.getUserSocialType();
      return Success(value);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getUserSocialType');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> disconnectGoogleSignIn() async {
    try {
      await _googleSignIn.disconnect();
      debugPrint('Google Sign-In disconnected');
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'disconnectGoogleSignIn');
      return Err(failure);
    }
  }

  @override
  Stream<Result<UserEntity, Failure>> get userStream =>
      _userStreamController.asBroadcastStream();
}
