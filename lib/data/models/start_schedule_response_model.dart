import 'package:on_time_front/data/models/get_preparation_step_response_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/started_schedule_entity.dart';

class StartScheduleResponseModel {
  const StartScheduleResponseModel({
    required this.schedule,
    required this.preparations,
  });

  final GetScheduleResponseModel schedule;
  final List<GetPreparationStepResponseModel> preparations;

  factory StartScheduleResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final preparationJson =
        data['preparations'] as List<dynamic>? ?? const <dynamic>[];

    return StartScheduleResponseModel(
      schedule: GetScheduleResponseModel.fromJson(
        data['schedule'] as Map<String, dynamic>,
      ),
      preparations: preparationJson
          .map(
            (item) => GetPreparationStepResponseModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  StartedScheduleEntity toEntity() {
    return StartedScheduleEntity(
      schedule: schedule.toEntity(),
      preparation: PreparationWithTimeEntity.fromPreparation(
        preparations.toPreparationEntity(),
      ),
    );
  }
}
