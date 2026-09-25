import 'package:equatable/equatable.dart';

enum DeviceTimeZoneStatus { loading, known, unavailable }

/// An observed device setting, never the authority for a saved commitment.
final class DeviceTimeZoneState extends Equatable {
  const DeviceTimeZoneState.loading()
    : status = DeviceTimeZoneStatus.loading,
      identifier = null;
  const DeviceTimeZoneState.known(String zone)
    : status = DeviceTimeZoneStatus.known,
      identifier = zone;
  const DeviceTimeZoneState.unavailable()
    : status = DeviceTimeZoneStatus.unavailable,
      identifier = null;

  final DeviceTimeZoneStatus status;
  final String? identifier;

  @override
  List<Object?> get props => [status, identifier];
}
