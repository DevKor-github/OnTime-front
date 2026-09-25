enum DetailedPreferenceLoad { loading, ready, failed, unavailable }

enum DetailedPreferenceSave { idle, saving, failed }

enum DetailedPreferenceDelivery {
  unknown,
  applying,
  delayed,
  applied,
  off,
  noUpcoming,
  permissionNeeded,
  cancellationUnconfirmed,
  schedulingFailed,
  needsCheck,
  contentDeferred,
}

final class DetailedNotificationSettingsState {
  const DetailedNotificationSettingsState({
    required this.generation,
    this.confirmedEnabled,
    this.requestedEnabled,
    this.scheduleNotificationsEnabled,
    this.load = DetailedPreferenceLoad.loading,
    this.save = DetailedPreferenceSave.idle,
    this.delivery = DetailedPreferenceDelivery.unknown,
  });
  final int generation;
  final bool? confirmedEnabled;
  final bool? requestedEnabled;
  final bool? scheduleNotificationsEnabled;
  final DetailedPreferenceLoad load;
  final DetailedPreferenceSave save;
  final DetailedPreferenceDelivery delivery;

  bool? get displayedEnabled => requestedEnabled ?? confirmedEnabled;
  bool get canRequest =>
      load == DetailedPreferenceLoad.ready && confirmedEnabled != null;
  bool get canRetry =>
      save != DetailedPreferenceSave.saving &&
      delivery != DetailedPreferenceDelivery.applying &&
      delivery != DetailedPreferenceDelivery.delayed;
}
