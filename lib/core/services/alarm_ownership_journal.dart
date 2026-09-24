export 'package:on_time_front/domain/entities/local_reset_result.dart'
    show ResetStep;
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'dart:convert';

import 'package:on_time_front/domain/entities/alarm_entities.dart';

abstract interface class AlarmJournalStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> remove();
}

/// Useful for ephemeral development hosts and isolated coordinator instances.
/// The product's shared coordinator always uses the independent file store.
final class MemoryAlarmJournalStore implements AlarmJournalStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> remove() async {
    value = null;
  }
}

class AlarmJournalUnavailable implements Exception {
  const AlarmJournalUnavailable();
}

/// Only syntax/encoding corruption is eligible for evidence-based recovery.
/// Valid JSON with an unsupported version or invalid state stays untouched.
final class AlarmJournalCorrupt extends AlarmJournalUnavailable {
  const AlarmJournalCorrupt();
}

final class AlarmJournalUnsupported extends AlarmJournalUnavailable {
  const AlarmJournalUnsupported();
}

abstract interface class RecoverableAlarmJournalStore
    implements AlarmJournalStore {
  Future<void> recoverCorrupt(String value);
}

enum ResetPhase { none, pending, complete }

/// This projection contains no title, timing, payload, fingerprint or key.
final class AlarmOwnership {
  AlarmOwnership(this.record, {required this.pending});
  final ScheduledAlarmRecord record;
  final bool pending;

  Map<String, Object?> toJson() => {
    'provider': record.provider.name,
    'scheduleId': record.scheduleId,
    if (record.provider == AlarmProvider.localNotification)
      'id': record.fallbackNotificationId ?? stableAlarmId(record.scheduleId),
    if (record.provider == AlarmProvider.androidAlarmManager)
      'id': record.nativeAlarmId ?? stableAlarmId(record.scheduleId),
    'pending': pending,
  };

  factory AlarmOwnership.fromJson(Map<String, dynamic> json) {
    final provider = AlarmProvider.values.byName(json['provider'] as String);
    final id = json['scheduleId'];
    final platformId = json['id'];
    if (id is! String ||
        id.isEmpty ||
        provider == AlarmProvider.none ||
        json['pending'] is! bool ||
        (provider != AlarmProvider.iosAlarmKit &&
            (platformId is! int ||
                platformId < -2147483648 ||
                platformId > 2147483647))) {
      throw const FormatException('Invalid ownership');
    }
    return AlarmOwnership(
      ScheduledAlarmRecord(
        scheduleId: id,
        provider: provider,
        nativeAlarmId: provider == AlarmProvider.androidAlarmManager
            ? json['id'] as int
            : null,
        fallbackNotificationId: provider == AlarmProvider.localNotification
            ? json['id'] as int
            : null,
        alarmTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        preparationStartTime: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        scheduleFingerprint: '',
        scheduleTitle: 'OnTime',
        payload: const {},
        cancellationPending: true,
      ),
      pending: json['pending'] as bool,
    );
  }
}

final class AlarmJournalSnapshot {
  AlarmJournalSnapshot({
    Map<String, AlarmOwnership>? ownership,
    this.reset = ResetPhase.none,
    this.unknownOwnership = false,
    Set<ResetStep>? completed,
  }) : ownership = ownership ?? {},
       completed = completed ?? {};
  final Map<String, AlarmOwnership> ownership;
  ResetPhase reset;
  bool unknownOwnership;
  final Set<ResetStep> completed;

  String encode() => jsonEncode({
    'version': 1,
    'reset': reset.name,
    'unknownOwnership': unknownOwnership,
    'completed': completed.map((step) => step.name).toList()..sort(),
    'ownership': ownership.values.map((entry) => entry.toJson()).toList(),
  });

  factory AlarmJournalSnapshot.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const AlarmJournalCorrupt();
    }
    if (decoded is Map<String, dynamic> &&
        decoded['version'] is int &&
        decoded['version'] != 1) {
      throw const AlarmJournalUnsupported();
    }
    try {
      final json = decoded as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException();
      final entries = (json['ownership'] as List)
          .map(
            (entry) => AlarmOwnership.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
      final completed = (json['completed'] as List)
          .map((value) => ResetStep.values.byName(value as String))
          .toList();
      final ownership = <String, AlarmOwnership>{};
      for (final entry in entries) {
        final key = alarmOwnershipKey(entry.record);
        if (ownership.containsKey(key)) throw const FormatException();
        ownership[key] = entry;
      }
      if (completed.toSet().length != completed.length) {
        throw const FormatException();
      }
      if (json['unknownOwnership'] != null &&
          json['unknownOwnership'] is! bool) {
        throw const FormatException();
      }
      final result = AlarmJournalSnapshot(
        unknownOwnership: json['unknownOwnership'] == true,
        reset: ResetPhase.values.byName(json['reset'] as String),
        completed: completed.toSet(),
        ownership: ownership,
      );
      if (result.reset == ResetPhase.none && result.completed.isNotEmpty ||
          result.completed.contains(ResetStep.deliveries) &&
              (result.ownership.isNotEmpty || result.unknownOwnership)) {
        throw const FormatException();
      }
      if (result.reset == ResetPhase.complete &&
          (result.ownership.isNotEmpty ||
              result.unknownOwnership ||
              result.completed.length != ResetStep.values.length)) {
        throw const FormatException();
      }
      return result;
    } catch (_) {
      throw const AlarmJournalUnavailable();
    }
  }
}

final class AlarmOwnershipJournal {
  AlarmOwnershipJournal(this.store);
  final AlarmJournalStore store;

  Future<AlarmJournalSnapshot> read() async {
    final raw = await store.read();
    return raw == null
        ? AlarmJournalSnapshot()
        : AlarmJournalSnapshot.decode(raw);
  }

  /// Called by startup/reset recovery under the same delivery owner. Rebuilt
  /// state comes only from independent evidence, never damaged reset receipts.
  Future<void> recoverCorrupt(AlarmJournalSnapshot value) async {
    final recoverable = store;
    if (recoverable is! RecoverableAlarmJournalStore) {
      throw const AlarmJournalUnavailable();
    }
    final encoded = value.encode();
    AlarmJournalSnapshot.decode(encoded);
    await recoverable.recoverCorrupt(encoded);
    if (await store.read() != encoded) throw const AlarmJournalUnavailable();
  }

  Future<void> save(AlarmJournalSnapshot value) async {
    final encoded = value.encode();
    AlarmJournalSnapshot.decode(encoded);
    await store.write(encoded);
    if (await store.read() != encoded) throw const AlarmJournalUnavailable();
  }

  Future<void> remember(
    Iterable<ScheduledAlarmRecord> records, {
    bool pending = true,
  }) async {
    final value = await read();
    for (final record in records) {
      if (record.provider == AlarmProvider.none) continue;
      value.ownership[alarmOwnershipKey(record)] = AlarmOwnership(
        record,
        pending: pending,
      );
    }
    await save(value);
  }

  /// Only the common cleanup engine may forget a confirmed provider ID.
  Future<void> confirmedCancelled(ScheduledAlarmRecord record) async {
    final value = await read();
    value.ownership.remove(alarmOwnershipKey(record));
    await save(value);
  }

  Future<void> removeCompleted() async {
    final value = await read();
    if (value.reset != ResetPhase.complete) {
      throw const AlarmJournalUnavailable();
    }
    await store.remove();
    if (await store.read() != null) throw const AlarmJournalUnavailable();
  }
}
