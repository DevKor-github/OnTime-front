import 'dart:async';
import 'alarm_ownership_journal.dart';
import 'alarm_journal_store.dart';

import 'package:flutter/foundation.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

/// One owner for schedule delivery effects. A timeout never releases this owner:
/// only completion of the underlying platform Future releases its queue slot.
final class AlarmOperationCoordinator extends ChangeNotifier {
  AlarmOperationCoordinator(this.gate, {AlarmOwnershipJournal? journal})
    : journal = journal ?? AlarmOwnershipJournal(MemoryAlarmJournalStore()) {
    gate.addListener(notifyListeners);
  }

  static final shared = AlarmOperationCoordinator(
    LocalDataOperationGate.shared,
    journal: AlarmOwnershipJournal(createProductAlarmJournalStore()),
  );
  final LocalDataOperationGate gate;
  final AlarmOwnershipJournal journal;
  Future<void> _tail = Future<void>.value();
  final _unpersisted = Expando<Map<String, ScheduledAlarmRecord>>();

  int get generation => gate.generation;
  bool get canSchedule => !gate.isReplacingData && !gate.isInvalidated;

  AlarmOperationLease capture() {
    final lease = AlarmOperationLease._(this, generation);
    lease.check();
    return lease;
  }

  Future<T> run<T>(AlarmOperationLease lease, Future<T> Function() action) =>
      _enqueue(() async {
        lease.check();
        return action();
      });

  /// Called inside the replacement gate. This does not await gate release or
  /// enqueue a normal reconciliation, which would deadlock the replacement.
  Future<T> cleanup<T>(Future<T> Function() action) => _enqueue(action);

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<ScheduledAlarmRecord>> loadRecords(
    AlarmRegistryRepository registry,
  ) async {
    final stored = await registry.loadAll();
    final durable = await journal.read();
    if (registry is AlarmOwnershipIntegrity &&
        await (registry as AlarmOwnershipIntegrity).hasUnresolvedOwnership() &&
        !durable.unknownOwnership) {
      durable.unknownOwnership = true;
      await journal.save(durable);
    }
    final merged = {
      for (final record in stored) alarmOwnershipKey(record): record,
      ...?_unpersisted[registry],
    };
    for (final entry in durable.ownership.entries) {
      if (entry.value.pending || !merged.containsKey(entry.key)) {
        final known = merged[entry.key];
        // The independent journal deliberately has no timing receipt. Preserve
        // a known enum from the registry without reviving its private content.
        merged[entry.key] = known == null
            ? entry.value.record
            : ownershipOnly(known);
      }
    }
    return merged.values.toList();
  }

  Future<void> remember(
    AlarmRegistryRepository registry,
    List<ScheduledAlarmRecord> records,
  ) async {
    await journal.remember(records);
    final memory = _unpersisted[registry] ??= {};
    for (final record in records) {
      memory[alarmOwnershipKey(record)] = ownershipOnly(record);
    }
    // Keep memory until the final write succeeds, including when disk fails.
    await registry.replaceAll(await loadRecords(registry));
  }

  Future<void> replaceRecords(
    AlarmRegistryRepository registry,
    List<ScheduledAlarmRecord> records,
  ) async {
    try {
      await registry.replaceAll(records);
      await journal.remember(
        records.where((r) => !r.cancellationPending),
        pending: false,
      );
      _unpersisted[registry] = null;
    } catch (_) {
      final memory = _unpersisted[registry] ??= {};
      for (final record in records) {
        memory[alarmOwnershipKey(record)] = ownershipOnly(record);
      }
      rethrow;
    }
  }

  Future<void> confirmedCancelled(
    AlarmRegistryRepository registry,
    ScheduledAlarmRecord record,
  ) async {
    await journal.confirmedCancelled(record);
    _unpersisted[registry]?.remove(alarmOwnershipKey(record));
  }

  static ScheduledAlarmRecord ownershipOnly(ScheduledAlarmRecord record) =>
      ScheduledAlarmRecord(
        scheduleId: record.scheduleId,
        provider: record.provider,
        nativeAlarmId: record.nativeAlarmId,
        fallbackNotificationId: record.fallbackNotificationId,
        alarmTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        preparationStartTime: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        scheduleFingerprint: '',
        scheduleTitle: 'OnTime',
        payload: const {},
        notificationTiming: record.notificationTiming,
        cancellationPending: true,
      );

  @override
  void dispose() {
    gate.removeListener(notifyListeners);
    super.dispose();
  }
}

final class AlarmOperationLease {
  AlarmOperationLease._(this._owner, this.generation);
  final AlarmOperationCoordinator _owner;
  final int generation;
  bool get isCurrent => _owner.generation == generation && _owner.canSchedule;
  void check() {
    if (!isCurrent) throw const AlarmOperationInvalidated();
  }
}

final class AlarmOperationInvalidated implements Exception {
  const AlarmOperationInvalidated();
}

enum AlarmCleanupStatus { complete, partial, unconfirmed }

final class AlarmCleanupReport {
  const AlarmCleanupReport(
    this.targeted,
    this.failed, {
    this.unknownOwnership = false,
  });
  final int targeted;
  final int failed;
  final bool unknownOwnership;
  bool get isComplete => failed == 0 && !unknownOwnership;
  AlarmCleanupStatus get status => isComplete
      ? AlarmCleanupStatus.complete
      : unknownOwnership || failed == targeted
      ? AlarmCleanupStatus.unconfirmed
      : AlarmCleanupStatus.partial;
}

final class AlarmCleanupIncomplete implements Exception {
  const AlarmCleanupIncomplete({this.report});
  final AlarmCleanupReport? report;
}
