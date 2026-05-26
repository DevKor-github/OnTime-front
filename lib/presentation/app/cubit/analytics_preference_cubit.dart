import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/product_analytics_service.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';
import 'package:on_time_front/domain/use-cases/load_analytics_preference_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_analytics_preference_use_case.dart';

part 'analytics_preference_state.dart';

@Injectable()
class AnalyticsPreferenceCubit extends Cubit<AnalyticsPreferenceState> {
  AnalyticsPreferenceCubit({
    required LoadAnalyticsPreferenceUseCase loadPreferenceUseCase,
    required UpdateAnalyticsPreferenceUseCase updatePreferenceUseCase,
    required ProductAnalyticsService analyticsService,
  })  : _loadPreferenceUseCase = loadPreferenceUseCase,
        _updatePreferenceUseCase = updatePreferenceUseCase,
        _analyticsService = analyticsService,
        super(const AnalyticsPreferenceState.initial());

  final LoadAnalyticsPreferenceUseCase _loadPreferenceUseCase;
  final UpdateAnalyticsPreferenceUseCase _updatePreferenceUseCase;
  final ProductAnalyticsService _analyticsService;

  Future<void> load({required bool signedIn}) async {
    emit(state.copyWith(status: AnalyticsPreferenceStatus.loading));
    final preference = await _loadPreferenceUseCase(signedIn: signedIn);
    if (!preference.isConfirmed) {
      await _analyticsService.applyPreference(preference);
      emit(
        AnalyticsPreferenceState.failure(
          enabled: preference.enabled,
          isConfirmed: false,
        ),
      );
      return;
    }
    await _analyticsService.applyPreference(preference);
    emit(
      AnalyticsPreferenceState.loaded(
        enabled: preference.enabled,
        isConfirmed: true,
      ),
    );
  }

  Future<void> update({
    required bool enabled,
    required bool signedIn,
  }) async {
    final previous = state;
    emit(state.copyWith(status: AnalyticsPreferenceStatus.updating));
    try {
      final preference = await _updatePreferenceUseCase(
        enabled: enabled,
        signedIn: signedIn,
      );
      await _analyticsService.applyPreference(preference);
      emit(
        AnalyticsPreferenceState.loaded(
          enabled: preference.enabled,
          isConfirmed: true,
        ),
      );
    } catch (_) {
      await _analyticsService.applyPreference(
        AnalyticsPreference(
          enabled: previous.enabled,
          isConfirmed: previous.isConfirmed,
        ),
      );
      emit(previous.copyWith(status: AnalyticsPreferenceStatus.failure));
    }
  }
}
