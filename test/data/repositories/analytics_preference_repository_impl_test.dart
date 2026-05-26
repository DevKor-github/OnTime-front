import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/analytics_preference_local_data_source.dart';
import 'package:on_time_front/data/data_sources/analytics_preference_remote_data_source.dart';
import 'package:on_time_front/data/repositories/analytics_preference_repository_impl.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAnalyticsPreferenceRemoteDataSource remoteDataSource;
  late AnalyticsPreferenceRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remoteDataSource = _FakeAnalyticsPreferenceRemoteDataSource();
    repository = AnalyticsPreferenceRepositoryImpl(
      localDataSource: AnalyticsPreferenceLocalDataSourceImpl(),
      remoteDataSource: remoteDataSource,
    );
  });

  test('local analytics preference defaults disabled until explicitly changed', () async {
    expect((await repository.loadLocalPreference()).enabled, isFalse);

    await repository.saveLocalPreference(true);

    expect((await repository.loadLocalPreference()).enabled, isTrue);
  });

  test('account analytics preference calls delegate to the remote data source', () async {
    remoteDataSource.preference = AnalyticsPreference(
      enabled: true,
      updatedAt: DateTime.utc(2026, 5, 26, 12),
    );

    expect(await repository.loadAccountPreference(), remoteDataSource.preference);
    expect(
      await repository.updateAccountPreference(false),
      const AnalyticsPreference(enabled: false),
    );
    expect(remoteDataSource.updatedValues, [false]);
  });
}

class _FakeAnalyticsPreferenceRemoteDataSource
    implements AnalyticsPreferenceRemoteDataSource {
  AnalyticsPreference preference = const AnalyticsPreference(enabled: false);
  final updatedValues = <bool>[];

  @override
  Future<AnalyticsPreference> getAnalyticsPreference() async => preference;

  @override
  Future<AnalyticsPreference> updateAnalyticsPreference({
    required bool enabled,
  }) async {
    updatedValues.add(enabled);
    preference = AnalyticsPreference(enabled: enabled);
    return preference;
  }
}
