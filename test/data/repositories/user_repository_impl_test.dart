import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  late _FakeAuthenticationRemoteDataSource remoteDataSource;
  late _FakeTokenLocalDataSource tokenLocalDataSource;
  late UserRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _FakeAuthenticationRemoteDataSource();
    tokenLocalDataSource = _FakeTokenLocalDataSource();
    repository = UserRepositoryImpl(remoteDataSource, tokenLocalDataSource);
  });

  test('signIn stores backend tokens and publishes signed-in user', () async {
    final emittedUsers = <UserEntity>[];
    final subscription = repository.userStream.listen(emittedUsers.add);
    addTearDown(subscription.cancel);

    await repository.signIn(email: 'user@example.com', password: 'Password1!');
    await pumpEventQueue();

    expect(remoteDataSource.signInCalls, [('user@example.com', 'Password1!')]);
    expect(tokenLocalDataSource.storedTokens, [_token]);
    expect(emittedUsers, [const UserEntity.empty(), _user]);
  });

  test('signUp validates password before calling backend', () async {
    await expectLater(
      repository.signUp(
        email: 'user@example.com',
        password: 'weak',
        name: 'User',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(remoteDataSource.signUpCalls, isEmpty);
    expect(tokenLocalDataSource.storedTokens, isEmpty);
  });

  test('signUp stores tokens and publishes newly created user', () async {
    const nextUser = UserEntity(
      id: 'new-user',
      email: 'new@example.com',
      name: 'New User',
      spareTime: Duration(minutes: 10),
      note: 'note',
      score: 4.5,
    );
    remoteDataSource.authResult = (nextUser, _token);

    await repository.signUp(
      email: 'new@example.com',
      password: 'Password1!',
      name: 'New User',
    );

    expect(remoteDataSource.signUpCalls, [
      ('new@example.com', 'Password1!', 'New User'),
    ]);
    expect(tokenLocalDataSource.storedTokens, [_token]);
    expect(await repository.userStream.first, nextUser);
  });

  test(
    'getUser clears tokens and publishes empty user on unauthorized response',
    () async {
      remoteDataSource.getUserHandler = () async {
        throw DioException(
          requestOptions: RequestOptions(path: '/users/me'),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: '/users/me'),
          ),
        );
      };

      final user = await repository.getUser();

      expect(user, const UserEntity.empty());
      expect(tokenLocalDataSource.deleteCount, 1);
      expect(await repository.userStream.first, const UserEntity.empty());
    },
  );

  test('signOut deletes local tokens and publishes empty user', () async {
    await repository.signIn(email: 'user@example.com', password: 'Password1!');

    await repository.signOut();

    expect(tokenLocalDataSource.deleteCount, 1);
    expect(await repository.userStream.first, const UserEntity.empty());
  });

  test(
    'delete and feedback methods forward optional feedback to backend',
    () async {
      await repository.deleteUser(feedbackMessage: 'Not useful');
      await repository.deleteGoogleUser(feedbackMessage: 'Google feedback');
      await repository.deleteAppleUser(feedbackMessage: 'Apple feedback');
      await repository.postFeedback('General feedback');

      expect(remoteDataSource.deleteUserFeedback, 'Not useful');
      expect(remoteDataSource.deleteGoogleFeedback, 'Google feedback');
      expect(remoteDataSource.deleteAppleFeedback, 'Apple feedback');
      expect(remoteDataSource.feedbackMessages, ['General feedback']);
    },
  );

  test('getUserSocialType returns null when backend lookup fails', () async {
    remoteDataSource.socialTypeHandler = () async {
      throw Exception('session expired');
    };

    expect(await repository.getUserSocialType(), isNull);
  });

  test('getUser publishes backend user on successful lookup', () async {
    final user = await repository.getUser();

    expect(user, _user);
    expect(await repository.userStream.first, _user);
  });

  test(
    'signInWithApple replaces local tokens and publishes backend user',
    () async {
      const appleUser = UserEntity(
        id: 'apple-user',
        email: 'apple@example.com',
        name: 'Apple User',
        spareTime: Duration(minutes: 5),
        note: '',
        score: 4.0,
      );
      remoteDataSource.authResult = (appleUser, _token);

      await repository.signInWithApple(
        idToken: 'id-token',
        authCode: 'auth-code',
        fullName: 'Apple User',
        email: 'apple@example.com',
      );

      expect(tokenLocalDataSource.deleteCount, 1);
      expect(tokenLocalDataSource.storedTokens, [_token]);
      expect(remoteDataSource.appleRequests.single.idToken, 'id-token');
      expect(remoteDataSource.appleRequests.single.authCode, 'auth-code');
      expect(remoteDataSource.appleRequests.single.fullName, 'Apple User');
      expect(remoteDataSource.appleRequests.single.email, 'apple@example.com');
      expect(await repository.userStream.first, appleUser);
    },
  );

  test(
    'signInWithApple rethrows backend failures without publishing user',
    () async {
      remoteDataSource.signInWithAppleHandler = (_) async {
        throw Exception('apple backend failed');
      };

      await expectLater(
        repository.signInWithApple(
          idToken: 'id-token',
          authCode: 'auth-code',
          fullName: 'Apple User',
        ),
        throwsException,
      );

      expect(tokenLocalDataSource.deleteCount, 1);
      expect(tokenLocalDataSource.storedTokens, isEmpty);
      expect(await repository.userStream.first, const UserEntity.empty());
    },
  );

  test(
    'signInWithGoogle replaces local tokens and publishes backend user',
    () async {
      const googleUser = UserEntity(
        id: 'google-user',
        email: 'google@example.com',
        name: 'Google User',
        spareTime: Duration(minutes: 15),
        note: '',
        score: 4.0,
      );
      remoteDataSource.authResult = (googleUser, _token);

      await repository.signInWithGoogle(
        _FakeGoogleSignInAccount(idToken: 'google-id-token'),
      );

      expect(tokenLocalDataSource.deleteCount, 1);
      expect(tokenLocalDataSource.storedTokens, [_token]);
      expect(remoteDataSource.googleRequests.single.idToken, 'google-id-token');
      expect(remoteDataSource.googleRequests.single.refreshToken, isEmpty);
      expect(await repository.userStream.first, googleUser);
    },
  );

  test('signInWithGoogle rejects accounts without an ID token', () async {
    await expectLater(
      repository.signInWithGoogle(_FakeGoogleSignInAccount()),
      throwsException,
    );

    expect(remoteDataSource.googleRequests, isEmpty);
    expect(tokenLocalDataSource.deleteCount, 0);
    expect(await repository.userStream.first, const UserEntity.empty());
  });

  test(
    'backend failures are surfaced without publishing a signed-in user',
    () async {
      remoteDataSource.signInHandler = (_, __) async {
        throw Exception('sign in failed');
      };

      await expectLater(
        repository.signIn(email: 'user@example.com', password: 'Password1!'),
        throwsException,
      );

      expect(tokenLocalDataSource.storedTokens, isEmpty);
      expect(await repository.userStream.first, const UserEntity.empty());
    },
  );

  test('non-unauthorized getUser failures are rethrown', () async {
    remoteDataSource.getUserHandler = () async {
      throw DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/users/me'),
        ),
      );
    };

    await expectLater(repository.getUser(), throwsA(isA<DioException>()));

    expect(tokenLocalDataSource.deleteCount, 0);
    expect(await repository.userStream.first, const UserEntity.empty());
  });

  test(
    'getUserSocialType returns backend social type when available',
    () async {
      expect(await repository.getUserSocialType(), 'GOOGLE');
    },
  );

  test('delete operations surface backend failures', () async {
    remoteDataSource.deleteUserHandler = () async {
      throw Exception('delete failed');
    };
    await expectLater(repository.deleteUser(), throwsException);

    remoteDataSource.deleteGoogleHandler = () async {
      throw Exception('delete google failed');
    };
    await expectLater(repository.deleteGoogleUser(), throwsException);

    remoteDataSource.deleteAppleHandler = () async {
      throw Exception('delete apple failed');
    };
    await expectLater(repository.deleteAppleUser(), throwsException);
  });

  test('disconnectGoogleSignIn absorbs plugin failures', () async {
    await repository.disconnectGoogleSignIn();
  });
}

const _user = UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  name: 'User',
  spareTime: Duration(minutes: 10),
  note: 'note',
  score: 4.5,
);

const _token = TokenEntity(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
);

class _FakeAuthenticationRemoteDataSource
    implements AuthenticationRemoteDataSource {
  (UserEntity, TokenEntity) authResult = (_user, _token);
  Future<UserEntity> Function() getUserHandler = () async => _user;
  Future<String?> Function() socialTypeHandler = () async => 'GOOGLE';
  Future<(UserEntity, TokenEntity)> Function(String, String)? signInHandler;

  final signInCalls = <(String, String)>[];
  final signUpCalls = <(String, String, String)>[];
  final appleRequests = <SignInWithAppleRequestModel>[];
  final googleRequests = <SignInWithGoogleRequestModel>[];
  final feedbackMessages = <String>[];
  Future<(UserEntity, TokenEntity)> Function(SignInWithAppleRequestModel)?
  signInWithAppleHandler;
  Future<void> Function()? deleteUserHandler;
  Future<void> Function()? deleteGoogleHandler;
  Future<void> Function()? deleteAppleHandler;
  String? deleteUserFeedback;
  String? deleteGoogleFeedback;
  String? deleteAppleFeedback;

  @override
  Future<(UserEntity, TokenEntity)> signIn(
    String email,
    String password,
  ) async {
    signInCalls.add((email, password));
    final handler = signInHandler;
    if (handler != null) {
      return handler(email, password);
    }
    return authResult;
  }

  @override
  Future<(UserEntity, TokenEntity)> signUp(
    String email,
    String password,
    String name,
  ) async {
    signUpCalls.add((email, password, name));
    return authResult;
  }

  @override
  Future<UserEntity> getUser() => getUserHandler();

  @override
  Future<void> deleteUser({String? feedbackMessage}) async {
    final handler = deleteUserHandler;
    if (handler != null) {
      await handler();
    }
    deleteUserFeedback = feedbackMessage;
  }

  @override
  Future<void> deleteGoogleMe({String? feedbackMessage}) async {
    final handler = deleteGoogleHandler;
    if (handler != null) {
      await handler();
    }
    deleteGoogleFeedback = feedbackMessage;
  }

  @override
  Future<void> deleteAppleMe({String? feedbackMessage}) async {
    final handler = deleteAppleHandler;
    if (handler != null) {
      await handler();
    }
    deleteAppleFeedback = feedbackMessage;
  }

  @override
  Future<void> postFeedback(String message) async {
    feedbackMessages.add(message);
  }

  @override
  Future<String?> getUserSocialType() => socialTypeHandler();

  @override
  Future<(UserEntity, TokenEntity)> signInWithApple(
    SignInWithAppleRequestModel signInWithAppleRequestModel,
  ) async {
    appleRequests.add(signInWithAppleRequestModel);
    final handler = signInWithAppleHandler;
    if (handler != null) {
      return handler(signInWithAppleRequestModel);
    }
    return authResult;
  }

  @override
  Future<(UserEntity, TokenEntity)> signInWithGoogle(
    SignInWithGoogleRequestModel signInWithGoogleRequestModel,
  ) async {
    googleRequests.add(signInWithGoogleRequestModel);
    return authResult;
  }
}

class _FakeGoogleSignInAccount implements GoogleSignInAccount {
  _FakeGoogleSignInAccount({this.idToken});

  final String? idToken;

  @override
  GoogleSignInAuthentication get authentication {
    return GoogleSignInAuthentication(idToken: idToken);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTokenLocalDataSource implements TokenLocalDataSource {
  final storedTokens = <TokenEntity>[];
  final storedAuthTokens = <String>[];
  int deleteCount = 0;

  @override
  Future<void> storeTokens(TokenEntity token) async {
    storedTokens.add(token);
  }

  @override
  Future<void> storeAuthToken(String token) async {
    storedAuthTokens.add(token);
  }

  @override
  Future<TokenEntity> getToken() async {
    return storedTokens.last;
  }

  @override
  Future<void> deleteToken() async {
    deleteCount += 1;
  }
}
