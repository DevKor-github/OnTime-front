import 'dart:async';
import 'dart:io';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_journal_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/my_page/cubit/detailed_notification_settings_cubit.dart';

import '../../helpers/schedule_deletion_fixture.dart';
import 'reconcile_alarms_use_case_test.dart'
    show
        FakeAlarmRegistryRepository,
        FakeAlarmSchedulerService,
        FakeFallbackAlarmNotificationService;

class _UnusedPreparation extends Fake implements PreparationRepository {}

class _DatabaseAlarms extends AlarmRepositoryImpl {
  _DatabaseAlarms(ScheduleDeletionFixture f)
    : super(
        database: f.db,
        scheduleRepository: f.schedules,
        preparationRepository: _UnusedPreparation(),
      );
  bool holdSettings = false;
  final readEntered = Completer<void>(), readRelease = Completer<void>();
  @override
  Future<AlarmSettings> getAlarmSettings() async {
    final actual = await super.getAlarmSettings();
    if (holdSettings) {
      holdSettings = false;
      readEntered.complete();
      await readRelease.future;
    }
    return actual;
  }
}

class _Native extends FakeAlarmSchedulerService {
  bool holdNext = false, failAfterHold = false;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    if (holdNext) {
      holdNext = false;
      entered.complete();
      await release.future;
      if (failAfterHold) {
        throw const AlarmSchedulingException(
          reason: AlarmFailureReason.platformError,
          message: 'synthetic native failure',
        );
      }
    }
    return super.scheduleNativeAlarm(record);
  }
}

class _JournalBarrier {
  _JournalBarrier(this.directory);
  final Directory directory;
  bool armed = false;
  final entered = Completer<void>(), release = Completer<void>();
  Future<void> checkpoint(String stage) async {
    if (!armed || stage != 'readBack') {
      return;
    }
    final raw = await File(
      '${directory.path}/ownership-v1.json',
    ).readAsString();
    if (AlarmJournalSnapshot.decode(raw).ownership.isEmpty) {
      return;
    }
    armed = false;
    entered.complete();
    await release.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScheduleDeletionFixture f;
  late DetailedNotificationPreferenceService preferences;
  late AlarmOperationCoordinator owner;
  late Directory journalDirectory;
  late _JournalBarrier journalBarrier;
  late _DatabaseAlarms repository;
  late FakeAlarmRegistryRepository registry;
  late _Native native;
  late FakeFallbackAlarmNotificationService fallback;
  late ReconcileAlarmsUseCase reconcile;
  late DetailedNotificationSettingsCubit controller;

  setUp(() async {
    f = ScheduleDeletionFixture();
    await f.initialize();
    await f.create('visit');
    preferences = DetailedNotificationPreferenceService(f.db, gate: f.gate);
    journalDirectory = await Directory.systemTemp.createTemp(
      'ontime-u03-journal-',
    );
    journalBarrier = _JournalBarrier(journalDirectory);
    owner = AlarmOperationCoordinator(
      f.gate,
      journal: AlarmOwnershipJournal(
        FileAlarmJournalStore(
          () async => journalDirectory,
          checkpoint: journalBarrier.checkpoint,
        ),
      ),
    );

    repository = _DatabaseAlarms(f);
    registry = FakeAlarmRegistryRepository();
    native = _Native()
      ..capabilities = const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.iosAlarmKit,
      );
    fallback = FakeFallbackAlarmNotificationService()
      ..permission = AlarmPermissionState.granted;
    reconcile = ReconcileAlarmsUseCase.test(
      repository,
      registry,
      native,
      fallback,
      operations: owner,
      nowProvider: () => DateTime.utc(2030, 1, 2, 9),
      languageCodeProvider: () => 'en',
      timeZoneProvider: () async => 'UTC',
    );
    controller = DetailedNotificationSettingsCubit.test(
      preferences,
      reconcile,
      operations: owner,
    );
  });
  tearDown(() async {
    if (!repository.readRelease.isCompleted) repository.readRelease.complete();
    if (!native.release.isCompleted) native.release.complete();
    if (!journalBarrier.release.isCompleted) {
      journalBarrier.release.complete();
    }
    await controller.close();
    await reconcile();
    owner.dispose();
    await f.close();
    await journalDirectory.delete(recursive: true);
  });

  Future<void> stateWhere(
    bool Function(DetailedNotificationSettingsState) match,
  ) async {
    if (match(controller.state)) return;
    await controller.stream
        .firstWhere(match)
        .timeout(const Duration(seconds: 10));
  }

  Future<void> durableOn() async {
    final permit = owner.acceptContentIntent(
      true,
      expectedGeneration: f.gate.generation,
    );
    final saved = await preferences.write(
      true,
      expectedGeneration: f.gate.generation,
    );
    owner.confirmContentIntent(permit, committedEnabled: saved.detailedEnabled);
  }

  test(
    'OFF accepted after old ON snapshot preserves a valid private registration',
    () async {
      await controller.refresh();
      expect(registry.records.single.deliveryContent.detailed, isFalse);
      final original = registry.records.single;
      await durableOn();
      repository.holdSettings = true;
      final running = reconcile();
      try {
        await repository.readEntered.future.timeout(
          const Duration(seconds: 10),
        );
        final oldPermit = owner.captureContentPermit();
        final off = owner.acceptContentIntent(false, expectedGeneration: 0);
        await preferences.write(false, expectedGeneration: 0);
        owner.confirmContentIntent(off, committedEnabled: false);
        expect(owner.allowsDetailed(oldPermit), isFalse);
        repository.readRelease.complete();
        final result = await running;
        expect(
          result.failures.map((e) => e.reason),
          contains(AlarmFailureReason.contentDeferred),
        );
        expect(native.canceledNative, isEmpty);
        expect(native.scheduledNative, hasLength(1));
        expect(registry.records.single, original);
        expect(fallback.scheduledFallback, isEmpty);
      } finally {
        if (!repository.readRelease.isCompleted) {
          repository.readRelease.complete();
        }
        await running;
      }
    },
  );

  test(
    'failed OFF and ON read-back block external detailed sends until a new ON intent',
    () async {
      await controller.refresh();
      await durableOn();
      owner.acceptContentIntent(false, expectedGeneration: 0);
      await controller.refresh();
      // The durable preference is ON, while the still-valid OS registration
      // remains private until a reconciliation actually replaces it.
      final sentBefore = native.scheduledNative.length;
      await f.db.customStatement(
        "CREATE TRIGGER reject_private BEFORE UPDATE OF "
        "detailed_notification_content ON users WHEN NEW.detailed_notification_content=0 "
        "BEGIN SELECT RAISE(ABORT,'synthetic private write failure'); END",
      );
      controller.request(false);
      await stateWhere((s) => s.save == DetailedPreferenceSave.failed);
      expect(controller.state.confirmedEnabled, isTrue);
      expect(controller.state.requestedEnabled, isFalse);
      expect(
        (await f.db.select(f.db.users).getSingle()).detailedNotificationContent,
        isTrue,
      );
      final held = owner.captureContentPermit();
      expect(owner.allowsDetailed(held), isFalse);
      // Force a real replacement need while keeping the same schedule identity.
      await f.db.customStatement(
        "UPDATE schedules SET schedule_name='Changed while held'",
      );
      await reconcile();
      expect(native.scheduledNative.length, sentBefore);
      expect(native.canceledNative, isEmpty);
      expect(registry.records.single.deliveryContent.detailed, isFalse);
      expect(fallback.scheduledFallback, isEmpty);
      await f.db.customStatement('DROP TRIGGER reject_private');
      controller.request(true);
      await stateWhere(
        (s) =>
            s.save == DetailedPreferenceSave.idle &&
            s.delivery == DetailedPreferenceDelivery.applied,
      );
      expect(native.scheduledNative.last.deliveryContent.detailed, isTrue);
      expect(
        native.scheduledNative.last.deliveryContent.title,
        contains('Changed while held'),
      );
      expect(owner.allowsDetailed(held), isFalse);
    },
  );

  test(
    'OFF DB commit does not wait for an already submitted native Future',
    () async {
      await controller.refresh();
      native.holdNext = true;
      controller.request(true);
      try {
        await native.entered.future.timeout(const Duration(seconds: 10));
        controller.request(false);
        await stateWhere(
          (s) =>
              s.confirmedEnabled == false &&
              s.save == DetailedPreferenceSave.idle,
        );
        expect(
          (await f.db.select(f.db.users).getSingle())
              .detailedNotificationContent,
          isFalse,
        );
        expect(native.release.isCompleted, isFalse);
        native.release.complete();
        await stateWhere(
          (s) => s.delivery == DetailedPreferenceDelivery.applied,
        );
        expect(registry.records.single.deliveryContent.detailed, isFalse);
        expect(native.scheduledNative.last.deliveryContent.detailed, isFalse);
      } finally {
        if (!native.release.isCompleted) native.release.complete();
      }
    },
  );

  test(
    'OFF during failing native send forbids its detailed fallback',
    () async {
      await durableOn();
      native.holdNext = true;
      native.failAfterHold = true;
      final running = reconcile();
      try {
        await native.entered.future.timeout(const Duration(seconds: 10));
        final off = owner.acceptContentIntent(false, expectedGeneration: 0);
        await preferences.write(false, expectedGeneration: 0);
        owner.confirmContentIntent(off, committedEnabled: false);
        native.release.complete();
        final result = await running;
        expect(fallback.scheduledFallback, isEmpty);
        expect(
          result.failures.map((e) => e.reason),
          contains(AlarmFailureReason.contentDeferred),
        );
      } finally {
        if (!native.release.isCompleted) native.release.complete();
        await running;
      }
    },
  );

  test(
    'saved OFF reports cancellation uncertainty without pretending OS became private',
    () async {
      await durableOn();
      await controller.refresh();
      native.throwOnCancelIds.add('visit');
      controller.request(false);
      await stateWhere(
        (s) => s.delivery == DetailedPreferenceDelivery.cancellationUnconfirmed,
      );
      expect(controller.state.confirmedEnabled, isFalse);
      expect(
        (await f.db.select(f.db.users).getSingle()).detailedNotificationContent,
        isFalse,
      );
      expect(native.scheduledNative.last.deliveryContent.detailed, isTrue);
      expect(native.pendingNative, contains('visit'));
      native.throwOnCancelIds.clear();
      await controller.retry();
      expect(controller.state.delivery, DetailedPreferenceDelivery.applied);
      expect(registry.records.single.deliveryContent.detailed, isFalse);
    },
  );

  test(
    'replacement scheduling gap is a failure even after preference saved',
    () async {
      await controller.refresh();
      native.throwOnScheduleIds.add('visit');
      fallback.throwOnScheduleIds.add('visit');
      controller.request(true);
      await stateWhere(
        (s) => s.delivery == DetailedPreferenceDelivery.schedulingFailed,
      );
      expect(controller.state.confirmedEnabled, isTrue);
      expect(native.pendingNative, isEmpty);
      expect(fallback.pendingFallback, isEmpty);
      expect(
        (await f.db.select(f.db.users).getSingle()).detailedNotificationContent,
        isTrue,
      );
    },
  );

  for (final useNative in [true, false]) {
    test(
      'ownership read-back then OFF prevents ${useNative ? 'native' : 'fallback'} detailed send',
      () async {
        if (!useNative) {
          native.capabilities = const AlarmSchedulerCapabilities(
            supportsNativeAlarm: false,
            nativeAlarmProvider: AlarmProvider.none,
          );
        }
        await durableOn();
        journalBarrier.armed = true;
        final running = reconcile();
        try {
          await Future.any([
            journalBarrier.entered.future,
            running.then<void>(
              (_) => fail('provider pass ended before ownership barrier'),
            ),
          ]).timeout(const Duration(seconds: 10));
          final raw = await File(
            '${journalDirectory.path}/ownership-v1.json',
          ).readAsString();
          final ownership = AlarmJournalSnapshot.decode(raw);
          expect(ownership.ownership, hasLength(1));
          expect(raw, isNot(contains('Name visit')));
          expect(raw, isNot(contains('Note visit')));
          expect(raw, isNot(contains('visit first')));
          final off = owner.acceptContentIntent(false, expectedGeneration: 0);
          await preferences.write(false, expectedGeneration: 0);
          owner.confirmContentIntent(off, committedEnabled: false);
          journalBarrier.release.complete();
          final result = await running;
          expect(
            result.failures.map((e) => e.reason),
            contains(AlarmFailureReason.contentDeferred),
          );
          expect(native.scheduledNative, isEmpty);
          expect(fallback.scheduledFallback, isEmpty);
          await reconcile();
          expect(registry.records.single.deliveryContent.detailed, isFalse);
          expect(
            (useNative ? native.scheduledNative : fallback.scheduledFallback)
                .single
                .deliveryContent
                .detailed,
            isFalse,
          );
        } finally {
          if (!journalBarrier.release.isCompleted) {
            journalBarrier.release.complete();
          }
          await running;
        }
      },
    );
  }

  test(
    'OFF during cancellation ownership read-back preserves the valid private OS alarm',
    () async {
      await controller.refresh();
      final privateRecord = registry.records.single;
      await durableOn();
      journalBarrier.armed = true;
      final running = reconcile();
      try {
        await Future.any([
          journalBarrier.entered.future,
          running.then<void>(
            (_) => fail('pass ended before cancellation ownership barrier'),
          ),
        ]).timeout(const Duration(seconds: 10));
        final off = owner.acceptContentIntent(false, expectedGeneration: 0);
        await preferences.write(false, expectedGeneration: 0);
        owner.confirmContentIntent(off, committedEnabled: false);
        journalBarrier.release.complete();
        final result = await running;
        expect(
          result.failures.map((e) => e.reason),
          contains(AlarmFailureReason.contentDeferred),
        );
        expect(native.canceledNative, isEmpty);
        expect(native.scheduledNative, hasLength(1));
        expect(native.pendingNative, contains('visit'));
        expect(registry.records.single, privateRecord);
        expect(fallback.scheduledFallback, isEmpty);
      } finally {
        if (!journalBarrier.release.isCompleted) {
          journalBarrier.release.complete();
        }
        await running;
      }
    },
  );

  test(
    'fresh runtime discards failed OFF intent and rereads durable ON with the existing file journal',
    () async {
      await controller.refresh();
      await durableOn();
      owner.acceptContentIntent(false, expectedGeneration: 0);
      await controller.refresh();
      expect(registry.records.single.deliveryContent.detailed, isFalse);
      await f.db.customStatement(
        "CREATE TRIGGER reject_off_restart BEFORE UPDATE OF "
        "detailed_notification_content ON users WHEN NEW.detailed_notification_content=0 "
        "BEGIN SELECT RAISE(ABORT,'synthetic failed OFF'); END",
      );
      controller.request(false);
      await stateWhere((s) => s.save == DetailedPreferenceSave.failed);
      expect(controller.state.confirmedEnabled, isTrue);
      expect(controller.state.requestedEnabled, isFalse);
      expect(owner.allowsDetailed(owner.captureContentPermit()), isFalse);
      final before = await f.db.select(f.db.users).getSingle();
      final raw = await File(
        '${journalDirectory.path}/ownership-v1.json',
      ).readAsString();
      expect(AlarmJournalSnapshot.decode(raw).ownership, hasLength(1));
      expect(raw, isNot(contains('requestedEnabled')));
      expect(raw, isNot(contains('Name visit')));
      await controller.close();
      owner.dispose();
      registry = FakeAlarmRegistryRepository();
      // Runtime recreation over the same actual DB and cold file read. This is
      // deliberately not called an OS process-kill or a database-reopen test.
      owner = AlarmOperationCoordinator(
        f.gate,
        journal: AlarmOwnershipJournal(
          FileAlarmJournalStore(() async => journalDirectory),
        ),
      );
      reconcile = ReconcileAlarmsUseCase.test(
        repository,
        registry,
        native,
        fallback,
        operations: owner,
        nowProvider: () => DateTime.utc(2030, 1, 2, 9),
        languageCodeProvider: () => 'en',
        timeZoneProvider: () async => 'UTC',
      );
      controller = DetailedNotificationSettingsCubit.test(
        preferences,
        reconcile,
        operations: owner,
      );
      expect(controller.state.requestedEnabled, isNull);
      await controller.refresh();
      expect(controller.state.confirmedEnabled, isTrue);
      expect(controller.state.requestedEnabled, isNull);
      expect(controller.state.delivery, DetailedPreferenceDelivery.applied);
      expect(registry.records.single.deliveryContent.detailed, isTrue);
      expect(native.scheduledNative.last.deliveryContent.detailed, isTrue);
      final after = await f.db.select(f.db.users).getSingle();
      expect(after.dataRevision, before.dataRevision);
      expect(after.storeIncarnation, before.storeIncarnation);
      expect(after.detailedNotificationContent, isTrue);
    },
  );
}
