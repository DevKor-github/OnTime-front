import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/track_product_usage_event_use_case.dart';
import 'package:on_time_front/domain/use-cases/track_schedule_analytics_use_case.dart';

class SpyProductUsageEventTracker implements ProductUsageEventTracker {
  final events = <ProductUsageEvent>[];

  @override
  Future<void> track(ProductUsageEvent event) async {
    events.add(event);
  }
}

void main() {
  test(
    'schedule create analytics uses allowed schedule_created parameters',
    () async {
      final productUsageEventTracker = SpyProductUsageEventTracker();
      final tracker = TrackScheduleAnalyticsUseCase.withClock(
        productUsageEventTracker,
        now: () => DateTime(2027, 3, 20, 8),
      );
      final schedule = ScheduleEntity(
        id: 'schedule-1',
        place: PlaceEntity(id: 'place-1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2027, 3, 20, 9),
        moveTime: const Duration(minutes: 30),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 10),
        scheduleNote: 'bring laptop',
      );
      final preparation = PreparationEntity(
        preparationStepList: const [
          PreparationStepEntity(
            id: 'prep-1',
            preparationName: 'Shower',
            preparationTime: Duration(minutes: 10),
          ),
          PreparationStepEntity(
            id: 'prep-2',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      );

      await tracker.trackScheduleCreated(
        schedule: schedule,
        preparation: preparation,
      );

      expect(productUsageEventTracker.events, hasLength(1));
      final event = productUsageEventTracker.events.single;
      expect(event.name, 'schedule_created');
      expect(event.workflow, 'schedule');
      expect(event.result, 'success');
      expect(event.parameters, {
        'preparation_mode': 'default',
        'preparation_step_count': 2,
        'minutes_until_schedule': 60,
      });
    },
  );
}
