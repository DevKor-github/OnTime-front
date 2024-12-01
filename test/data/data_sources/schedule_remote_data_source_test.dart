import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/core/dio/api_response.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late ScheduleRemoteDataSourceImpl scheduleRemoteDataSourceImpl;
  final uuid = Uuid();

  final scheduleEntityId = uuid.v7();
  final userEntityId = uuid.v7();

  final tPlaceEntity = PlaceEntity(
    id: uuid.v7(),
    placeName: 'Office',
  );

  final tScheduleEntity = ScheduleEntity(
    id: scheduleEntityId,
    userId: userEntityId,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Discuss project updates',
  );

  final tCreateScheduleModel =
      CreateScheduleRequestModel.fromEntity(tScheduleEntity);

  final tUpdateScheduleModel =
      UpdateScheduleRequestModel.fromEntity(tScheduleEntity);

  setUp(() {
    dio = AppDio();
    scheduleRemoteDataSourceImpl = ScheduleRemoteDataSourceImpl(dio);
  });

  group('createSchedule', () {
    test('should perform a POST request on the create schedule endpoint',
        () async {
      // arrange
      when(dio.post(Endpoint.createSchedule,
              data: tCreateScheduleModel.toJson()))
          .thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.createSchedule),
        ),
      );

      // act
      await scheduleRemoteDataSourceImpl.createSchedule(
        tScheduleEntity,
      );

      // assert
      verify(dio.post(Endpoint.createSchedule,
              data: tCreateScheduleModel.toJson()))
          .called(1);
    });

    test('should throw an exception when the response code is not 200', () {
      // arrange
      when(dio.post(Endpoint.createSchedule,
              data: tCreateScheduleModel.toJson()))
          .thenAnswer(
        (_) async => Response(
          statusCode: 400,
          requestOptions: RequestOptions(path: Endpoint.createSchedule),
        ),
      );

      // act
      final call = scheduleRemoteDataSourceImpl.createSchedule;

      // assert
      expect(() => call(tScheduleEntity), throwsException);
    });
  });

  group('getScheduleByDate', () {
    test('should perform a GET request on the /schedule/show endpoint',
        () async {
      // arrange
      when(dio.get<ApiResponse<List<GetScheduleResponseModel>>>(
          Endpoint.getSchedulesByDate,
          queryParameters: {
            'startDate': tScheduleEntity.scheduleTime,
            'endDate': '',
          })).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(path: Endpoint.getSchedulesByDate),
          data: ApiResponse(
              status: 'success',
              data: [GetScheduleResponseModel.fromEntity(tScheduleEntity)]),
        ),
      );

      // act
      final result = await scheduleRemoteDataSourceImpl.getSchedulesByDate(
          tScheduleEntity.scheduleTime, null);

      debugPrint(result.toString());

      // assert
      verify(dio.get(Endpoint.getSchedulesByDate,
          queryParameters: {'date': tScheduleEntity.scheduleTime})).called(1);
    });
  });

  group('updateSchdule', () {
    test('should perform a PUT request on the /schedule/modify endpoint',
        () async {
      // arrange
      when(dio.put(Endpoint.updateSchedule(scheduleEntityId),
              data: tUpdateScheduleModel.toJson()))
          .thenAnswer(
        (_) async => Response(
          statusCode: 204,
          requestOptions:
              RequestOptions(path: Endpoint.updateSchedule(scheduleEntityId)),
        ),
      );

      // act
      await scheduleRemoteDataSourceImpl.updateSchedule(tScheduleEntity);

      // assert
      verify(dio.put(Endpoint.updateSchedule(scheduleEntityId),
              data: tUpdateScheduleModel.toJson()))
          .called(1);
    });

    test('should throw an exception when the response code is not 204',
        () async {
      when(dio.put(Endpoint.updateSchedule(scheduleEntityId),
              data: tUpdateScheduleModel.toJson()))
          .thenAnswer(
        (_) async => Response(
          statusCode: 400,
          requestOptions:
              RequestOptions(path: Endpoint.updateSchedule(scheduleEntityId)),
        ),
      );

      // act
      final call = scheduleRemoteDataSourceImpl.updateSchedule(tScheduleEntity);

      // assert
      expect(call, throwsException);
    });
  });
}
