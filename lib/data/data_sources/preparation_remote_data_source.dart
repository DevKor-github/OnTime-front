import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/update_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/update_preparation_user_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/data/models/create_preparation_schedule_request_model.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';
import 'package:on_time_front/data/models/get_preparation_step_response_model.dart';
import 'package:on_time_front/data/models/update_spare_time_request_model.dart';

abstract interface class PreparationRemoteDataSource {
  Future<void> createDefaultPreparation(
      CreateDefaultPreparationRequestModel model);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updateDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId);

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationEntity> getDefualtPreparation();

  Future<void> updateSpareTime(Duration newSpareTime);
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
      CreateDefaultPreparationRequestModel model) async {
    try {
      final result = await dio.put(
        Endpoint.createDefaultPreparation,
        data: model.toJson(),
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
  Future<void> updateDefaultPreparation(
      PreparationEntity preparationEntity) async {
    try {
      final updateModel =
          PreparationUserModifyRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.put(
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
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      final updateModel =
          PreparationScheduleModifyRequestModelListExtension.fromEntityList(
              preparationEntity.preparationStepList);

      final result = await dio.post(
        Endpoint.updatePreparationByScheduleId(scheduleId),
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
  Future<void> updateSpareTime(Duration newSpareTime) async {
    try {
      final body = UpdateSpareTimeRequestModel.fromDuration(newSpareTime);
      final result = await dio.put(
        Endpoint.updateSpareTime,
        data: body.toJson(),
      );
      if (result.statusCode != 200) {
        throw Exception('Error updating spare time');
      }
    } catch (e) {
      rethrow;
    }
  }
}
