// Separate synthetic QA bundle only. This is not the production entry point.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/database/sqlcipher_loader.dart';
import 'package:on_time_front/core/services/alarm_journal_store.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/local_time_zone_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/time/device_civil_day.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/timed_preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

const _runId = String.fromEnvironment('ONTIME_A10_QA_RUN');
const _actions = ['seed', 'observe', 'start', 'reconcile', 'cleanup'];

class _ProbeCheckFailure implements Exception {
  const _ProbeCheckFailure(this.check);
  final String check;
}

void _require(bool condition, String check) {
  if (!condition) throw _ProbeCheckFailure(check);
}

Object? _jsonValue(Object? value) =>
    value is DateTime ? value.toUtc().toIso8601String() : value.toString();
String _encode(Object? value) => jsonEncode(value, toEncodable: _jsonValue);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final package = await PackageInfo.fromPlatform();
  if (!RegExp(r'^[a-zA-Z0-9-]{1,48}$').hasMatch(_runId) ||
      !(package.packageName == 'club.devkor.ontime.qa.a10' ||
          package.packageName.startsWith('club.devkor.ontime.qa.a10.'))) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'A10 QA bundle and run identity required. No data opened.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  // Production registry/runtime implementations, isolated within this QA run.
  SharedPreferences.setPrefix('a10_time_zone_probe.$_runId.');
  TimeZoneRules.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(
    '${(await getApplicationSupportDirectory()).path}/a10-time-zone-probe/$_runId',
  );
  await root.create(recursive: true);
  await excludeLocalDatabaseFromPlatformBackup(File(root.path));
  final command = File('${documents.path}/a10-probe-command.json');
  var action = 'observe';
  String? target;
  if (await command.exists()) {
    final value =
        jsonDecode(await command.readAsString()) as Map<String, dynamic>;
    _require(value['run'] == _runId, 'command run mismatch');
    action = value['action'] as String;
    target = value['targetUtc'] as String?;
  }
  final probe = _Probe(root, documents, package.packageName);
  runApp(_ProbeApp(probe, action, target));
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp(this.probe, this.initialAction, this.target);
  final _Probe probe;
  final String initialAction;
  final String? target;
  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  bool busy = false;
  String result = 'Starting synthetic QA probe';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => perform(widget.initialAction),
    );
  }

  Future<void> perform(String action) async {
    if (busy) return;
    setState(() => busy = true);
    final value = await widget.probe.perform(
      action,
      targetLiteral: widget.target,
    );
    if (mounted) {
      setState(() {
        result = const JsonEncoder.withIndent('  ').convert(value);
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('A10 synthetic native probe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Run: $_runId\nOnly the dedicated QA installation is used. This screen is not home UI or notification-tap evidence.',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final action in _actions)
                  FilledButton(
                    onPressed: busy ? null : () => perform(action),
                    child: Text(action),
                  ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            SelectableText(result),
          ],
        ),
      ),
    ),
  );
}

class _Probe {
  _Probe(this.root, this.documents, this.packageName);
  final Directory root, documents;
  final String packageName;
  String get explicitId => 'a10-$_runId-explicit';
  String get legacyId => 'a10-$_runId-unique-null';
  File get dbFile => File('${root.path}/synthetic.sqlite');
  File get keyFile => File('${root.path}/synthetic-key.txt');
  File get checkpoint => File('${root.path}/checkpoint.json');

  Future<Map<String, Object?>> _raw(AppDatabase db) async => {
    'schedules': [
      for (final r
          in await db.customSelect('SELECT * FROM schedules ORDER BY id').get())
        r.data,
    ],
    'users': [
      for (final r
          in await db.customSelect('SELECT * FROM users ORDER BY id').get())
        r.data,
    ],
    'preparationDefinitions': [
      for (final r
          in await db
              .customSelect('SELECT * FROM preparation_definitions ORDER BY id')
              .get())
        r.data,
    ],
    'preparationSteps': [
      for (final r
          in await db
              .customSelect(
                'SELECT * FROM preparation_definition_steps ORDER BY id',
              )
              .get())
        r.data,
    ],
  };
  String _digest(Object value) =>
      sha256.convert(utf8.encode(_encode(value))).toString();
  Map<String, Object?> _observation(DeliveryObservation value) => {
    'source': value.source.name,
    'available': value.available,
    'isOsObservation': value.isOsObservation,
    'unmappedCount': value.unmappedCount,
    'entries': [
      for (final entry in value.entries)
        {'id': entry.id, 'scheduleId': entry.scheduleId},
    ],
  };

  Future<Map<String, Object?>> perform(
    String action, {
    String? targetLiteral,
  }) async {
    final output = <String, Object?>{
      'run': _runId,
      'action': action,
      'packageName': packageName,
      'platform': Platform.operatingSystem,
      'processId': pid,
      'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'completed': false,
      'scope':
          'Real native zone channel, SQLCipher and production repository/reconcile implementations in a synthetic QA bundle. Home UI, notification taps and physical-device status require separate evidence.',
    };
    var phase = 'validate action';
    AppDatabase? db;
    ScheduleRepositoryImpl? schedules;
    PreparationRepositoryImpl? preparation;
    UserRepositoryImpl? users;
    AlarmOperationCoordinator? operations;
    try {
      _require(_actions.contains(action), 'unknown action');
      phase = 'native zone';
      final zone = await LocalTimeZoneService.current();
      output['nativeZone'] = zone;
      final localNow = DateTime.now();
      output['dartDeviceOffsetSeconds'] = localNow.timeZoneOffset.inSeconds;
      output['dartDeviceTimeZoneName'] = localNow.timeZoneName;
      output['loadedRulesIdentity'] = TimeZoneRules.loadedIdentity;
      final creating = action == 'seed';
      if (creating) {
        _require(
          !await dbFile.exists() &&
              !await keyFile.exists() &&
              !await checkpoint.exists(),
          'seed never overwrites an existing run',
        );
        final random = Random.secure();
        final key = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await keyFile.writeAsString(key, flush: true);
        await excludeLocalDatabaseFromPlatformBackup(keyFile);
      } else {
        _require(
          await dbFile.exists() &&
              await keyFile.exists() &&
              await checkpoint.exists(),
          'seed required',
        );
      }
      phase = 'open actual SQLCipher';
      final key = await keyFile.readAsString();
      configureSqlCipherLoader();
      db = AppDatabase.forTesting(
        NativeDatabase(
          dbFile,
          setup: (raw) => guardEncryptedDatabase(
            raw,
            key,
            role: creating
                ? DatabaseOpenRole.ownedCreation
                : DatabaseOpenRole.activePairStartup,
            allowCreation: creating,
          ),
        ),
      );
      final cipher = await db.customSelect('PRAGMA cipher_version').getSingle();
      output['cipherVersion'] = cipher.data.values.single;
      await excludeLocalDatabaseFromPlatformBackup(dbFile);
      final recurring = RecurringScheduleRepositoryImpl(db);
      final timed = TimedPreparationRepositoryImpl(
        localDataSource: PreparationWithTimeLocalDataSourceImpl(),
      );
      schedules = ScheduleRepositoryImpl(
        database: db,
        timedPreparationRepository: timed,
        recurringScheduleRepository: recurring,
      );
      if (creating) {
        phase = 'seed fixed synthetic targets';
        final requested = targetLiteral == null
            ? DateTime.now().toUtc().add(const Duration(hours: 3))
            : DateTime.parse(targetLiteral);
        _require(
          requested.isUtc &&
              requested.isAfter(
                DateTime.now().toUtc().add(const Duration(minutes: 10)),
              ),
          'target must be explicit future UTC',
        );
        final target = DateTime.utc(
          requested.year,
          requested.month,
          requested.day,
          requested.hour,
          requested.minute,
          requested.second,
          123,
          456,
        );
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration(minutes: 5),
            note: 'A10 synthetic profile',
            isOnboardingCompleted: true,
          ),
        );
        for (final legacy in [false, true]) {
          final instant = target.add(Duration(minutes: legacy ? 15 : 0));
          final civil = CivilDateTime.fromFields(
            tz.TZDateTime.from(instant, tz.getLocation('Asia/Seoul')),
          ).toUtcCarrier();
          final id = legacy ? legacyId : explicitId;
          await schedules.createSchedule(
            ScheduleEntity(
              id: id,
              place: PlaceEntity(
                id: '$id-place',
                placeName: 'Synthetic QA place',
              ),
              scheduleName: legacy ? 'A10 unique null' : 'A10 explicit',
              scheduleTime: civil,
              timeZoneId: 'Asia/Seoul',
              occurrenceOffsetSeconds: legacy ? null : 32400,
              moveTime: const Duration(minutes: 2),
              isChanged: false,
              isStarted: false,
              scheduleSpareTime: null,
              scheduleNote: 'Synthetic precision fixture',
            ),
          );
        }
        await db.userDao.updateAlarmSettings(
          userId: 'local-profile',
          enabled: true,
        );
        output['seedTargetUtc'] = target.toIso8601String();
      }
      await RestoreRuntimeIdentity.shared.load(db);
      final before = await _raw(db);
      final saved = creating
          ? null
          : jsonDecode(await checkpoint.readAsString()) as Map<String, dynamic>;
      if (saved != null) {
        _require(
          _digest(before) == saved['portableDigest'],
          'reopen or zone change modified portable data',
        );
      }
      output['beforeDigest'] = _digest(before);
      phase = 'read schedule and runtime';
      Future<Map<String, Object?>> read(String id) async {
        final row = await schedules!.getScheduleById(id);
        final resolution = ScheduleTimeResolver.resolve(
          row,
          nowUtc: DateTime.now().toUtc(),
        );
        final instant = resolution.instantUtc;
        _require(instant != null, 'synthetic target became unresolved');
        final prep = await readSchedulePreparation(db!, row);
        final runtime =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              row,
              PreparationWithTimeEntity.fromPreparation(prep),
              timeResolution: resolution,
            );
        final device = instant!.toLocal();
        final day = DeviceCivilDay.at(instant);
        final cached = await timed.getTimedPreparationSnapshot(id);
        return {
          'id': id,
          'civil': CivilDateTime.fromFields(
            row.scheduleTime,
          ).toCivilIso8601String(),
          'zone': row.timeZoneId,
          'storedOffsetSeconds': row.occurrenceOffsetSeconds,
          'instantUtc': instant.toIso8601String(),
          'fingerprint': runtime.cacheFingerprint,
          'deviceCivil': CivilDateTime.fromFields(
            device,
          ).toCivilIso8601String(),
          'deviceOffsetSeconds': device.timeZoneOffset.inSeconds,
          'deviceDayStartUtc': day.startUtc.toIso8601String(),
          'deviceDayEndUtc': day.endUtc.toIso8601String(),
          'deviceDayHours': day.endUtc.difference(day.startUtc).inMinutes / 60,
          'startedAtUtc': row.startedAt?.toUtc().toIso8601String(),
          'frozen': row.preparationFrozen,
          'isStarted': row.isStarted,
          'cachedFingerprint': cached?.scheduleFingerprint,
          'cachedStartedAtUtc': cached?.startedAt?.toUtc().toIso8601String(),
          'cacheRequiresConfirmation': cached?.requiresConfirmation,
        };
      }

      final beforeRecords = [await read(explicitId), await read(legacyId)];
      if (saved != null) {
        final records = saved['records'] as List;
        for (var i = 0; i < records.length; i++) {
          _require(
            beforeRecords[i]['instantUtc'] == records[i]['instantUtc'],
            'target instant changed',
          );
          _require(
            beforeRecords[i]['fingerprint'] == records[i]['fingerprint'],
            'runtime fingerprint changed across restart or zone',
          );
          for (final field in [
            'cachedFingerprint',
            'cachedStartedAtUtc',
            'cacheRequiresConfirmation',
          ]) {
            _require(
              beforeRecords[i][field] == records[i][field],
              'cached runtime changed across restart or zone',
            );
          }
        }
      }
      _require(
        _digest(await _raw(db)) == _digest(before),
        'read changed portable data',
      );
      output['readOnlyInvariant'] = true;
      if (action == 'start') {
        phase = 'public first start and durable runtime';
        final fingerprint = beforeRecords.last['fingerprint'];
        final hadStart = beforeRecords.last['startedAtUtc'] != null;
        final beforeRevision =
            ((before['users'] as List).single as Map)['data_revision'] as int;
        final started = await schedules.startSchedule(
          legacyId,
          startedAt: DateTime.now().toUtc(),
        );
        final row = await schedules.getScheduleById(legacyId);
        final resolved = ScheduleTimeResolver.resolve(
          row,
          nowUtc: DateTime.now().toUtc(),
        );
        final prep = PreparationWithTimeEntity.fromPreparation(
          await readSchedulePreparation(db, row),
        );
        final runtime =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              row,
              prep,
              timeResolution: resolved,
            );
        _require(
          row.occurrenceOffsetSeconds == 32400 &&
              row.preparationFrozen &&
              row.startedAt?.toUtc() == started.toUtc(),
          'first start fact mismatch',
        );
        _require(
          runtime.cacheFingerprint == fingerprint,
          'first start changed target fingerprint',
        );
        await timed.saveTimedPreparationSnapshot(
          legacyId,
          TimedPreparationSnapshotEntity(
            preparation: prep,
            savedAt: DateTime.now().toUtc(),
            startedAt: started,
            scheduleFingerprint: runtime.cacheFingerprint,
          ),
        );
        final committedRaw = await _raw(db);
        final afterRevision =
            ((committedRaw['users'] as List).single as Map)['data_revision']
                as int;
        _require(
          afterRevision == beforeRevision + (hadStart ? 0 : 1),
          'start revision changed unexpectedly',
        );
        output['startRevisionDelta'] = afterRevision - beforeRevision;
        final committed = _digest(committedRaw);
        final repeated = await schedules.startSchedule(
          legacyId,
          startedAt: DateTime.now().toUtc(),
        );
        _require(
          repeated.toUtc() == started.toUtc() &&
              _digest(await _raw(db)) == committed,
          'repeated start changed facts',
        );
        output['startReceiptUtc'] = started.toUtc().toIso8601String();
        output['startIdempotent'] = true;
      }
      if (action == 'reconcile' || action == 'cleanup') {
        phase = 'native delivery owner';
        final registry = AlarmRegistryRepositoryImpl(
          localDataSource: AlarmRegistryLocalDataSourceImpl(),
        );
        _require(
          (await registry.loadAll()).every(
            (r) => r.scheduleId.startsWith('a10-$_runId-'),
          ),
          'foreign registry ownership',
        );
        operations = AlarmOperationCoordinator(
          LocalDataOperationGate.shared,
          journal: AlarmOwnershipJournal(
            FileAlarmJournalStore(
              () async => Directory('${root.path}/alarm-journal'),
              excludeFromBackup: (path) =>
                  excludeLocalDatabaseFromPlatformBackup(File(path)),
            ),
          ),
        );
        // Actual platform plugin; the injectable constructor only selects the
        // isolated durable owner. No scheduling/provider method is mocked.
        // ignore: invalid_use_of_visible_for_testing_member
        final notifications = NotificationService.test(
          localNotifications: FlutterLocalNotificationsPlugin(),
          alarmOwner: operations,
        );
        await notifications.initialize();
        final scheduler = AlarmSchedulerService();
        final fallback = FallbackAlarmNotificationServiceImpl(
          notificationService: notifications,
        );
        if (action == 'cleanup') {
          await CancelAllAlarmsUseCase(
            registry,
            scheduler,
            fallback,
            operations: operations,
          ).call();
        } else {
          users = UserRepositoryImpl(db);
          preparation = PreparationRepositoryImpl(
            preparationLocalDataSource: PreparationLocalDataSourceImpl(
              appDatabase: db,
            ),
            userRepository: users,
            database: db,
          );
          final alarmRepository = AlarmRepositoryImpl(
            database: db,
            scheduleRepository: schedules,
            preparationRepository: preparation,
            recurringScheduleRepository: recurring,
          );
          final result = await ReconcileAlarmsUseCase(
            alarmRepository,
            registry,
            scheduler,
            fallback,
            operations: operations,
          ).call();
          output['reconciliation'] = {
            'status': result.status.name,
            'permissionIssue': result.permissionIssue?.name,
            'armedIds': result.armedScheduleIds,
            'skippedCount': result.skippedScheduleCount,
            'failures': [
              for (final failure in result.failures)
                {
                  'scheduleId': failure.scheduleId,
                  'reason': failure.reason.name,
                },
            ],
          };
        }
        output['registry'] = [
          for (final record in await registry.loadAll())
            {
              'scheduleId': record.scheduleId,
              'provider': record.provider.name,
              'alarmTimeUtc': record.alarmTime.toUtc().toIso8601String(),
              'preparationStartUtc': record.preparationStartTime
                  .toUtc()
                  .toIso8601String(),
              'fingerprint': record.scheduleFingerprint,
              'cancellationPending': record.cancellationPending,
              'timing': record.notificationTiming?.name,
            },
        ];
        output['fallbackObservation'] = _observation(
          await fallback.observePending(),
        );
        output['nativeObservation'] = _observation(
          await scheduler.observePendingNativeAlarms([explicitId, legacyId]),
        );
      }
      phase = 'final readback';
      final after = await _raw(db);
      if (action != 'start') {
        _require(
          _digest(before) == _digest(after),
          'read or reconcile changed portable facts',
        );
      }
      output['afterDigest'] = _digest(after);
      output['records'] = [await read(explicitId), await read(legacyId)];
      final state = {
        'portableDigest': output['afterDigest'],
        'records': output['records'],
      };
      await checkpoint.writeAsString(_encode(state), flush: true);
      output['completed'] = true;
    } catch (error) {
      output['failurePhase'] = phase;
      // Never print SQL, key bytes, arbitrary platform messages or host paths.
      output['failureType'] = error.runtimeType.toString();
      if (error is _ProbeCheckFailure) output['failedCheck'] = error.check;
    } finally {
      final failures = <String>[];
      for (final close in <Future<void> Function()>[
        () async {
          await preparation?.dispose();
        },
        () async {
          await users?.dispose();
        },
        () async {
          await schedules?.dispose();
        },
        () async {
          await db?.close();
        },
        () async {
          operations?.dispose();
        },
      ]) {
        try {
          await close();
        } catch (error) {
          failures.add(error.runtimeType.toString());
        }
      }
      output['closed'] = failures.isEmpty;
      if (failures.isNotEmpty) {
        output['completed'] = false;
        output['cleanupFailureTypes'] = failures;
      }
    }
    final encoded = _encode(output);
    print('A10_NATIVE_PROBE $encoded');
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    try {
      await File(
        '${root.path}/observation-$stamp-$action.json',
      ).writeAsString(encoded, flush: true);
      await File(
        '${documents.path}/a10-probe-result.json',
      ).writeAsString(encoded, flush: true);
    } catch (error) {
      output['completed'] = false;
      output['evidenceWriteFailureType'] = error.runtimeType.toString();
      print('A10_NATIVE_PROBE ${_encode(output)}');
    }
    return output;
  }
}
