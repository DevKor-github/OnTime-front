import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AnalyticsPreferenceLocalDataSource {
  Future<AnalyticsPreference> loadPreference();

  Future<void> savePreference(bool enabled);
}

@Injectable(as: AnalyticsPreferenceLocalDataSource)
class AnalyticsPreferenceLocalDataSourceImpl
    implements AnalyticsPreferenceLocalDataSource {
  static const _enabledKey = 'analytics_preference_enabled';

  @override
  Future<AnalyticsPreference> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return AnalyticsPreference(enabled: prefs.getBool(_enabledKey) ?? false);
  }

  @override
  Future<void> savePreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}
