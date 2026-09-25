import 'package:on_time_front/domain/entities/alarm_entities.dart';

enum DeliveryObservationSource {
  androidPluginCache,
  iosNotificationCenter,
  iosAlarmKit,
  unavailable,
}

enum DeliveryPresence { present, absent, unknown }

/// Only routing identity is retained. Notification text is never copied here.
class PendingDelivery {
  const PendingDelivery({required this.id, this.scheduleId});

  final String id;
  final String? scheduleId;
}

/// A successful empty query and a failed/unsupported query are different facts.
/// Android's plugin cache is not an observation of AlarmManager registrations.
class DeliveryObservation {
  const DeliveryObservation({
    required this.source,
    required this.entries,
    this.available = true,
    this.unmappedCount = 0,
  });

  const DeliveryObservation.unknown({
    this.source = DeliveryObservationSource.unavailable,
  }) : entries = const [],
       available = false,
       unmappedCount = 0;

  final DeliveryObservationSource source;
  final List<PendingDelivery> entries;
  final bool available;
  final int unmappedCount;

  bool get isOsObservation =>
      source == DeliveryObservationSource.iosNotificationCenter ||
      source == DeliveryObservationSource.iosAlarmKit;

  DeliveryPresence presence(ScheduledAlarmRecord record) {
    if (!available) return DeliveryPresence.unknown;
    final id = record.provider == AlarmProvider.localNotification
        ? (record.fallbackNotificationId ?? stableAlarmId(record.scheduleId))
              .toString()
        : record.scheduleId;
    return entries.any((entry) => entry.id == id)
        ? DeliveryPresence.present
        : DeliveryPresence.absent;
  }
}
