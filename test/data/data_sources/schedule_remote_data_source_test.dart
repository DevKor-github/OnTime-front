import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/data/models/create_schedule_request_model.dart';
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

  final tPlaceEntity = PlaceEntity(id: uuid.v7(), placeName: 'Office');

  final tScheduleEntity = ScheduleEntity(
    id: scheduleEntityId,
    place: tPlaceEntity,
    scheduleName: 'Meeting',
    scheduleTime: DateTime.now(),
    moveTime: Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration(minutes: 5),
    scheduleNote: 'Discuss project updates',
  );

  final tCreateScheduleModel = CreateScheduleRequestModel.fromEntity(
    tScheduleEntity,
  );
  final tUpdateScheduleModel = UpdateScheduleRequestModel.fromEntity(
    tScheduleEntity,
  );

  setUp(() {
    dio = MockAppDio();
    scheduleRemoteDataSourceImpl = ScheduleRemoteDataSourceImpl(dio);
  });

  group('createSchedule', () {
    test(
      'should perform a POST request on the create schedule endpoint',
      () async {
        // arrange
        when(
          dio.post(
            Endpoint.createSchedule,
            data: tCreateScheduleModel.toJson(),
          ),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 200,
            requestOptions: RequestOptions(path: Endpoint.createSchedule),
          ),
        );

        // act
        await scheduleRemoteDataSourceImpl.createSchedule(tScheduleEntity);

        // assert
        verify(
          dio.post(
            Endpoint.createSchedule,
            data: tCreateScheduleModel.toJson(),
          ),
        ).called(1);
      },
    );

    test('should throw an exception when the response code is not 200', () {
      // arrange
      when(
        dio.post(Endpoint.createSchedule, data: tCreateScheduleModel.toJson()),
      ).thenAnswer(
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

  group('updateSchedule', () {
    test('should perform a PUT request without completion fields', () async {
      final updateJson = tUpdateScheduleModel.toJson();
      expect(updateJson, isNot(contains('latenessTime')));

      when(
        dio.put(Endpoint.updateSchedule(scheduleEntityId), data: updateJson),
      ).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(
            path: Endpoint.updateSchedule(scheduleEntityId),
          ),
        ),
      );

      await scheduleRemoteDataSourceImpl.updateSchedule(tScheduleEntity);

      verify(
        dio.put(Endpoint.updateSchedule(scheduleEntityId), data: updateJson),
      ).called(1);
    });

    test(
      'should throw an exception when the response code is not 200',
      () async {
        when(
          dio.put(
            Endpoint.updateSchedule(scheduleEntityId),
            data: tUpdateScheduleModel.toJson(),
          ),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: Endpoint.updateSchedule(scheduleEntityId),
            ),
          ),
        );

        final call = scheduleRemoteDataSourceImpl.updateSchedule(
          tScheduleEntity,
        );

        expect(call, throwsException);
      },
    );
  });

  group('deleteSchedule', () {
    test(
      'should perform a DELETE request on the /schedule/delete endpoint',
      () async {
        // arrange
        when(
          dio.delete(Endpoint.deleteScheduleById(scheduleEntityId)),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 200,
            requestOptions: RequestOptions(
              path: Endpoint.deleteScheduleById(scheduleEntityId),
            ),
          ),
        );

        // act
        await scheduleRemoteDataSourceImpl.deleteSchedule(tScheduleEntity);

        // assert
        verify(
          dio.delete(Endpoint.deleteScheduleById(scheduleEntityId)),
        ).called(1);
      },
    );

    test(
      'should throw an exception when the response code is not 204',
      () async {
        when(
          dio.delete(Endpoint.deleteScheduleById(scheduleEntityId)),
        ).thenAnswer(
          (_) async => Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: Endpoint.deleteScheduleById(scheduleEntityId),
            ),
          ),
        );

        // act
        final call = scheduleRemoteDataSourceImpl.deleteSchedule(
          tScheduleEntity,
        );

        // assert
        expect(call, throwsException);
      },
    );
  });

  group('startSchedule', () {
    test(
      'should perform a POST request with no request body and map response',
      () async {
        when(dio.post(Endpoint.startSchedule(scheduleEntityId))).thenAnswer(
          (_) async => Response(
            statusCode: 200,
            requestOptions: RequestOptions(
              path: Endpoint.startSchedule(scheduleEntityId),
            ),
            data: {
              'status': 'success',
              'code': 200,
              'message': 'OK',
              'data': {
                'schedule': {
                  'scheduleId': scheduleEntityId,
                  'place': {
                    'placeId': tPlaceEntity.id,
                    'placeName': tPlaceEntity.placeName,
                  },
                  'scheduleName': 'Meeting',
                  'scheduleTime': '2026-05-13T19:30:00',
                  'moveTime': 10,
                  'scheduleSpareTime': 5,
                  'scheduleNote': 'Discuss project updates',
                  'latenessTime': -1,
                  'doneStatus': 'NOT_ENDED',
                  'startedAt': '2026-05-13T10:15:30Z',
                  'finishedAt': null,
                },
                'preparations': [
                  {
                    'preparationId': 'prep-1',
                    'preparationName': 'Wash up',
                    'preparationTime': 10,
                    'nextPreparationId': null,
                  },
                ],
              },
            },
          ),
        );

        final result = await scheduleRemoteDataSourceImpl.startSchedule(
          scheduleEntityId,
        );

        verify(dio.post(Endpoint.startSchedule(scheduleEntityId))).called(1);
        expect(result.schedule.id, scheduleEntityId);
        expect(
          result.schedule.startedAt,
          DateTime.parse('2026-05-13T10:15:30Z'),
        );
        expect(result.preparation.preparationStepList.single.id, 'prep-1');
      },
    );
  });
}
