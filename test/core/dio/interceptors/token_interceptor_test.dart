import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/core/dio/interceptors/token_interceptor.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

void main() {
  final getIt = GetIt.instance;

  late Dio dio;
  late _FakeTokenLocalDataSource tokenLocalDataSource;
  late _FakeUserRepository userRepository;
  late _UnauthorizedAdapter adapter;

  setUp(() async {
    await getIt.reset();

    tokenLocalDataSource = _FakeTokenLocalDataSource();
    userRepository = _FakeUserRepository(tokenLocalDataSource);
    getIt.registerSingleton<TokenLocalDataSource>(tokenLocalDataSource);
    getIt.registerSingleton<UserRepository>(userRepository);

    adapter = _UnauthorizedAdapter();
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://example.com',
        receiveDataWhenStatusError: true,
      ),
    )..httpClientAdapter = adapter;
    dio.interceptors.add(TokenInterceptor(dio));
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('locally signs out when refresh token request returns 401', () async {
    await expectLater(
      dio.get<void>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(
        adapter.requestedPaths, containsAll(['/protected', '/refresh-token']));
    expect(userRepository.signOutCalled, isTrue);
    expect(tokenLocalDataSource.deleteTokenCalled, isTrue);
  });
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  final requestedPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    return ResponseBody.fromString(
      '{"message":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenLocalDataSource implements TokenLocalDataSource {
  bool deleteTokenCalled = false;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalled = true;
  }

  @override
  Future<TokenEntity> getToken() async {
    return const TokenEntity(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<void> storeAuthToken(String token) async {}

  @override
  Future<void> storeTokens(TokenEntity token) async {}
}

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this._tokenLocalDataSource);

  final TokenLocalDataSource _tokenLocalDataSource;
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    await _tokenLocalDataSource.deleteToken();
  }

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  GoogleSignIn get googleSignIn => throw UnimplementedError();

  @override
  Future<void> deleteAppleUser() => throw UnimplementedError();

  @override
  Future<void> deleteGoogleUser() => throw UnimplementedError();

  @override
  Future<void> deleteUser() => throw UnimplementedError();

  @override
  Future<void> disconnectGoogleSignIn() => throw UnimplementedError();

  @override
  Future<void> getUser() => throw UnimplementedError();

  @override
  Future<String?> getUserSocialType() => throw UnimplementedError();

  @override
  Future<void> postFeedback(String message) => throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithGoogle(GoogleSignInAccount account) =>
      throw UnimplementedError();

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) =>
      throw UnimplementedError();
}
