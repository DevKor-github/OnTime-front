import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/data/models/create_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/create_preparation_user_request_model.dart';
import 'package:on_time_front/data/models/get_preparation_response_model.dart';
import 'package:on_time_front/data/models/update_preparation_user_request_model.dart';

abstract interface class PreparationRemoteDataSource {
  Future<void> createDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updatePreparation(PreparationStepEntity preparationStepEntity);

  Future<PreparationEntity> deletePreparation(
      PreparationEntity preparationEntity);

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

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
    try {
      final result = await dio.get(
        Endpoint.getPreparationByScheduleId(scheduleId),
      );

      if (result.statusCode == 200) {
        final responseModels = (result.data as List<dynamic>)
            .map((json) => PreparationStepResponseModel.fromJson(
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
  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    try {
      final result = await dio.get(
        Endpoint.getPreparationStepById,
        queryParameters: {"preparationStepId": preparationStepId},
      );

      if (result.statusCode == 200) {
        final responseModel =
            PreparationStepResponseModel.fromJson(result.data["data"]);
        return responseModel.toEntity();
      } else {
        throw Exception('Error fetching preparation step by ID');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationEntity> deletePreparation(
      PreparationEntity preparationEntity) async {
    try {
      if (preparationEntity.preparationStepList.isEmpty) {
        return preparationEntity;
      }

      final deletedStepId = preparationEntity.preparationStepList.first.id;

      // 로컬에서 단계 삭제 및 재배열
      preparationEntity.removeStepById(deletedStepId);
      preparationEntity.relinkList();

      // 삭제된 결과 반환
      return preparationEntity;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePreparation(
      PreparationStepEntity preparationStepEntity) async {
    try {
      final updateModel =
          PreparationUserModifyRequestModel.fromEntity(preparationStepEntity);

      final result = await dio.put(
        Endpoint.updatePreparation,
        data: updateModel.toJson(),
      );

      if (result.statusCode != 200) {
        throw Exception('Error updating preparation');
      }
    } catch (e) {
      rethrow;
    }
  }
}
