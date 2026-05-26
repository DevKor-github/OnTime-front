import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/analytics_preference_remote_data_source.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late AnalyticsPreferenceRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockAppDio();
    dataSource = AnalyticsPreferenceRemoteDataSourceImpl(dio);
  });

  test('loads analytics preference from the account endpoint', () async {
    when(dio.get<dynamic>(Endpoint.analyticsPreference)).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        data: {
          'data': {
            'enabled': true,
            'updatedAt': '2026-05-26T12:00:00Z',
          },
        },
        requestOptions: RequestOptions(path: Endpoint.analyticsPreference),
      ),
    );

    final preference = await dataSource.getAnalyticsPreference();

    expect(preference.enabled, isTrue);
    expect(preference.updatedAt, DateTime.parse('2026-05-26T12:00:00Z'));
  });

  test('updates analytics preference with the enabled flag only', () async {
    when(
      dio.put<dynamic>(
        Endpoint.analyticsPreference,
        data: anyNamed('data'),
      ),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        data: {
          'data': {
            'enabled': false,
            'updatedAt': '2026-05-26T12:00:05Z',
          },
        },
        requestOptions: RequestOptions(path: Endpoint.analyticsPreference),
      ),
    );

    final preference = await dataSource.updateAnalyticsPreference(
      enabled: false,
    );

    final data =
        verify(
              dio.put<dynamic>(
                Endpoint.analyticsPreference,
                data: captureAnyNamed('data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(data, {'enabled': false});
    expect(preference.enabled, isFalse);
  });
}
