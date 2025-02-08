import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/sign_in_user_response_model.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

abstract interface class AuthenticationRemoteDataSource {
  Future<(UserEntity, TokenEntity)> signIn(String email, String password);

  Future<(UserEntity, TokenEntity)> signUp(
      String email, String password, String name);

  Future<(UserEntity, TokenEntity)> signInWithGoogle(String accessToken);
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
  Future<(UserEntity, TokenEntity)> signInWithGoogle(String accessToken) async {
    try {
      final result = await dio.post(
        Endpoint.signInWithGoogle,
        data: {
          'accessToken': accessToken,
        },
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
}
