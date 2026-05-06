import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/authentication_remote_data_source.dart';

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

      final capturedData = verify(
        dio.delete(Endpoint.deleteUser, data: captureAnyNamed('data')),
      ).captured.single as Map<String, dynamic>;
      expect(capturedData['feedbackId'], isA<String>());
      expect(capturedData['message'], 'Not useful anymore.');
    });

    test('sends an empty body when feedback is blank', () async {
      when(dio.delete(Endpoint.deleteGoogleMe, data: anyNamed('data')))
          .thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.deleteGoogleMe),
        ),
      );

      await dataSource.deleteGoogleMe(feedbackMessage: '   ');

      verify(dio.delete(Endpoint.deleteGoogleMe, data: <String, dynamic>{}))
          .called(1);
    });
  });
}
