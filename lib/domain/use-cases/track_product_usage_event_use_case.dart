import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/product_analytics_service.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';

abstract interface class ProductUsageEventTracker {
  Future<void> track(ProductUsageEvent event);
}

@Injectable(as: ProductUsageEventTracker)
class TrackProductUsageEventUseCase implements ProductUsageEventTracker {
  TrackProductUsageEventUseCase(this._analyticsService);

  final ProductAnalyticsService _analyticsService;

  @override
  Future<void> track(ProductUsageEvent event) async {
    try {
      await _analyticsService.track(event);
    } catch (error) {
      AppLogger.debug(
        '[Analytics] track failed event=${event.name} '
        'errorType=${error.runtimeType}',
      );
    }
  }
}
