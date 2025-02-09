import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/data/models/create_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';
import 'package:on_time_front/data/models/update_preparation_user_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late PreparationRemoteDataSourceImpl remoteDataSource;
  final uuid = Uuid();

  final scheduleId = uuid.v7();

  final preparationStep1 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 1: Wake up',
    preparationTime: Duration(minutes: 10),
    nextPreparationId: null,
  );

  final preparationStep2 = PreparationStepEntity(
    id: uuid.v7(),
    preparationName: 'Step 2: Brush teeth',
    preparationTime: Duration(minutes: 5),
    nextPreparationId: null,
  );

  final preparationEntity = PreparationEntity(
    preparationStepList: [preparationStep1, preparationStep2],
  );

  final tUpdateRequestModel =
      PreparationUserModifyRequestModel.fromEntity(preparationStep1);

  final tCreateDefualtPreparationRequestModel =
      CreateDefaultPreparationRequestModel.fromEntity(
          preparationEntity: preparationEntity,
          spareTime: Duration(minutes: 10),
          note: 'Wake up');

  final tCreateScheduleRequestModel =
      PreparationScheduleCreateRequestModelListExtension.fromEntityList(
          preparationEntity.preparationStepList);

  setUp(() {
    dio = MockAppDio();
    remoteDataSource = PreparationRemoteDataSourceImpl(dio);
  });

  group('createCustomPreparation', () {
    test(
        'should perform a POST request on the create custom preparation endpoint',
        () async {
      // arrange
      when(dio.post(
        Endpoint.getCreateCustomPreparation(scheduleId),
        data:
            tCreateScheduleRequestModel.map((model) => model.toJson()).toList(),
      )).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(
            path: Endpoint.getCreateCustomPreparation(scheduleId),
          ),
        ),
      );

      // act
      await remoteDataSource.createCustomPreparation(
          preparationEntity, scheduleId);

      // assert
      verify(dio.post(
        Endpoint.getCreateCustomPreparation(scheduleId),
        data:
            tCreateScheduleRequestModel.map((model) => model.toJson()).toList(),
      )).called(1);
    });

    test('should throw an exception when the response code is not 200',
        () async {
      // arrange
      when(dio.post(
        Endpoint.getCreateCustomPreparation(scheduleId),
        data:
            tCreateScheduleRequestModel.map((model) => model.toJson()).toList(),
      )).thenAnswer(
        (_) async => Response(
          statusCode: 400,
          requestOptions: RequestOptions(
            path: Endpoint.getCreateCustomPreparation(scheduleId),
          ),
        ),
      );

      // act
      final call = remoteDataSource.createCustomPreparation;

      // assert
      expect(() => call(preparationEntity, scheduleId), throwsException);
    });
  });

  group('createDefaultPreparation', () {
    test(
        'should perform a POST request on the create default preparation endpoint',
        () async {
      // arrange
      when(dio.put(
        Endpoint.createDefaultPreparation,
        data: tCreateDefualtPreparationRequestModel.toJson(),
      )).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          requestOptions: RequestOptions(
            path: Endpoint.createDefaultPreparation,
          ),
        ),
      );

      // act
      await remoteDataSource
          .createDefaultPreparation(tCreateDefualtPreparationRequestModel);

      // assert
      verify(dio.put(
        Endpoint.createDefaultPreparation,
        data: tCreateDefualtPreparationRequestModel.toJson(),
      )).called(1);
    });

    test('should throw an exception when the response code is not 200',
        () async {
      // arrange
      when(dio.post(
        Endpoint.createDefaultPreparation,
        data: tCreateDefualtPreparationRequestModel.toJson(),
      )).thenAnswer(
        (_) async => Response(
          statusCode: 400,
          requestOptions: RequestOptions(
            path: Endpoint.createDefaultPreparation,
          ),
        ),
      );

      // act
      final call = remoteDataSource.createDefaultPreparation;

      // assert
      expect(
          () => call(tCreateDefualtPreparationRequestModel), throwsException);
    });
  });

  group('getPreparationByScheduleId', () {
    test('should return PreparationEntity when the response is successful',
        () async {
      // arrange
      // when(dio.get(Endpoint.getPreparationByScheduleId(scheduleId))).thenAnswer(
      //   (_) async => Response(
      //     statusCode: 200,
      //     data: [
      //       {
      //         "preparationId": preparationStep1.id,
      //         "preparationName": preparationStep1.preparationName,
      //         "preparationTime": preparationStep1.preparationTime.inMinutes,
      //         "nextPreparationId": preparationStep1.nextPreparationId,
      //       },
      //       {
      //         "preparationId": preparationStep2.id,
      //         "preparationName": preparationStep2.preparationName,
      //         "preparationTime": preparationStep2.preparationTime.inMinutes,
      //         "nextPreparationId": preparationStep2.nextPreparationId,
      //       },
      //     ],
      //     requestOptions: RequestOptions(
      //       path: Endpoint.getPreparationByScheduleId(scheduleId),
      //     ),
      //   ),
      // );

      // // act
      // final result =
      //     await remoteDataSource.getPreparationByScheduleId(scheduleId);

      // // assert
      // expect(result.preparationStepList.length, 2);
    });

    test('should throw an exception when the response code is not 200',
        () async {
      // arrange
      when(dio.get(Endpoint.getPreparationByScheduleId(scheduleId))).thenAnswer(
        (_) async => Response(
          statusCode: 400,
          requestOptions: RequestOptions(
            path: Endpoint.getPreparationByScheduleId(scheduleId),
          ),
        ),
      );

      // act
      final call = remoteDataSource.getPreparationByScheduleId;

      // assert
      expect(() => call(scheduleId), throwsException);
    });
  });

  group('getPreparationStepById', () {
    test('should return PreparationStepEntity when the response is successful',
        () async {
      // arrange
      when(dio.get(
        Endpoint.getPreparationStepById,
        queryParameters: {"preparationStepId": preparationStep1.id},
      )).thenAnswer(
        (_) async => Response(
          statusCode: 200,
          data: {
            "data": {
              "preparationId": preparationStep1.id,
              "preparationName": preparationStep1.preparationName,
              "preparationTime": preparationStep1.preparationTime.inMinutes,
              "nextPreparationId": preparationStep1.nextPreparationId,
            }
          },
          requestOptions: RequestOptions(
            path: Endpoint.getPreparationStepById,
          ),
        ),
      );

      // act
      final result =
          await remoteDataSource.getPreparationStepById(preparationStep1.id);

      // assert
      expect(result.id, preparationStep1.id);
      expect(result.preparationName, preparationStep1.preparationName);
    });

    test('should throw an exception when the response code is not 200',
        () async {
      // arrange
      when(dio.get(
        Endpoint.getPreparationStepById,
        queryParameters: {"preparationStepId": preparationStep1.id},
      )).thenAnswer(
        (_) async => Response(
          statusCode: 404,
          requestOptions: RequestOptions(
            path: Endpoint.getPreparationStepById,
          ),
        ),
      );

      // act
      final call = remoteDataSource.getPreparationStepById;

      // assert
      expect(() => call(preparationStep1.id), throwsException);
    });
  });

  // group('updatePreparation', () {
  //   test('should perform a PUT request on the update preparation endpoint',
  //       () async {
  //     // arrange
  //     when(dio.post(
  //       Endpoint.updateDefaultPreparation,
  //       data: tUpdateRequestModel.toJson(),
  //     )).thenAnswer(
  //       (_) async => Response(
  //         statusCode: 200,
  //         requestOptions: RequestOptions(
  //           path: Endpoint.updateDefaultPreparation,
  //         ),
  //       ),
  //     );

  //     // act
  //     await remoteDataSource.updateDefaultPreparation(preparationEntity);

  //     // assert
  //     verify(dio.post(
  //       Endpoint.updateDefaultPreparation,
  //       data: tUpdateRequestModel.toJson(),
  //     )).called(1);
  //   });

  //   test('should throw an exception when the response code is not 200',
  //       () async {
  //     // arrange
  //     when(dio.post(
  //       Endpoint.updateDefaultPreparation,
  //       data: tUpdateRequestModel.toJson(),
  //     )).thenAnswer(
  //       (_) async => Response(
  //         statusCode: 400,
  //         requestOptions: RequestOptions(
  //           path: Endpoint.updateDefaultPreparation,
  //         ),
  //       ),
  //     );

  //     // act
  //     final call = remoteDataSource.updateDefaultPreparation;

  //     // assert
  //     expect(() => call(preparationEntity), throwsException);
  //   });
  // });
}
