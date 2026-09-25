/// A completed occurrence cannot acquire another durable start transition.
final class ScheduleStartRejected implements Exception {
  const ScheduleStartRejected(this.scheduleId);
  final String scheduleId;
}
