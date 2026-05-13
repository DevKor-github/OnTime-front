import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';

Map<String, dynamic> scheduleJson({Object? startedAt}) {
  return {
    'scheduleId': 'schedule-1',
    'place': {'placeId': 'place-1', 'placeName': 'Office'},
    'scheduleName': 'Meeting',
    'scheduleTime': '2026-05-13T19:30:00',
    'moveTime': 20,
    'scheduleSpareTime': 10,
    'scheduleNote': 'Bring notes',
    'latenessTime': -1,
    'doneStatus': 'NOT_ENDED',
    'startedAt': startedAt,
  };
}

void main() {
  group('GetScheduleResponseModel', () {
    test('maps null startedAt', () {
      final model = GetScheduleResponseModel.fromJson(
        scheduleJson(startedAt: null),
      );

      expect(model.startedAt, isNull);
      expect(model.toEntity().startedAt, isNull);
    });

    test('maps non-null UTC startedAt', () {
      final model = GetScheduleResponseModel.fromJson(
        scheduleJson(startedAt: '2026-05-13T10:15:30Z'),
      );

      expect(model.startedAt, DateTime.parse('2026-05-13T10:15:30Z'));
      expect(
        model.toEntity().startedAt,
        DateTime.parse('2026-05-13T10:15:30Z'),
      );
    });
  });
}
