import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/analytics_preference_local_data_source.dart';
import 'package:on_time_front/data/data_sources/analytics_preference_remote_data_source.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';

@Singleton(as: AnalyticsPreferenceRepository)
class AnalyticsPreferenceRepositoryImpl implements AnalyticsPreferenceRepository {
  AnalyticsPreferenceRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  final AnalyticsPreferenceLocalDataSource localDataSource;
  final AnalyticsPreferenceRemoteDataSource remoteDataSource;

  @override
  Future<AnalyticsPreference> loadLocalPreference() {
    return localDataSource.loadPreference();
  }

  @override
  Future<void> saveLocalPreference(bool enabled) {
    return localDataSource.savePreference(enabled);
  }

  @override
  Future<AnalyticsPreference> loadAccountPreference() {
    return remoteDataSource.getAnalyticsPreference();
  }

  @override
  Future<AnalyticsPreference> updateAccountPreference(bool enabled) {
    return remoteDataSource.updateAnalyticsPreference(enabled: enabled);
  }
}
