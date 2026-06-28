import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/product_analytics_service.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

void main() {
  test('product usage events include the runtime app version', () async {
    final client = _FakeAnalyticsProviderClient();
    final service = _buildService(client);

    await service.applyPreference(
      const AnalyticsPreference(enabled: true, isConfirmed: true),
    );
    await service.track(_scheduleCreatedEvent());

    expect(client.loggedEvents.single.parameters['app_version'], '9.8.7');
  });

  test(
    'unconfirmed analytics preference does not log product usage events',
    () async {
      final client = _FakeAnalyticsProviderClient();
      final service = _buildService(client);

      await service.applyPreference(
        const AnalyticsPreference(enabled: true, isConfirmed: false),
      );
      await service.track(_scheduleCreatedEvent());

      expect(client.collectionEnabledValues, [false]);
      expect(client.loggedEvents, isEmpty);
    },
  );

  test(
    'disabled analytics preference does not log product usage events',
    () async {
      final client = _FakeAnalyticsProviderClient();
      final service = _buildService(client);

      await service.applyPreference(
        const AnalyticsPreference(enabled: false, isConfirmed: true),
      );
      await service.track(_scheduleCreatedEvent());

      expect(client.collectionEnabledValues, [false]);
      expect(client.loggedEvents, isEmpty);
    },
  );
}

ProductAnalyticsService _buildService(_FakeAnalyticsProviderClient client) {
  return ProductAnalyticsService(
    client: client,
    appMetadataProvider: const _FakeAppMetadataProvider(
      AppMetadata(version: '9.8.7', buildNumber: '654'),
    ),
    collectionAllowedInBuild: true,
  );
}

ProductUsageEvent _scheduleCreatedEvent() {
  return ProductUsageEvent.scheduleCreated(
    preparationMode: SchedulePreparationMode.defaultPreparation,
    preparationStepCount: 1,
    minutesUntilSchedule: 60,
  );
}

class _FakeAnalyticsProviderClient implements AnalyticsProviderClient {
  final collectionEnabledValues = <bool>[];
  final loggedEvents = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionEnabledValues.add(enabled);
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserId(String? userId) async {}
}

class _FakeAppMetadataProvider implements AppMetadataProvider {
  const _FakeAppMetadataProvider(this.metadata);

  final AppMetadata metadata;

  @override
  Future<AppMetadata> getMetadata() async => metadata;
}
