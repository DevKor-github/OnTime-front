import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/start_schedule_response_model.dart';

void main() {
  test('maps start response schedule and frozen preparations', () {
    final response = StartScheduleResponseModel.fromJson({
      'status': 'success',
      'code': 200,
      'message': 'OK',
      'data': {
        'schedule': {
          'scheduleId': 'schedule-1',
          'place': {'placeId': 'place-1', 'placeName': 'Office'},
          'scheduleName': 'Meeting',
          'scheduleTime': '2026-05-13T19:30:00',
          'moveTime': 20,
          'scheduleSpareTime': 10,
          'scheduleNote': 'Bring notes',
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
    }).toEntity();

    expect(response.schedule.id, 'schedule-1');
    expect(response.schedule.startedAt, DateTime.parse('2026-05-13T10:15:30Z'));
    expect(response.schedule.finishedAt, isNull);
    expect(response.preparation.preparationStepList.single.id, 'prep-1');
    expect(
      response.preparation.preparationStepList.single.preparationTime,
      const Duration(minutes: 10),
    );
  });
}
