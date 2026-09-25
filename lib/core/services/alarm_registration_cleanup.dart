import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

/// Invoked only by the schedule-delivery owner, including replacement cleanup.
/// Provider cancellation already performs its platform-specific read-back.
final class AlarmRegistrationCleanup {
  AlarmRegistrationCleanup(
    this.registry,
    this.scheduler,
    this.fallback,
    this.operations,
  );
  final AlarmRegistryRepository registry;
  final AlarmSchedulerService scheduler;
  final FallbackAlarmNotificationService fallback;
  final AlarmOperationCoordinator operations;

  /// Read-only provider evidence for syntactically damaged journals. This uses
  /// the same A14 observation ports/identity rules as reconciliation; it never
  /// cancels, schedules, or infers reset progress from damaged bytes.
  Future<AlarmJournalSnapshot> reconstructOwnership({
    Iterable<ScheduledAlarmRecord> durableRecords = const [],
  }) async {
    final stored = await registry.loadAll();
    final ownership = <String, AlarmOwnership>{};
    var identityConflict = false;
    void retain(ScheduledAlarmRecord record) {
      if (record.provider == AlarmProvider.none) return;
      final key = alarmOwnershipKey(record);
      final previous = ownership[key];
      if (previous != null && previous.record.scheduleId != record.scheduleId) {
        identityConflict = true;
        return;
      }
      ownership[key] = AlarmOwnership(
        AlarmOperationCoordinator.ownershipOnly(record),
        pending: true,
      );
    }

    for (final record in [...stored, ...durableRecords]) {
      retain(record);
    }

    DeliveryObservation notifications;
    try {
      notifications = await fallback.observePending();
    } catch (_) {
      notifications = const DeliveryObservation.unknown();
    }
    for (final entry in notifications.entries) {
      final id = int.tryParse(entry.id);
      final scheduleId = entry.scheduleId;
      if (!notifications.available ||
          scheduleId == null ||
          scheduleId.isEmpty ||
          id == null ||
          id < -2147483648 ||
          id > 2147483647) {
        continue;
      }
      retain(
        ScheduledAlarmRecord(
          scheduleId: scheduleId,
          provider: AlarmProvider.localNotification,
          fallbackNotificationId: id,
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
      );
    }

    DeliveryObservation native;
    try {
      native = await scheduler.observePendingNativeAlarms(
        ownership.values.map((entry) => entry.record.scheduleId).toSet(),
      );
    } catch (_) {
      native = const DeliveryObservation.unknown();
    }
    // The native port only maps IDs the app supplied. Never invert an AlarmKit
    // UUID or manufacture a Schedule identity for an unmapped native alarm.
    final knownNativeIds = ownership.values
        .map((entry) => entry.record.scheduleId)
        .toSet();
    for (final entry in native.entries) {
      if (!native.available ||
          native.source != DeliveryObservationSource.iosAlarmKit ||
          entry.scheduleId == null ||
          !knownNativeIds.contains(entry.scheduleId) ||
          entry.id != entry.scheduleId) {
        continue;
      }
      final base = ownership.values.firstWhere(
        (known) => known.record.scheduleId == entry.scheduleId,
      );
      retain(base.record.copyWith(provider: AlarmProvider.iosAlarmKit));
    }
    final allNotificationsMapped = notifications.entries.every((entry) {
      final id = int.tryParse(entry.id);
      return id != null && ownership.containsKey('localNotification:$id');
    });
    final allNativeMapped = native.entries.every(
      (entry) =>
          entry.scheduleId != null &&
          entry.id == entry.scheduleId &&
          ownership.containsKey('iosAlarmKit:${entry.scheduleId}'),
    );
    final completeOsEvidence =
        notifications.available &&
        notifications.source ==
            DeliveryObservationSource.iosNotificationCenter &&
        notifications.unmappedCount == 0 &&
        allNotificationsMapped &&
        native.available &&
        native.source == DeliveryObservationSource.iosAlarmKit &&
        native.unmappedCount == 0 &&
        allNativeMapped &&
        ownership.values.every(
          (entry) => entry.record.provider != AlarmProvider.androidAlarmManager,
        ) &&
        !identityConflict;
    return AlarmJournalSnapshot(
      ownership: ownership,
      unknownOwnership: !completeOsEvidence,
    );
  }

  /// Retryable after a crash between journal verification and marker removal.
  /// A marker by itself never authorizes deletion of application data.
  Future<AlarmJournalSnapshot> resolveLegacyIntegrity(
    AlarmJournalSnapshot state,
  ) async {
    final integrity = registry;
    final hasLegacyMarker =
        integrity is AlarmOwnershipIntegrity &&
        await (integrity as AlarmOwnershipIntegrity).hasUnresolvedOwnership();
    if (!state.unknownOwnership && !hasLegacyMarker) return state;
    final observed = await reconstructOwnership(
      durableRecords: state.ownership.values.map((entry) => entry.record),
    );
    // Save all observed IDs even when platform absence cannot be proved.
    state.ownership.addAll(observed.ownership);
    state.unknownOwnership =
        observed.unknownOwnership ||
        (hasLegacyMarker && integrity is! RecoverableAlarmOwnershipIntegrity);
    await operations.journal.save(state);
    state = await operations.journal.read();
    if (!state.unknownOwnership && hasLegacyMarker) {
      try {
        await (integrity as RecoverableAlarmOwnershipIntegrity)
            .clearResolvedOwnership();
        if (await (integrity as RecoverableAlarmOwnershipIntegrity)
            .hasUnresolvedOwnership()) {
          throw const AlarmJournalUnavailable();
        }
      } catch (_) {
        state.unknownOwnership = true;
        await operations.journal.save(state);
        rethrow;
      }
    }
    return state;
  }

  Future<List<ScheduledAlarmRecord>> cancelRecords(
    List<ScheduledAlarmRecord> records, {
    bool Function()? isCurrent,
    Future<bool> Function()? isStillOwned,
  }) async {
    Future<void> check() async {
      if (!(isCurrent?.call() ?? true) ||
          !(await isStillOwned?.call() ?? true) ||
          !(isCurrent?.call() ?? true)) {
        throw const AlarmOperationInvalidated();
      }
    }

    await check();
    if (records.isNotEmpty) await operations.remember(registry, records);
    await check();
    final failed = <ScheduledAlarmRecord>[];
    for (final record in records) {
      await check();
      try {
        if (record.provider == AlarmProvider.localNotification) {
          await fallback.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          await scheduler.cancelNativeAlarm(record);
        }
        await check();
        await operations.confirmedCancelled(registry, record);
        await check();
      } on AlarmOperationInvalidated {
        rethrow;
      } catch (_) {
        failed.add(AlarmOperationCoordinator.ownershipOnly(record));
      }
    }
    return failed;
  }

  Future<void> cancelMatching({String? scheduleId}) async {
    final report = await cancelMatchingReport(scheduleId: scheduleId);
    if (!report.isComplete) throw AlarmCleanupIncomplete(report: report);
  }

  Future<AlarmCleanupReport> cancelMatchingReport({
    String? scheduleId,
    bool Function()? isCurrent,
    Future<bool> Function()? isStillOwned,
  }) async {
    Future<void> check() async {
      if (!(isCurrent?.call() ?? true) ||
          !(await isStillOwned?.call() ?? true) ||
          !(isCurrent?.call() ?? true)) {
        throw const AlarmOperationInvalidated();
      }
    }

    await check();
    final stored = await operations.loadRecords(registry);
    await check();
    final targets = stored
        .where(
          (record) => scheduleId == null || record.scheduleId == scheduleId,
        )
        .toList();
    final failed = await cancelRecords(
      targets,
      isCurrent: isCurrent,
      isStillOwned: isStillOwned,
    );
    await check();
    await operations.replaceRecords(registry, [
      if (scheduleId != null)
        ...stored.where((record) => record.scheduleId != scheduleId),
      ...failed,
    ]);
    await check();
    return AlarmCleanupReport(
      targets.length,
      failed.length,
      unknownOwnership: (await operations.journal.read()).unknownOwnership,
    );
  }
}
