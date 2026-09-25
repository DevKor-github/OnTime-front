import 'dart:convert';
import 'package:on_time_front/domain/entities/backup_processing.dart';

abstract final class BackupLimits {
  static const cipherBytes = 72 * 1024 * 1024;
  static const plainBytes = 64 * 1024 * 1024;
  static const depth = 32;
  static const schedules = 100000;
  static const records = 500000;
  static const preparationSteps = 1000;
  static const work = 2000000;
  static const identifierBytes = 512;
  static const stringBytes = 64 * 1024;
  static const noteScalars = 16384;
  static const exactInteger = 9007199254740991;

  static Never exceeded(String limit) =>
      throw BackupProcessingFailure(BackupFailureKind.resourceLimit, limit);
  static Never invalid() =>
      throw const BackupProcessingFailure(BackupFailureKind.dataInvariant);

  static void string(
    String value, {
    bool identifier = false,
    bool note = false,
  }) {
    final max = identifier ? identifierBytes : stringBytes;
    // No larger UTF-8 encoding is allocated just to discover a known overrun.
    if (value.length > max) exceeded(identifier ? 'identifier' : 'string');
    if (utf8.encode(value).length > max) {
      exceeded(identifier ? 'identifier' : 'string');
    }
    if (note && value.runes.length > noteScalars) exceeded('note');
    for (final rune in value.runes) {
      if (rune >= 0xd800 && rune <= 0xdfff) invalid();
    }
  }

  static int integer(
    Object? value, {
    int minimum = 0,
    int maximum = exactInteger,
  }) {
    if (value is! int || value < minimum || value > maximum) invalid();
    return value;
  }

  static int minutes(Object? value) {
    // Dart Duration uses signed 64-bit microseconds on supported native targets.
    return integer(value, maximum: 0x7fffffffffffffff ~/ 60000000);
  }
}

class BackupBudget {
  BackupBudget({this.lease}) : _shared = _WorkMeter();
  BackupBudget._(this.lease, this._shared);
  final _WorkMeter _shared;

  /// A distinct encoding pass has its own byte cap, sharing total logical work.
  BackupBudget bytePass() => BackupBudget._(lease, _shared);
  final BackupProcessingLease? lease;
  int cipherBytes = 0;
  int plainBytes = 0;
  bool earlyRecordAdmission = false;
  int records = 0;
  int schedules = 0;
  int get work => _shared.work;

  /// Largest individually accounted buffer/token, NOT simultaneous live bytes,
  /// Dart heap, native allocation or process RSS.
  int get largestTrackedBufferBytes => _shared.largestBuffer;

  void ciphertext(int amount) {
    lease?.check();
    if (amount < 0 || amount > BackupLimits.cipherBytes - cipherBytes) {
      BackupLimits.exceeded('cipherBytes');
    }
    cipherBytes += amount;
  }

  void plaintext(int amount) {
    lease?.check();
    if (amount < 0 || amount > BackupLimits.plainBytes - plainBytes) {
      BackupLimits.exceeded('plainBytes');
    }
    plainBytes += amount;
  }

  void visit([int amount = 1]) {
    lease?.check();
    if (amount < 0 || amount > BackupLimits.work - work) {
      BackupLimits.exceeded('work');
    }
    _shared.work += amount;
  }

  void admitValidated({bool schedule = false}) {
    if (!earlyRecordAdmission) admit(schedule: schedule);
  }

  void admit({bool schedule = false}) {
    visit();
    if (records == BackupLimits.records) BackupLimits.exceeded('records');
    if (schedule && schedules == BackupLimits.schedules) {
      BackupLimits.exceeded('schedules');
    }
    records++;
    if (schedule) schedules++;
  }

  void buffer(int bytes) {
    if (bytes > largestTrackedBufferBytes) _shared.largestBuffer = bytes;
  }
}

class _WorkMeter {
  int work = 0;
  int largestBuffer = 0;
}
