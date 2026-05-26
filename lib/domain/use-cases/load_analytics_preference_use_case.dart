import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';

@Injectable()
class LoadAnalyticsPreferenceUseCase {
  LoadAnalyticsPreferenceUseCase(this._repository);

  final AnalyticsPreferenceRepository _repository;

  Future<AnalyticsPreference> call({required bool signedIn}) async {
    final localPreference = await _repository.loadLocalPreference();
    if (!signedIn) return localPreference;

    try {
      final accountPreference = await _repository.loadAccountPreference();
      return AnalyticsPreference(
        enabled: localPreference.enabled && accountPreference.enabled,
        updatedAt: accountPreference.updatedAt,
      );
    } catch (_) {
      return const AnalyticsPreference.disabledUnconfirmed();
    }
  }
}
