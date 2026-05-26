import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';
import 'package:on_time_front/domain/use-cases/load_analytics_preference_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_analytics_preference_use_case.dart';

void main() {
  test('signed-in analytics preference fails closed when account load fails', () async {
    final repository = _FakeAnalyticsPreferenceRepository()
      ..localPreference = const AnalyticsPreference(enabled: true)
      ..loadAccountError = Exception('backend unavailable');
    final useCase = LoadAnalyticsPreferenceUseCase(repository);

    final preference = await useCase(signedIn: true);

    expect(preference.enabled, isFalse);
    expect(preference.isConfirmed, isFalse);
  });

  test(
    'signed-in analytics preference update keeps local value when account update fails',
    () async {
      final repository = _FakeAnalyticsPreferenceRepository()
        ..localPreference = const AnalyticsPreference(enabled: true)
        ..updateAccountError = Exception('backend unavailable');
      final useCase = UpdateAnalyticsPreferenceUseCase(repository);

      await expectLater(
        useCase(enabled: false, signedIn: true),
        throwsException,
      );

      expect(repository.localPreference.enabled, isTrue);
    },
  );
}

class _FakeAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  AnalyticsPreference localPreference = const AnalyticsPreference(enabled: false);
  AnalyticsPreference accountPreference =
      const AnalyticsPreference(enabled: false);
  Object? loadAccountError;
  Object? updateAccountError;

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
    final error = updateAccountError;
    if (error != null) throw error;
    accountPreference = AnalyticsPreference(enabled: enabled);
    return accountPreference;
  }
}
