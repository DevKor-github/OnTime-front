import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/product_analytics_service.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';
import 'package:on_time_front/domain/use-cases/load_analytics_preference_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_analytics_preference_use_case.dart';
import 'package:on_time_front/presentation/app/cubit/analytics_preference_cubit.dart';

void main() {
  test('load fails closed when signed-in account preference cannot be loaded', () async {
    final repository = _FakeAnalyticsPreferenceRepository()
      ..localPreference = const AnalyticsPreference(enabled: true)
      ..loadAccountError = Exception('backend unavailable');
    final cubit = AnalyticsPreferenceCubit(
      loadPreferenceUseCase: LoadAnalyticsPreferenceUseCase(repository),
      updatePreferenceUseCase: UpdateAnalyticsPreferenceUseCase(repository),
      analyticsService: ProductAnalyticsService(
        client: _FakeAnalyticsProviderClient(),
        collectionAllowedInBuild: true,
      ),
    );
    addTearDown(cubit.close);

    await cubit.load(signedIn: true);

    expect(cubit.state.status, AnalyticsPreferenceStatus.failure);
    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.canEmitEvents, isFalse);
  });

  test('load applies confirmed enabled preference to analytics service', () async {
    final client = _FakeAnalyticsProviderClient();
    final repository = _FakeAnalyticsPreferenceRepository()
      ..localPreference = const AnalyticsPreference(enabled: true)
      ..accountPreference = const AnalyticsPreference(enabled: true);
    final cubit = AnalyticsPreferenceCubit(
      loadPreferenceUseCase: LoadAnalyticsPreferenceUseCase(repository),
      updatePreferenceUseCase: UpdateAnalyticsPreferenceUseCase(repository),
      analyticsService: ProductAnalyticsService(
        client: client,
        collectionAllowedInBuild: true,
      ),
    );
    addTearDown(cubit.close);

    await cubit.load(signedIn: true);

    expect(cubit.state.canEmitEvents, isTrue);
    expect(client.collectionEnabledValues, [true]);
  });
}

class _FakeAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  AnalyticsPreference localPreference = const AnalyticsPreference(enabled: false);
  AnalyticsPreference accountPreference =
      const AnalyticsPreference(enabled: false);
  Object? loadAccountError;

  @override
  Future<AnalyticsPreference> loadLocalPreference() async => localPreference;

  @override
  Future<void> saveLocalPreference(bool enabled) async {
    localPreference = AnalyticsPreference(enabled: enabled);
  }

  @override
  Future<AnalyticsPreference> loadAccountPreference() async {
    final error = loadAccountError;
    if (error != null) throw error;
    return accountPreference;
  }

  @override
  Future<AnalyticsPreference> updateAccountPreference(bool enabled) async {
    accountPreference = AnalyticsPreference(enabled: enabled);
    return accountPreference;
  }
}

class _FakeAnalyticsProviderClient implements AnalyticsProviderClient {
  final collectionEnabledValues = <bool>[];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionEnabledValues.add(enabled);
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
