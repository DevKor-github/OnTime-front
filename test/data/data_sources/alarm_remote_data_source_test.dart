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

  test('getAlarmSettings maps backend settings response', () async {
    when(dio.get<dynamic>(Endpoint.alarmSettings)).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        data: {
          'data': {
            'alarmsEnabled': true,
            'defaultAlarmOffsetMinutes': 8,
            'updatedAt': '2026-05-05T09:00:00.000',
          },
        },
        requestOptions: RequestOptions(path: Endpoint.alarmSettings),
      ),
    );

    final settings = await remoteDataSource.getAlarmSettings();

    expect(settings.alarmsEnabled, isTrue);
    expect(settings.defaultAlarmOffsetMinutes, 8);
    expect(settings.alarmOffset, const Duration(minutes: 8));
  });

  test(
    'updateAlarmSettings patches the enabled flag and returns settings',
    () async {
      when(
        dio.patch<dynamic>(Endpoint.alarmSettings, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            'data': {'alarmsEnabled': false, 'defaultAlarmOffsetMinutes': 5},
          },
          requestOptions: RequestOptions(path: Endpoint.alarmSettings),
        ),
      );

      final settings = await remoteDataSource.updateAlarmSettings(
        alarmsEnabled: false,
      );

      final data =
          verify(
                dio.patch<dynamic>(
                  Endpoint.alarmSettings,
                  data: captureAnyNamed('data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(data, {'alarmsEnabled': false});
      expect(settings.alarmsEnabled, isFalse);
    },
  );

  test('registerCurrentDevice posts device capability contract', () async {
    when(
      dio.put<dynamic>(Endpoint.currentDevice, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(path: Endpoint.currentDevice),
      ),
    );

    await remoteDataSource.registerCurrentDevice(
      const AlarmDeviceInfo(
        deviceId: 'device-1',
        platform: 'android',
        appVersion: '1.0.0',
        osVersion: 'android-35',
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.androidAlarmManager,
        fallbackProvider: AlarmProvider.localNotification,
      ),
    );

    final data =
        verify(
              dio.put<dynamic>(
                Endpoint.currentDevice,
                data: captureAnyNamed('data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(data['deviceId'], 'device-1');
    expect(data['nativeAlarmProvider'], 'androidAlarmManager');
    expect(data['fallbackProvider'], 'localNotification');
  });

  test('unregisterCurrentDevice deletes the current device by id', () async {
    when(
      dio.delete<dynamic>(Endpoint.currentDevice, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(path: Endpoint.currentDevice),
      ),
    );

    await remoteDataSource.unregisterCurrentDevice('device-1');

    final data =
        verify(
              dio.delete<dynamic>(
                Endpoint.currentDevice,
                data: captureAnyNamed('data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(data, {'deviceId': 'device-1'});
  });

  test('getAlarmWindow queries ISO range and maps schedules', () async {
    final start = DateTime.utc(2026, 5, 5, 9);
    final end = start.add(const Duration(days: 7));
    when(
      dio.get<dynamic>(
        Endpoint.alarmWindow,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        data: {
          'data': [
            {
              'scheduleId': 'schedule-1',
              'scheduleName': 'Morning meeting',
              'place': {'placeId': 'place-1', 'placeName': 'Office'},
              'scheduleTime': '2026-05-06T10:00:00.000',
              'moveTime': 20,
              'scheduleSpareTime': 10,
              'doneStatus': 'NOT_ENDED',
              'preparations': [
                {
                  'preparationId': 'prep-1',
                  'preparationName': 'Pack',
                  'preparationTime': 5,
                  'nextPreparationId': null,
                },
              ],
            },
          ],
        },
        requestOptions: RequestOptions(path: Endpoint.alarmWindow),
      ),
    );

    final schedules = await remoteDataSource.getAlarmWindow(start, end);

    final query =
        verify(
              dio.get<dynamic>(
                Endpoint.alarmWindow,
                queryParameters: captureAnyNamed('queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(query, {
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
    });
    expect(schedules.single.id, 'schedule-1');
    expect(
      schedules.single.preparation.preparationStepList.single.id,
      'prep-1',
    );
  });

  test(
    'non-200 alarm endpoints throw instead of returning partial data',
    () async {
      when(dio.get<dynamic>(Endpoint.alarmSettings)).thenAnswer(
        (_) async => Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: Endpoint.alarmSettings),
        ),
      );

      await expectLater(remoteDataSource.getAlarmSettings(), throwsException);
    },
  );

  test('non-200 alarm mutations and window queries surface failures', () async {
    when(
      dio.patch<dynamic>(Endpoint.alarmSettings, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: Endpoint.alarmSettings),
      ),
    );
    await expectLater(
      remoteDataSource.updateAlarmSettings(alarmsEnabled: true),
      throwsException,
    );

    when(
      dio.put<dynamic>(Endpoint.currentDevice, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: Endpoint.currentDevice),
      ),
    );
    await expectLater(
      remoteDataSource.registerCurrentDevice(
        const AlarmDeviceInfo(
          deviceId: 'device-1',
          platform: 'android',
          appVersion: '1.0.0',
          osVersion: 'android-35',
          supportsNativeAlarm: true,
          nativeAlarmProvider: AlarmProvider.androidAlarmManager,
          fallbackProvider: AlarmProvider.localNotification,
        ),
      ),
      throwsException,
    );

    when(
      dio.delete<dynamic>(Endpoint.currentDevice, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: Endpoint.currentDevice),
      ),
    );
    await expectLater(
      remoteDataSource.unregisterCurrentDevice('device-1'),
      throwsException,
    );

    when(
      dio.get<dynamic>(
        Endpoint.alarmWindow,
        queryParameters: anyNamed('queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: Endpoint.alarmWindow),
      ),
    );
    final start = DateTime.utc(2026, 5, 5, 9);
    await expectLater(
      remoteDataSource.getAlarmWindow(
        start,
        start.add(const Duration(days: 7)),
      ),
      throwsException,
    );
  });

  group('postAlarmStatus', () {
    test(
      'posts lower-camel backend contract without retry on success',
      () async {
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
        expect(data['status'], 'armed');
        expect(data['nativeAlarmProvider'], 'iosAlarmKit');
        expect(data['fallbackProvider'], 'localNotification');
      },
    );

    test(
      'falls back to backend enum format after generic bad request',
      () async {
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
        expect(firstData['status'], 'armed');
        expect(firstData['nativeAlarmProvider'], 'iosAlarmKit');
        expect(secondData.containsKey('permissionIssue'), isFalse);
        expect(secondData['status'], 'ARMED');
        expect(secondData['nativeAlarmProvider'], 'IOS_ALARM_KIT');
        expect(secondData['fallbackProvider'], 'LOCAL_NOTIFICATION');
      },
    );

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
