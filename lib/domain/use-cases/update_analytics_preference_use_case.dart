import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/repositories/analytics_preference_repository.dart';

@Injectable()
class UpdateAnalyticsPreferenceUseCase {
  UpdateAnalyticsPreferenceUseCase(this._repository);

  final AnalyticsPreferenceRepository _repository;

  Future<AnalyticsPreference> call({
    required bool enabled,
    required bool signedIn,
  }) async {
    if (!signedIn) {
      await _repository.saveLocalPreference(enabled);
      return AnalyticsPreference(enabled: enabled);
    }

    final accountPreference = await _repository.updateAccountPreference(
      enabled,
    );
    await _repository.saveLocalPreference(accountPreference.enabled);
    return accountPreference;
  }
}
