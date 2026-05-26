import 'package:on_time_front/domain/entities/analytics_preference.dart';

abstract interface class AnalyticsPreferenceRepository {
  Future<AnalyticsPreference> loadLocalPreference();

  Future<void> saveLocalPreference(bool enabled);

  Future<AnalyticsPreference> loadAccountPreference();

  Future<AnalyticsPreference> updateAccountPreference(bool enabled);
}
