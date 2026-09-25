/// The device's calendar day on the instant axis. DST days are not always 24h.
final class DeviceCivilDay {
  DeviceCivilDay.at(DateTime instant) {
    final local = instant.toLocal();
    startUtc = DateTime(local.year, local.month, local.day).toUtc();
    endUtc = DateTime(local.year, local.month, local.day + 1).toUtc();
  }

  late final DateTime startUtc;
  late final DateTime endUtc;

  bool contains(DateTime instant) =>
      !instant.isBefore(startUtc) && instant.isBefore(endUtc);
}
