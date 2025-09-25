import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/get_user_response_model.dart';
import 'package:on_time_front/data/models/sign_in_user_response_model.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:uuid/uuid.dart';

abstract interface class AuthenticationRemoteDataSource {
  Future<(UserEntity, TokenEntity)> signIn(String email, String password);

  Future<(UserEntity, TokenEntity)> signUp(
      String email, String password, String name);

  Future<(UserEntity, TokenEntity)> signInWithGoogle(
      SignInWithGoogleRequestModel signInWithGoogleRequestModel);

  Future<(UserEntity, TokenEntity)> signInWithApple(
      SignInWithAppleRequestModel signInWithAppleRequestModel);

  Future<UserEntity> getUser();

  Future<void> deleteGoogleMe();

  Future<void> deleteAppleMe();

  Future<void> postFeedback(String message);

  Future<void> deleteUser();

  Future<String?> getUserSocialType();
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

  @override
  Future<void> deleteGoogleMe() async {
    try {
      final result = await dio.delete(Endpoint.deleteGoogleMe);
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error deleting Google user');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAppleMe() async {
    try {
      final result = await dio.delete(Endpoint.deleteAppleMe);
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error deleting Apple user');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> postFeedback(String message) async {
    try {
      final feedbackId = const Uuid().v4();
      final result = await dio.post(Endpoint.feedback, data: {
        'feedbackId': feedbackId,
        'message': message,
      });
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error posting feedback');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      final result = await dio.delete(Endpoint.deleteUser);
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error deleting user');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String?> getUserSocialType() async {
    try {
      final result = await dio.get(Endpoint.getUser);
      if (result.statusCode == 200) {
        final data = result.data['data'] as Map<String, dynamic>;
        return data['socialType'] as String?;
      } else {
        throw Exception('Error getting user social type');
      }
    } catch (e) {
      rethrow;
    }
  }
}
