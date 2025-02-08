import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:on_time_front/core/constants/endpoint.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/data/models/create_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/create_preparation_user_request_model.dart';
import 'package:on_time_front/data/models/get_preparation_step_response_model.dart';

abstract interface class PreparationRemoteDataSource {
  Future<void> createDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updateDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId);

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationEntity> getDefualtPreparation();

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);
}

@Injectable(as: PreparationRemoteDataSource)
class PreparationRemoteDataSourceImpl implements PreparationRemoteDataSource {
  final Dio dio;

  PreparationRemoteDataSourceImpl(this.dio);

  @override
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      final requestModels =
          PreparationScheduleCreateRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.post(
        Endpoint.getCreateCustomPreparation(scheduleId),
        data: requestModels.map((model) => model.toJson()).toList(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error creating custom preparation');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity) async {
    try {
      final requestModels =
          PreparationUserRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.post(
        Endpoint.createDefaultPreparation,
        data: requestModels.map((model) => model.toJson()).toList(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error creating default preparation');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationEntity> getPreparationByScheduleId(
      String scheduleId) async {
    // 원상복구!!!!!
    try {
      final result = await dio.get(
        //  Endpoint.getPreparationByScheduleId(scheduleId),
        'https://ontime.devkor.club' +
            Endpoint.getPreparationByScheduleId(scheduleId),
        options: Options(
          headers: {
            'Authorization':
                'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJBY2Nlc3NUb2tlbiIsImV4cCI6MTczOTAxMzc4MywiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwidXNlcklkIjoxfQ.5_kMFuoOmmYjnNGQnTbwZD2DGInrmMYRsOp1iM4IMxbHvPEHktHdJJlgqwz_3F4eNPyqVHedzJfMH5CfOGRiEQ',
          },
        ),
      );

      if (result.statusCode == 200) {
        final responseModels = (result.data['data'] as List<dynamic>)
            .map((json) => GetPreparationStepResponseModel.fromJson(
                json as Map<String, dynamic>))
            .toList();

        return responseModels.toPreparationEntity();
      } else {
        throw Exception('Error fetching preparation by schedule ID');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationEntity> getDefualtPreparation() async {
    try {
      final result = await dio.get(Endpoint.getDefaultPreparation);

      if (result.statusCode == 200) {
        final responseModels = (result.data['data'] as List<dynamic>)
            .map((json) => GetPreparationStepResponseModel.fromJson(
                json as Map<String, dynamic>))
            .toList();

        return responseModels.toPreparationEntity();
      } else {
        throw Exception('Error fetching default preparation');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    try {
      final result = await dio.get(
        Endpoint.getPreparationStepById,
        queryParameters: {"preparationStepId": preparationStepId},
      );

      if (result.statusCode == 200) {
        final responseModel =
            GetPreparationStepResponseModel.fromJson(result.data["data"]);
        return responseModel.toEntity();
      } else {
        throw Exception('Error fetching preparation step by ID');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateDefaultPreparation(
      PreparationEntity preparationEntity) async {
    try {
      final updateModel =
          PreparationUserRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.post(
        Endpoint.updateDefaultPreparation,
        data: updateModel.map((model) => model.toJson()).toList(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error updating preparation');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String preparationId) async {
    try {
      final updateModel =
          PreparationUserRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.post(
        Endpoint.updatePreparationByScheduleId(preparationId),
        data: updateModel.map((model) => model.toJson()).toList(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error updating preparation');
      }
    } catch (e) {
      rethrow;
    }
  }
}
