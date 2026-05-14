import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

void main() {
  final schedule = ScheduleEntity(
    id: 'schedule-1',
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Morning meeting',
    scheduleTime: DateTime(2026, 6, 1, 9, 30),
    moveTime: const Duration(minutes: 20),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: 'Bring laptop',
  );

  test('create schedule omits preparation fields for default source', () {
    final json = CreateScheduleRequestModel.fromEntity(schedule).toJson();

    expect(json.containsKey('preparationTemplateId'), isFalse);
    expect(json.containsKey('customPreparations'), isFalse);
  });

  test('create schedule serializes template source from template id', () {
    final json = CreateScheduleRequestModel.fromEntity(
      schedule.copyWith(
        preparationMode: SchedulePreparationMode.template,
        preparationTemplateId: 'template-1',
      ),
    ).toJson();

    expect(json['preparationTemplateId'], 'template-1');
    expect(json.containsKey('customPreparations'), isFalse);
  });

  test('create schedule serializes custom ordered preparations', () {
    final json = CreateScheduleRequestModel.fromEntity(
      schedule.copyWith(
        preparationMode: SchedulePreparationMode.custom,
        customPreparations: const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'prep-1',
              preparationName: 'Pack laptop',
              preparationTime: Duration(minutes: 5),
            ),
          ],
        ),
      ),
    ).toJson();

    expect(json.containsKey('preparationTemplateId'), isFalse);
    expect(json['customPreparations'], [
      {
        'preparationId': 'prep-1',
        'preparationName': 'Pack laptop',
        'preparationTime': 5,
        'orderIndex': 0,
      },
    ]);
  });

  test('update schedule preserves preparation source by default', () {
    final json = UpdateScheduleRequestModel.fromEntity(
      schedule.copyWith(
        preparationMode: SchedulePreparationMode.template,
        preparationTemplateId: 'template-1',
      ),
    ).toJson();

    expect(json.containsKey('preparationMode'), isFalse);
    expect(json.containsKey('preparationTemplateId'), isFalse);
    expect(json.containsKey('customPreparations'), isFalse);
  });

  test('update schedule includes preparation source when requested', () {
    final json = UpdateScheduleRequestModel.fromEntity(
      schedule.copyWith(
        preparationMode: SchedulePreparationMode.template,
        preparationTemplateId: 'template-1',
      ),
      includePreparationSource: true,
    ).toJson();

    expect(json['preparationMode'], 'TEMPLATE');
    expect(json['preparationTemplateId'], 'template-1');
    expect(json.containsKey('customPreparations'), isFalse);
  });

  test('schedule response parses preparation metadata and frozen flag', () {
    final entity = GetScheduleResponseModel.fromJson({
      'scheduleId': 'schedule-1',
      'placeId': 'place-1',
      'placeName': 'Office',
      'scheduleName': 'Morning meeting',
      'scheduleTime': '2026-06-01T09:30:00',
      'moveTime': 20,
      'scheduleSpareTime': 10,
      'scheduleNote': '',
      'startedAt': '2026-06-01T08:30:00Z',
      'preparationMode': 'TEMPLATE',
      'preparationTemplateId': 'template-1',
      'preparationTemplateName': 'Work',
      'preparationTemplateDeleted': true,
    }).toEntity();

    expect(entity.place.placeName, 'Office');
    expect(entity.preparationMode, SchedulePreparationMode.template);
    expect(entity.preparationTemplateId, 'template-1');
    expect(entity.preparationTemplateName, 'Work');
    expect(entity.preparationTemplateDeleted, isTrue);
    expect(entity.preparationFrozen, isTrue);
    expect(entity.isStarted, isTrue);
  });
}
