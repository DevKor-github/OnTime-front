import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';
import 'package:on_time_front/data/models/sign_in_with_apple_request_model.dart';
import 'package:on_time_front/data/models/sign_in_with_google_request_model.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late AuthenticationRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockAppDio();
    dataSource = AuthenticationRemoteDataSourceImpl(dio);
  });

  group('deleteUser', () {
    test('sends optional feedback in the DELETE request body', () async {
      when(dio.delete(Endpoint.deleteUser, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.deleteUser),
        ),
      );

      await dataSource.deleteUser(feedbackMessage: '  Not useful anymore.  ');

      final capturedData =
          verify(
                dio.delete(Endpoint.deleteUser, data: captureAnyNamed('data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(capturedData['feedbackId'], isA<String>());
      expect(capturedData['message'], 'Not useful anymore.');
    });

    test('sends an empty body when feedback is blank', () async {
      when(
        dio.delete(Endpoint.deleteGoogleMe, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.deleteGoogleMe),
        ),
      );

      await dataSource.deleteGoogleMe(feedbackMessage: '   ');

      verify(
        dio.delete(Endpoint.deleteGoogleMe, data: <String, dynamic>{}),
      ).called(1);
    });
  });

  group('auth contract', () {
    test(
      'signIn posts credentials and returns user with response tokens',
      () async {
        when(
          dio.post(Endpoint.signIn, data: anyNamed('data')),
        ).thenAnswer((_) async => _authResponse(Endpoint.signIn));

        final (user, token) = await dataSource.signIn(
          'user@example.com',
          'Password1!',
        );

        final capturedData =
            verify(
                  dio.post(Endpoint.signIn, data: captureAnyNamed('data')),
                ).captured.single
                as Map<String, dynamic>;
        expect(capturedData, {
          'email': 'user@example.com',
          'password': 'Password1!',
        });
        expect(user, _user(isOnboardingCompleted: true));
        expect(token.accessToken, 'access-token');
        expect(token.refreshToken, 'refresh-token');
      },
    );

    test(
      'signUp posts registration data and maps guest onboarding status',
      () async {
        when(dio.post(Endpoint.signUp, data: anyNamed('data'))).thenAnswer(
          (_) async => _authResponse(Endpoint.signUp, role: 'GUEST'),
        );

        final (user, _) = await dataSource.signUp(
          'new@example.com',
          'Password1!',
          'New User',
        );

        final capturedData =
            verify(
                  dio.post(Endpoint.signUp, data: captureAnyNamed('data')),
                ).captured.single
                as Map<String, dynamic>;
        expect(capturedData, {
          'email': 'new@example.com',
          'password': 'Password1!',
          'name': 'New User',
        });
        expect(user, _user(isOnboardingCompleted: false));
      },
    );

    test('signInWithGoogle posts provider token payload', () async {
      when(
        dio.post(Endpoint.signInWithGoogle, data: anyNamed('data')),
      ).thenAnswer((_) async => _authResponse(Endpoint.signInWithGoogle));

      await dataSource.signInWithGoogle(
        SignInWithGoogleRequestModel(
          idToken: 'google-id-token',
          refreshToken: 'google-refresh-token',
        ),
      );

      final capturedData =
          verify(
                dio.post(
                  Endpoint.signInWithGoogle,
                  data: captureAnyNamed('data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(capturedData, {
        'idToken': 'google-id-token',
        'refreshToken': 'google-refresh-token',
      });
    });

    test('signInWithApple omits null email from provider payload', () async {
      when(
        dio.post(Endpoint.signInWithApple, data: anyNamed('data')),
      ).thenAnswer((_) async => _authResponse(Endpoint.signInWithApple));

      await dataSource.signInWithApple(
        SignInWithAppleRequestModel(
          idToken: 'apple-id-token',
          authCode: 'auth-code',
          fullName: 'Apple User',
        ),
      );

      final capturedData =
          verify(
                dio.post(
                  Endpoint.signInWithApple,
                  data: captureAnyNamed('data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(capturedData, {
        'idToken': 'apple-id-token',
        'authCode': 'auth-code',
        'fullName': 'Apple User',
      });
    });

    test('getUser maps backend profile defaults', () async {
      when(dio.get(Endpoint.getUser)).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'data': {
              'userId': 2,
              'email': 'profile@example.com',
              'name': 'Profile',
              'spareTime': null,
              'note': null,
              'punctualityScore': null,
              'role': 'GUEST',
            },
          },
          requestOptions: RequestOptions(path: Endpoint.getUser),
        ),
      );

      final user = await dataSource.getUser();

      expect(
        user,
        const UserEntity(
          id: '2',
          email: 'profile@example.com',
          name: 'Profile',
          spareTime: Duration.zero,
          note: '',
          score: -1,
          isOnboardingCompleted: false,
        ),
      );
    });

    test('getUserSocialType reads social type from profile payload', () async {
      when(dio.get(Endpoint.getUser)).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'data': {'socialType': 'GOOGLE'},
          },
          requestOptions: RequestOptions(path: Endpoint.getUser),
        ),
      );

      expect(await dataSource.getUserSocialType(), 'GOOGLE');
    });

    test('postFeedback trims backend long-text payload', () async {
      when(dio.post(Endpoint.feedback, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.feedback),
        ),
      );

      await dataSource.postFeedback('  useful feedback  ');

      final capturedData =
          verify(
                dio.post(Endpoint.feedback, data: captureAnyNamed('data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(capturedData['feedbackId'], isA<String>());
      expect(capturedData['message'], 'useful feedback');
    });

    test(
      'non-200 signIn response throws instead of returning partial data',
      () async {
        when(dio.post(Endpoint.signIn, data: anyNamed('data'))).thenAnswer(
          (_) async => Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: Endpoint.signIn),
          ),
        );

        await expectLater(
          dataSource.signIn('user@example.com', 'Password1!'),
          throwsException,
        );
      },
    );

    test(
      'non-200 auth and profile responses surface contract failures',
      () async {
        when(dio.post(Endpoint.signUp, data: anyNamed('data'))).thenAnswer(
          (_) async => Response(
            statusCode: 409,
            requestOptions: RequestOptions(path: Endpoint.signUp),
          ),
        );
        await expectLater(
          dataSource.signUp('new@example.com', 'Password1!', 'New User'),
          throwsException,
        );

        when(
          dio.post(Endpoint.signInWithGoogle, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 400,
            requestOptions: RequestOptions(path: Endpoint.signInWithGoogle),
          ),
        );
        await expectLater(
          dataSource.signInWithGoogle(
            SignInWithGoogleRequestModel(
              idToken: 'google-id-token',
              refreshToken: 'google-refresh-token',
            ),
          ),
          throwsException,
        );

        when(
          dio.post(Endpoint.signInWithApple, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 400,
            requestOptions: RequestOptions(path: Endpoint.signInWithApple),
          ),
        );
        await expectLater(
          dataSource.signInWithApple(
            SignInWithAppleRequestModel(
              idToken: 'apple-id-token',
              authCode: 'auth-code',
              fullName: 'Apple User',
            ),
          ),
          throwsException,
        );

        when(dio.get(Endpoint.getUser)).thenAnswer(
          (_) async => Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: Endpoint.getUser),
          ),
        );
        await expectLater(dataSource.getUser(), throwsException);
        await expectLater(dataSource.getUserSocialType(), throwsException);
      },
    );

    test('non-200 delete and feedback responses surface failures', () async {
      when(
        dio.delete(Endpoint.deleteGoogleMe, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: Endpoint.deleteGoogleMe),
        ),
      );
      await expectLater(dataSource.deleteGoogleMe(), throwsException);

      when(
        dio.delete(Endpoint.deleteAppleMe, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: Endpoint.deleteAppleMe),
        ),
      );
      await expectLater(dataSource.deleteAppleMe(), throwsException);

      when(dio.delete(Endpoint.deleteUser, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: Endpoint.deleteUser),
        ),
      );
      await expectLater(dataSource.deleteUser(), throwsException);

      when(dio.post(Endpoint.feedback, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: Endpoint.feedback),
        ),
      );
      await expectLater(dataSource.postFeedback('not useful'), throwsException);
    });
  });
}

Response<dynamic> _authResponse(String path, {String role = 'USER'}) {
  return Response(
    statusCode: 200,
    data: {
      'data': {
        'userId': 1,
        'email': 'user@example.com',
        'name': 'User',
        'spareTime': 10,
        'note': 'note',
        'punctualityScore': 4.5,
        'role': role,
      },
    },
    headers: Headers.fromMap({
      'authorization': ['access-token'],
      'authorization-refresh': ['refresh-token'],
    }),
    requestOptions: RequestOptions(path: path),
  );
}

UserEntity _user({required bool isOnboardingCompleted}) {
  return UserEntity(
    id: '1',
    email: 'user@example.com',
    name: 'User',
    spareTime: const Duration(minutes: 10),
    note: 'note',
    score: 4.5,
    isOnboardingCompleted: isOnboardingCompleted,
  );
}
