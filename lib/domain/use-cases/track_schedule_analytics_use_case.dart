import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_analytics_tracker.dart';
import 'package:on_time_front/domain/use-cases/track_product_usage_event_use_case.dart';

@Injectable(as: ScheduleAnalyticsTracker)
class TrackScheduleAnalyticsUseCase implements ScheduleAnalyticsTracker {
  final ProductUsageEventTracker _productUsageEventTracker;
  final DateTime Function() _now;

  TrackScheduleAnalyticsUseCase(this._productUsageEventTracker)
    : _now = DateTime.now;

  TrackScheduleAnalyticsUseCase.withClock(
    this._productUsageEventTracker, {
    required DateTime Function() now,
  }) : _now = now;

  @override
  Future<void> trackScheduleCreated({
    required ScheduleEntity schedule,
    required PreparationEntity preparation,
  }) async {
    await _productUsageEventTracker.track(
      ProductUsageEvent.scheduleCreated(
        preparationMode: schedule.preparationMode,
        preparationStepCount: preparation.preparationStepList.length,
        minutesUntilSchedule: schedule.scheduleTime
            .difference(_now())
            .inMinutes,
      ),
    );
  }
}
