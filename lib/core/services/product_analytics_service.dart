import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';

abstract interface class AnalyticsProviderClient {
  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  });

  Future<void> setUserId(String? userId);
}

@Singleton(as: AnalyticsProviderClient)
class FirebaseAnalyticsProviderClient implements AnalyticsProviderClient {
  FirebaseAnalyticsProviderClient({@ignoreParam FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) {
    return _analytics.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserId(String? userId) {
    return _analytics.setUserId(id: userId);
  }
}

@Singleton()
class ProductAnalyticsService {
  ProductAnalyticsService({
    required AnalyticsProviderClient client,
    required AppMetadataProvider appMetadataProvider,
    @ignoreParam
    bool collectionAllowedInBuild = const bool.fromEnvironment(
      'ONTIME_ANALYTICS_ENABLED',
    ),
  }) : _client = client,
       _appMetadataProvider = appMetadataProvider,
       _collectionAllowedInBuild = collectionAllowedInBuild;

  final AnalyticsProviderClient _client;
  final AppMetadataProvider _appMetadataProvider;
  final bool _collectionAllowedInBuild;
  bool _collectionEnabled = false;

  Future<void> applyPreference(AnalyticsPreference preference) async {
    _collectionEnabled =
        _collectionAllowedInBuild &&
        preference.isConfirmed &&
        preference.enabled;
    await _client.setAnalyticsCollectionEnabled(_collectionEnabled);
  }

  Future<void> track(ProductUsageEvent event) async {
    if (!_collectionEnabled) return;
    final metadata = await _appMetadataProvider.getMetadata();
    await _client.logEvent(
      name: event.name,
      parameters: event.toAnalyticsParameters(
        platform: _platformWireValue(),
        appVersion: metadata.version,
      ),
    );
  }

  Future<void> setUserAssociation(String? userId) {
    return _client.setUserId(userId);
  }

  String _platformWireValue() {
    try {
      switch (DeviceInfoService.platformType) {
        case PlatformType.android:
          return 'android';
        case PlatformType.ios:
          return 'ios';
        case PlatformType.web:
          return 'web';
      }
    } catch (_) {
      return 'unknown';
    }
  }
}
