/// A successful local lookup proved that this Schedule does not exist.
/// Storage/open/decryption errors must never be converted into this result.
class ScheduleNotFound implements Exception {
  const ScheduleNotFound(this.scheduleId);
  final String scheduleId;
}
