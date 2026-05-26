part of 'analytics_preference_cubit.dart';

enum AnalyticsPreferenceStatus {
  initial,
  loading,
  loaded,
  updating,
  failure,
}

class AnalyticsPreferenceState extends Equatable {
  const AnalyticsPreferenceState._({
    required this.status,
    required this.enabled,
    required this.isConfirmed,
  });

  const AnalyticsPreferenceState.initial()
      : this._(
          status: AnalyticsPreferenceStatus.initial,
          enabled: false,
          isConfirmed: false,
        );

  const AnalyticsPreferenceState.loaded({
    required bool enabled,
    required bool isConfirmed,
  }) : this._(
          status: AnalyticsPreferenceStatus.loaded,
          enabled: enabled,
          isConfirmed: isConfirmed,
        );

  const AnalyticsPreferenceState.failure({
    required bool enabled,
    required bool isConfirmed,
  }) : this._(
          status: AnalyticsPreferenceStatus.failure,
          enabled: enabled,
          isConfirmed: isConfirmed,
        );

  final AnalyticsPreferenceStatus status;
  final bool enabled;
  final bool isConfirmed;

  bool get canEmitEvents =>
      status == AnalyticsPreferenceStatus.loaded && isConfirmed && enabled;

  AnalyticsPreferenceState copyWith({
    AnalyticsPreferenceStatus? status,
    bool? enabled,
    bool? isConfirmed,
  }) {
    return AnalyticsPreferenceState._(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  @override
  List<Object> get props => [status, enabled, isConfirmed];
}
