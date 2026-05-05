import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/alarm_remote_data_source.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late AlarmRemoteDataSourceImpl remoteDataSource;

  setUp(() {
    dio = MockAppDio();
    remoteDataSource = AlarmRemoteDataSourceImpl(dio);
  });

  group('postAlarmStatus', () {
    test('posts backend enum format without retry on success', () async {
      when(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.alarmStatus),
        ),
      );

      await remoteDataSource.postAlarmStatus(_statusReport());

      final verification = verify(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: captureAnyNamed('data'),
          options: captureAnyNamed('options'),
        ),
      )..called(1);
      final data = verification.captured[0] as Map<String, dynamic>;
      final options = verification.captured[1] as Options;

      expect(options.validateStatus!(400), isTrue);
      expect(data.containsKey('permissionIssue'), isFalse);
      expect(data['reconciledAt'], '2026-05-05T09:00:00.000Z');
      expect(data['status'], 'ARMED');
      expect(data['nativeAlarmProvider'], 'IOS_ALARM_KIT');
      expect(data['fallbackProvider'], 'LOCAL_NOTIFICATION');
    });

    test('falls back to lower-camel format after bad request', () async {
      var callCount = 0;
      when(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer((_) async {
        callCount += 1;
        return Response(
          statusCode: callCount == 1 ? 400 : 200,
          data: callCount == 1
              ? {
                  'status': 'error',
                  'code': 400,
                  'message': 'bad request',
                  'data': null,
                }
              : null,
          requestOptions: RequestOptions(path: Endpoint.alarmStatus),
        );
      });

      await remoteDataSource.postAlarmStatus(_statusReport());

      final verification = verify(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: captureAnyNamed('data'),
          options: captureAnyNamed('options'),
        ),
      )..called(2);
      final firstData = verification.captured[0] as Map<String, dynamic>;
      final firstOptions = verification.captured[1] as Options;
      final secondData = verification.captured[2] as Map<String, dynamic>;
      final secondOptions = verification.captured[3] as Options;

      expect(firstOptions.validateStatus!(400), isTrue);
      expect(secondOptions.validateStatus!(400), isTrue);
      expect(firstData.containsKey('permissionIssue'), isFalse);
      expect(firstData['status'], 'ARMED');
      expect(firstData['nativeAlarmProvider'], 'IOS_ALARM_KIT');
      expect(secondData.containsKey('permissionIssue'), isFalse);
      expect(secondData['status'], 'armed');
      expect(secondData['nativeAlarmProvider'], 'iosAlarmKit');
      expect(secondData['fallbackProvider'], 'localNotification');
    });

    test('does not retry semantic validation errors', () async {
      when(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 400,
          data: {
            'status': 'error',
            'code': 1002,
            'message': 'invalid input',
            'data': null,
          },
          requestOptions: RequestOptions(path: Endpoint.alarmStatus),
        ),
      );

      expect(
        () => remoteDataSource.postAlarmStatus(_statusReport()),
        throwsException,
      );

      verify(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).called(1);
    });

    test('throws device session exception for inactive session', () async {
      when(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 409,
          data: {'code': 'DEVICE_SESSION_NOT_ACTIVE'},
          requestOptions: RequestOptions(path: Endpoint.alarmStatus),
        ),
      );

      expect(
        () => remoteDataSource.postAlarmStatus(_statusReport()),
        throwsA(isA<DeviceSessionNotActiveException>()),
      );

      verify(
        dio.post<dynamic>(
          Endpoint.alarmStatus,
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).called(1);
    });
  });
}

AlarmStatusReport _statusReport() {
  final now = DateTime.utc(2026, 5, 5, 9);
  return AlarmStatusReport(
    deviceId: 'device-1',
    reconciledAt: now,
    scheduleWindowStart: now,
    scheduleWindowEnd: now.add(const Duration(days: 8)),
    alarmCoverageStart: now,
    alarmCoverageEnd: now.add(const Duration(days: 7)),
    status: AlarmReconciliationStatus.armed,
    nativeAlarmProvider: AlarmProvider.iosAlarmKit,
    fallbackProvider: AlarmProvider.localNotification,
    armedScheduleCount: 1,
    armedScheduleIds: const ['schedule-1'],
    skippedScheduleCount: 0,
    failures: const [],
  );
}
