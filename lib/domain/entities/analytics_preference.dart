class AnalyticsPreference {
  const AnalyticsPreference({
    required this.enabled,
    this.updatedAt,
    this.isConfirmed = true,
  });

  const AnalyticsPreference.disabledUnconfirmed()
      : enabled = false,
        updatedAt = null,
        isConfirmed = false;

  final bool enabled;
  final DateTime? updatedAt;
  final bool isConfirmed;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AnalyticsPreference &&
            other.enabled == enabled &&
            other.updatedAt == updatedAt &&
            other.isConfirmed == isConfirmed;
  }

  @override
  int get hashCode => Object.hash(enabled, updatedAt, isConfirmed);
}
