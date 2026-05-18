import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/notification_remote_data_source.dart';
import 'package:on_time_front/data/models/fcm_token_register_request_model.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late NotificationRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockAppDio();
    dataSource = NotificationRemoteDataSourceImpl(dio);
  });

  test('fcmTokenRegister posts the device token payload', () async {
    when(
      dio.post<dynamic>(Endpoint.fcmTokenRegister, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(path: Endpoint.fcmTokenRegister),
      ),
    );

    await dataSource.fcmTokenRegister(
      FcmTokenRegisterRequestModel(
        firebaseToken: 'fcm-token',
        deviceId: 'device-1',
      ),
    );

    final data =
        verify(
              dio.post<dynamic>(
                Endpoint.fcmTokenRegister,
                data: captureAnyNamed('data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(data, {'firebaseToken': 'fcm-token', 'deviceId': 'device-1'});
  });

  test('fcmTokenRegister rejects non-success backend status', () async {
    when(
      dio.post<dynamic>(Endpoint.fcmTokenRegister, data: anyNamed('data')),
    ).thenAnswer(
      (_) async => Response(
        statusCode: 500,
        requestOptions: RequestOptions(path: Endpoint.fcmTokenRegister),
      ),
    );

    await expectLater(
      dataSource.fcmTokenRegister(
        FcmTokenRegisterRequestModel(firebaseToken: 'fcm-token'),
      ),
      throwsException,
    );
  });
}
