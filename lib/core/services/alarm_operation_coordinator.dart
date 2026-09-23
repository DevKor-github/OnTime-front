import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

/// One owner for schedule delivery effects. A timeout never releases this owner:
/// only completion of the underlying platform Future releases its queue slot.
final class AlarmOperationCoordinator extends ChangeNotifier {
  AlarmOperationCoordinator(this.gate) {
    gate.addListener(notifyListeners);
  }

  static final shared = AlarmOperationCoordinator(
    LocalDataOperationGate.shared,
  );
  final LocalDataOperationGate gate;
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
    return {
      for (final record in stored) alarmOwnershipKey(record): record,
      ...?_unpersisted[registry],
    }.values.toList();
  }

  Future<void> remember(
    AlarmRegistryRepository registry,
    List<ScheduledAlarmRecord> records,
  ) async {
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
      _unpersisted[registry] = null;
    } catch (_) {
      final memory = _unpersisted[registry] ??= {};
      for (final record in records) {
        memory[alarmOwnershipKey(record)] = ownershipOnly(record);
      }
      rethrow;
    }
  }

  static ScheduledAlarmRecord ownershipOnly(ScheduledAlarmRecord record) =>
      ScheduledAlarmRecord(
        scheduleId: record.scheduleId,
        provider: record.provider,
        nativeAlarmId: record.nativeAlarmId,
        fallbackNotificationId: record.fallbackNotificationId,
        alarmTime: record.alarmTime,
        preparationStartTime: record.preparationStartTime,
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

final class AlarmCleanupIncomplete implements Exception {
  const AlarmCleanupIncomplete();
}
