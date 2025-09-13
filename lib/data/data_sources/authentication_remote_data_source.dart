import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/get_user_response_model.dart';
import 'package:on_time_front/data/models/sign_in_user_response_model.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class AuthenticationRemoteDataSource {
  Future<(UserEntity, TokenEntity)> signIn(String email, String password);

  Future<(UserEntity, TokenEntity)> signUp(
      String email, String password, String name);

  Future<(UserEntity, TokenEntity)> signInWithGoogle(
      SignInWithGoogleRequestModel signInWithGoogleRequestModel);

  Future<(UserEntity, TokenEntity)> signInWithApple(
      SignInWithAppleRequestModel signInWithAppleRequestModel);

  Future<UserEntity> getUser();
}

@Injectable(as: AuthenticationRemoteDataSource)
class AuthenticationRemoteDataSourceImpl
    implements AuthenticationRemoteDataSource {
  final Dio dio;
  AuthenticationRemoteDataSourceImpl(this.dio);

  @override
  Future<(UserEntity, TokenEntity)> signIn(
      String email, String password) async {
    try {
      final result = await dio.post(
        Endpoint.signIn,
        data: {
          'email': email,
          'password': password,
        },
      );
      if (result.statusCode == 200) {
        final user = SignInUserResponseModel.fromJson(result.data['data']);
        final token = TokenEntity.fromHeaders(result.headers);
        return (user.toEntity(), token);
      } else {
        throw Exception('Error signing in');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<(UserEntity, TokenEntity)> signUp(
      String email, String password, String name) async {
    try {
      final result = await dio.post(
        Endpoint.signUp,
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );
      if (result.statusCode == 200) {
        final user = SignInUserResponseModel.fromJson(result.data['data']);
        final token = TokenEntity.fromHeaders(result.headers);
        return (user.toEntity(), token);
      } else {
        throw Exception('Error signing up');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<(UserEntity, TokenEntity)> signInWithGoogle(
      SignInWithGoogleRequestModel signInWithGoogleRequestModel) async {
    try {
      final result = await dio.post(
        Endpoint.signInWithGoogle,
        data: signInWithGoogleRequestModel.toJson(),
      );
      if (result.statusCode == 200) {
        final user = SignInUserResponseModel.fromJson(result.data['data']);
        final token = TokenEntity.fromHeaders(result.headers);
        return (user.toEntity(), token);
      } else {
        throw Exception('Error signing in with Google');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<(UserEntity, TokenEntity)> signInWithApple(
      SignInWithAppleRequestModel signInWithAppleRequestModel) async {
    try {
      final result = await dio.post(
        Endpoint.signInWithApple,
        data: signInWithAppleRequestModel.toJson(),
      );
      if (result.statusCode == 200) {
        final user = SignInUserResponseModel.fromJson(result.data['data']);
        final token = TokenEntity.fromHeaders(result.headers);
        return (user.toEntity(), token);
      } else {
        throw Exception('Error signing in with Apple');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserEntity> getUser() async {
    try {
      final result = await dio.get(Endpoint.getUser);
      if (result.statusCode == 200) {
        final user = GetUserResponseModel.fromJson(result.data['data']);
        return user.toEntity();
      } else {
        throw Exception('Error getting user');
      }
    } catch (e) {
      rethrow;
    }
  }
}
