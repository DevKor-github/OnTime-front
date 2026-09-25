import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'backup_limits.dart';
import 'backup_value_validation.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/recurring_backup_data.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

/// The single authenticated portable-content codec and materializer. No active
/// database, revision, installation key, GetIt or startup state is required.
class BackupContent {
  static Future<BackupContent> decrypt(
    Uint8List encrypted,
    String password,
    BackupCrypto crypto,
  ) async {
    final plaintext = await crypto.decrypt(
      container: encrypted,
      password: password,
    );
    return BackupContent.fromJson(
      _asMap(jsonDecode(utf8.decode(plaintext)), 'backup'),
    );
  }

  // Shared bounded-record decoding used by the streaming ingestion pipeline.
  // Callers must not collect these records into a whole-backup object.
  static ScheduleEntity decodeSchedule(Map<String, dynamic> json) {
    final value = _scheduleFromJson(json);
    _validateSchedule(value);
    return value;
  }

  /// Scalar/shape admission only for the contextual streaming validator.
  /// This does not grant preview, materialization, or execution authority.
  /// In particular, an unknown zone still requires historical classification
  /// or explicit time review under a fixed validation instant.
  static ScheduleEntity decodeScheduleStructure(Map<String, dynamic> json) {
    final value = _scheduleFromJson(json);
    _validateScheduleStructure(value);
    return value;
  }

  static PreparationEntity decodePreparation(List<dynamic> json) =>
      _preparationFromJson(json);
  static Map<String, Object?> encodeSchedule(ScheduleEntity value) =>
      _scheduleToJson(value);
  static List<Map<String, Object?>> encodePreparation(
    PreparationEntity value,
  ) => _preparationToJson(value);

  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: cutoff,
    cutoffLiteral: cutoffLiteral,
    sourceAppVersion: sourceAppVersion,
    sourcePlatform: sourcePlatform,
    scheduleCount: schedules.length,
    templateCount: templates.length,
    defaultPreparationStepCount: defaultPreparation.preparationStepList.length,
  );

  Future<void> validateReadBack(AppDatabase database) async {
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_check')
        .get();
    final integrity = await database.customSelect('PRAGMA quick_check').get();
    if (foreignKeys.isNotEmpty ||
        integrity.length != 1 ||
        integrity.single.data.values.single != 'ok') {
      throw const FormatException('Staging integrity validation failed');
    }
    final observed = await capture(
      database,
      cutoff: cutoff,
      sourceAppVersion: sourceAppVersion,
      sourcePlatform: sourcePlatform,
    );
    if (!const DeepCollectionEquality().equals(
      _canonicalDurable(this),
      _canonicalDurable(observed),
    )) {
      throw const FormatException('Staging read-back differs from backup');
    }
  }

  Future<void> writeTo(
    AppDatabase database, {
    required bool pendingCleanup,
  }) async {
    final data = this;
    final profile = data.profile.valueOrNull!;
    await database.transaction(() async {
      await database.deleteAllDurableData();
      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: const Value(localProfileId),
              restoreCleanupPending: Value(pendingCleanup),
              rejectLegacyDelivery: Value(pendingCleanup),
              spareTime: profile.spareTime.inMinutes,
              note: profile.note,
              isOnboardingCompleted: Value(profile.isOnboardingCompleted),
              eligibleOutcomeCount: Value(profile.eligibleOutcomeCount),
              onTimeOutcomeCount: Value(profile.onTimeOutcomeCount),
              alarmsEnabled: Value(data.alarmsEnabled),
              alarmOffsetMinutes: Value(data.alarmOffsetMinutes),
              detailedNotificationContent: Value(
                data.detailedNotificationContent,
              ),
              dataRevision: Value(data.dataRevision + 1),
              firstDurableDataAt: Value(
                data.cutoffLiteral == null
                    ? data.cutoff
                    : DateTime.now().toUtc(),
              ),
              lastDurableDataAt: Value(
                data.cutoffLiteral == null
                    ? data.cutoff
                    : DateTime.now().toUtc(),
              ),
            ),
          );
      await database.preparationUserDao.createPreparationUser(
        data.defaultPreparation,
        localProfileId,
      );
      await data.recurring.restore(database);
      for (final schedule in data.schedules) {
        // The app's only freeze writer records the first start in the same TX.
        // Historical backups omit both fields and keep null/false defaults.
        if (schedule.preparationFrozen && schedule.startedAt == null) {
          throw const FormatException(
            'Frozen preparation requires a first start',
          );
        }
        await database.scheduleDao.createSchedule(
          schedule.toScheduleWithPlaceRow(),
        );
        if (pendingCleanup &&
            schedule.doneStatus == ScheduleDoneStatus.notEnded) {
          await (database.update(
            database.schedules,
          )..where((t) => t.id.equals(schedule.id))).write(
            const SchedulesCompanion(requiresStartConfirmation: Value(true)),
          );
        }
        final preparation = data.schedulePreparations[schedule.id];
        if (preparation != null && preparation.preparationStepList.isNotEmpty) {
          await database.preparationScheduleDao.createPreparationSchedule(
            preparation,
            schedule.id,
          );
        }
      }
      for (final template in data.templates) {
        await database.preparationTemplateDao.restore(
          id: template.id,
          name: template.name,
          preparation: template.preparation,
          createdAt: template.createdAt,
          updatedAt: template.updatedAt,
        );
      }
    });
  }

  static Future<BackupContent> capture(
    AppDatabase target, {
    required DateTime cutoff,
    required String sourceAppVersion,
    required String sourcePlatform,
  }) async {
    return target.transaction(() async {
      final user = await (target.select(
        target.users,
      )..where((table) => table.id.equals(localProfileId))).getSingle();
      final scheduleRows = await target.scheduleDao.getScheduleList();
      final schedulePreparations = <String, PreparationEntity>{};
      for (final row in scheduleRows) {
        schedulePreparations[row.schedule.id] = await target
            .preparationScheduleDao
            .getPreparationSchedulesByScheduleId(row.schedule.id);
      }
      return BackupContent(
        cutoff: cutoff,
        sourceAppVersion: sourceAppVersion,
        sourcePlatform: sourcePlatform,
        dataRevision: user.dataRevision,
        profile: user.toUserEntity(),
        alarmsEnabled: user.alarmsEnabled,
        alarmOffsetMinutes: user.alarmOffsetMinutes,
        detailedNotificationContent: user.detailedNotificationContent,
        schedules: scheduleRows.map((row) => row.toScheduleEntity()).toList(),
        defaultPreparation: await target.preparationUserDao
            .getPreparationUsersByUserId(localProfileId),
        schedulePreparations: schedulePreparations,
        templates: await target.preparationTemplateDao.getAll(),
        recurring: await RecurringBackupData.capture(target),
      );
    });
  }

  const BackupContent({
    required this.cutoff,
    this.cutoffLiteral,
    required this.sourceAppVersion,
    required this.sourcePlatform,
    required this.dataRevision,
    required this.profile,
    required this.alarmsEnabled,
    required this.alarmOffsetMinutes,
    required this.detailedNotificationContent,
    required this.schedules,
    required this.defaultPreparation,
    required this.schedulePreparations,
    required this.templates,
    this.recurring = const RecurringBackupData(),
  });

  final DateTime cutoff;

  /// Present only for legacy metadata lacking an instant offset.
  final String? cutoffLiteral;
  final String sourceAppVersion;
  final String sourcePlatform;
  final int dataRevision;
  final UserEntity profile;
  final bool alarmsEnabled;
  final int alarmOffsetMinutes;
  final bool detailedNotificationContent;
  final List<ScheduleEntity> schedules;
  final PreparationEntity defaultPreparation;
  final Map<String, PreparationEntity> schedulePreparations;
  final List<PreparationTemplateEntity> templates;
  final RecurringBackupData recurring;

  Map<String, Object?> toJson() => {
    'formatVersion': 2,
    'recurring': recurring.toJson(),
    'cutoff': cutoffLiteral ?? cutoff.toUtc().toIso8601String(),
    'sourceAppVersion': sourceAppVersion,
    'sourcePlatform': sourcePlatform,
    'dataRevision': dataRevision,
    'profile': {
      'spareTimeMinutes': profile.valueOrNull!.spareTime.inMinutes,
      'note': profile.valueOrNull!.note,
      'isOnboardingCompleted': profile.valueOrNull!.isOnboardingCompleted,
      'eligibleOutcomeCount': profile.valueOrNull!.eligibleOutcomeCount,
      'onTimeOutcomeCount': profile.valueOrNull!.onTimeOutcomeCount,
    },
    'preferences': {
      'alarmsEnabled': alarmsEnabled,
      'alarmOffsetMinutes': alarmOffsetMinutes,
      'detailedNotificationContent': detailedNotificationContent,
    },
    'schedules': schedules.map(_scheduleToJson).toList(),
    'defaultPreparation': _preparationToJson(defaultPreparation),
    'schedulePreparations': {
      for (final entry in schedulePreparations.entries)
        entry.key: _preparationToJson(entry.value),
    },
    'templates': templates
        .map(
          (template) => {
            'id': template.id,
            'name': template.name,
            'createdAt': template.createdAt.toUtc().toIso8601String(),
            'updatedAt': template.updatedAt.toUtc().toIso8601String(),
            'preparation': _preparationToJson(template.preparation),
          },
        )
        .toList(),
  };

  factory BackupContent.fromJson(Map<String, dynamic> json) {
    final version = _asInt(json['formatVersion'], 'formatVersion');
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported backup data version.');
    }
    final profile = _asMap(json['profile'], 'profile');
    final preferences = _asMap(json['preferences'], 'preferences');
    final schedulePreparations = _asMap(
      json['schedulePreparations'],
      'schedulePreparations',
    );
    final templates = _asList(json['templates'], 'templates');
    final result = BackupContent(
      recurring: version == 1
          ? const RecurringBackupData()
          : RecurringBackupData.fromJson(json['recurring']),
      cutoff: BackupValueValidation.date(
        _asString(json['cutoff'], 'cutoff'),
        civilTime: !BackupValueValidation.explicitOffset(
          _asString(json['cutoff'], 'cutoff'),
        ),
      ),
      cutoffLiteral:
          BackupValueValidation.explicitOffset(
            _asString(json['cutoff'], 'cutoff'),
          )
          ? null
          : _asString(json['cutoff'], 'cutoff'),
      sourceAppVersion: _asString(json['sourceAppVersion'], 'sourceAppVersion'),
      sourcePlatform: _asString(json['sourcePlatform'], 'sourcePlatform'),
      dataRevision: BackupLimits.integer(
        json['dataRevision'],
        maximum: BackupLimits.exactInteger - 1,
      ),
      profile: UserEntity(
        id: localProfileId,
        spareTime: Duration(
          minutes: _asNonNegativeInt(
            profile['spareTimeMinutes'],
            'profile.spareTimeMinutes',
          ),
        ),
        note: _asString(profile['note'], 'profile.note'),
        isOnboardingCompleted: _asBool(
          profile['isOnboardingCompleted'],
          'profile.isOnboardingCompleted',
        ),
        eligibleOutcomeCount: _asNonNegativeInt(
          profile['eligibleOutcomeCount'],
          'profile.eligibleOutcomeCount',
        ),
        onTimeOutcomeCount: _asNonNegativeInt(
          profile['onTimeOutcomeCount'],
          'profile.onTimeOutcomeCount',
        ),
      ),
      alarmsEnabled: _asBool(
        preferences['alarmsEnabled'],
        'preferences.alarmsEnabled',
      ),
      alarmOffsetMinutes: _asNonNegativeInt(
        preferences['alarmOffsetMinutes'],
        'preferences.alarmOffsetMinutes',
      ),
      detailedNotificationContent: _asBool(
        preferences['detailedNotificationContent'],
        'preferences.detailedNotificationContent',
      ),
      schedules: _asList(
        json['schedules'],
        'schedules',
      ).map((value) => _scheduleFromJson(_asMap(value, 'schedule'))).toList(),
      defaultPreparation: _preparationFromJson(
        _asList(json['defaultPreparation'], 'defaultPreparation'),
      ),
      schedulePreparations: {
        for (final entry in schedulePreparations.entries)
          entry.key: _preparationFromJson(
            _asList(entry.value, 'schedulePreparations.${entry.key}'),
          ),
      },
      templates: templates.map((value) {
        final map = _asMap(value, 'template');
        return PreparationTemplateEntity(
          id: _asString(map['id'], 'template.id'),
          name: _asString(map['name'], 'template.name'),
          createdAt: _templateInstant(map['createdAt'], 'template.createdAt'),
          updatedAt: _templateInstant(map['updatedAt'], 'template.updatedAt'),
          preparation: _preparationFromJson(
            _asList(map['preparation'], 'template.preparation'),
          ),
        );
      }).toList(),
    );
    _validateBackupData(result);
    return result;
  }
}

void _validateBackupData(BackupContent data) {
  data.recurring.validate(data.schedules);
  final profile = data.profile.valueOrNull!;
  if (profile.onTimeOutcomeCount > profile.eligibleOutcomeCount) {
    throw const FormatException(
      'On-time outcome count cannot exceed eligible outcome count.',
    );
  }
  if (data.alarmOffsetMinutes > 24 * 60) {
    throw const FormatException('Alarm offset is outside the supported range.');
  }
  final scheduleIds = <String>{};
  for (final schedule in data.schedules) {
    if (schedule.id.isEmpty || !scheduleIds.add(schedule.id)) {
      throw const FormatException('Schedule identifiers must be unique.');
    }
    _validateSchedule(schedule);
  }
  if (!data.schedulePreparations.keys.every(scheduleIds.contains)) {
    throw const FormatException(
      'Schedule preparation references an unknown schedule.',
    );
  }
  final templateIds = <String>{};
  for (final template in data.templates) {
    if (template.id.isEmpty || !templateIds.add(template.id)) {
      throw const FormatException('Template identifiers must be unique.');
    }
  }
  _validatePreparation(data.defaultPreparation);
  for (final preparation in data.schedulePreparations.values) {
    _validatePreparation(preparation);
  }
  for (final template in data.templates) {
    _validatePreparation(template.preparation);
  }
}

void _validateSchedule(ScheduleEntity schedule) {
  _validateScheduleStructure(schedule);
  BackupValueValidation.namedZone(schedule.timeZoneId);
}

void _validateScheduleStructure(ScheduleEntity schedule) {
  BackupLimits.string(schedule.id, identifier: true);
  if (schedule.id.isEmpty ||
      schedule.place.id.isEmpty ||
      schedule.place.placeName.isEmpty ||
      schedule.place.placeName.length > 30) {
    BackupLimits.invalid();
  }
  BackupLimits.string(schedule.place.id, identifier: true);
  BackupValueValidation.zoneIdentifier(schedule.timeZoneId);
  if (schedule.moveTime.isNegative ||
      (schedule.scheduleSpareTime?.isNegative ?? false)) {
    BackupLimits.invalid();
  }
  final offset = schedule.occurrenceOffsetSeconds;
  if (offset != null && (offset < -24 * 60 * 60 || offset > 24 * 60 * 60)) {
    BackupLimits.invalid();
  }
  if (schedule.preparationFrozen && schedule.startedAt == null) {
    BackupLimits.invalid();
  }
}

void _validatePreparation(PreparationEntity preparation) {
  if (preparation.preparationStepList.length > BackupLimits.preparationSteps) {
    BackupLimits.exceeded('preparationSteps');
  }
  final ids = <String>{};
  for (final step in preparation.preparationStepList) {
    if (step.preparationName.isEmpty || step.preparationName.length > 30) {
      BackupLimits.invalid();
    }
    if (step.id.isEmpty || !ids.add(step.id)) {
      throw const FormatException(
        'Preparation step identifiers must be unique.',
      );
    }
  }
  final incoming = <String, int>{};
  for (final step in preparation.preparationStepList) {
    final nextId = step.nextPreparationId;
    if (nextId != null) incoming[nextId] = (incoming[nextId] ?? 0) + 1;
    if (nextId != null && !ids.contains(nextId)) {
      throw const FormatException(
        'Preparation step references an unknown next step.',
      );
    }
  }
  if (ids.isEmpty) return;
  final heads = ids.where((id) => !incoming.containsKey(id)).toList();
  if (heads.length != 1 || incoming.values.any((count) => count != 1)) {
    BackupLimits.invalid();
  }
  final byId = {
    for (final step in preparation.preparationStepList) step.id: step,
  };
  final visited = <String>{};
  String? current = heads.single;
  while (current != null) {
    if (!visited.add(current)) BackupLimits.invalid();
    current = byId[current]!.nextPreparationId;
  }
  if (visited.length != ids.length) BackupLimits.invalid();
}

Map<String, Object?> _scheduleToJson(ScheduleEntity value) => {
  'id': value.id,
  'place': {'id': value.place.id, 'name': value.place.placeName},
  'name': value.scheduleName,
  'civilTime': CivilDateTime.fromFields(
    value.scheduleTime,
  ).toCivilIso8601String(),
  'timeZoneId': value.timeZoneId,
  'occurrenceOffsetSeconds': value.occurrenceOffsetSeconds,
  'moveTimeMinutes': value.moveTime.inMinutes,
  'isChanged': value.isChanged,
  'spareTimeMinutes': value.scheduleSpareTime?.inMinutes,
  'note': value.scheduleNote,
  'latenessTime': value.latenessTime,
  'doneStatus': value.doneStatus.name,
  'finishedAt': value.finishedAt?.toUtc().toIso8601String(),
  'startedAt': value.startedAt?.toUtc().toIso8601String(),
  'preparationFrozen': value.preparationFrozen,
  'preparationMode': value.preparationMode?.name,
  'preparationTemplateId': value.preparationTemplateId,
  'preparationTemplateName': value.preparationTemplateName,
  'preparationTemplateDeleted': value.preparationTemplateDeleted,
  'scoreContributionRecorded': value.scoreContributionRecorded,
  'recurringSegmentId': value.recurringSegmentId,
  'recurringSlotKey': value.recurringSlotKey,
  'recurringOrdinal': value.recurringOrdinal,
  'recurringOverrides': value.recurringOverrides,
  'preparationDefinitionId': value.preparationDefinitionId,
};

ScheduleEntity _scheduleFromJson(Map<String, dynamic> json) {
  final place = _asMap(json['place'], 'schedule.place');
  final eligibleCount = _nullableInt(
    json['occurrenceOffsetSeconds'],
    'schedule.occurrenceOffsetSeconds',
  );
  return ScheduleEntity(
    recurringSegmentId: _nullableString(
      json['recurringSegmentId'],
      'schedule.recurringSegmentId',
    ),
    recurringSlotKey: _nullableString(
      json['recurringSlotKey'],
      'schedule.recurringSlotKey',
    ),
    recurringOrdinal: _nullableInt(
      json['recurringOrdinal'],
      'schedule.recurringOrdinal',
    ),
    recurringOverrides:
        _nullableString(
          json['recurringOverrides'],
          'schedule.recurringOverrides',
        ) ??
        '',
    preparationDefinitionId: _nullableString(
      json['preparationDefinitionId'],
      'schedule.preparationDefinitionId',
    ),
    id: _asString(json['id'], 'schedule.id'),
    place: PlaceEntity(
      id: _asString(place['id'], 'schedule.place.id'),
      placeName: _asString(place['name'], 'schedule.place.name'),
    ),
    scheduleName: _asString(json['name'], 'schedule.name'),
    scheduleTime: _asDate(json['civilTime'], 'schedule.civilTime'),
    timeZoneId: _asString(json['timeZoneId'], 'schedule.timeZoneId'),
    occurrenceOffsetSeconds: eligibleCount,
    moveTime: Duration(
      minutes: _asNonNegativeInt(
        json['moveTimeMinutes'],
        'schedule.moveTimeMinutes',
      ),
    ),
    isChanged: _asBool(json['isChanged'], 'schedule.isChanged'),
    isStarted: false,
    scheduleSpareTime: json['spareTimeMinutes'] == null
        ? null
        : Duration(minutes: BackupLimits.minutes(json['spareTimeMinutes'])),
    scheduleNote: _asString(json['note'], 'schedule.note'),
    latenessTime: _asInt(json['latenessTime'], 'schedule.latenessTime'),
    doneStatus: ScheduleDoneStatus.values.byName(
      _asString(json['doneStatus'], 'schedule.doneStatus'),
    ),
    startedAt: _nullableDate(json['startedAt'], 'schedule.startedAt'),
    finishedAt: _nullableDate(json['finishedAt'], 'schedule.finishedAt'),
    preparationMode: json['preparationMode'] == null
        ? null
        : SchedulePreparationMode.values.byName(
            _asString(json['preparationMode'], 'schedule.preparationMode'),
          ),
    preparationTemplateId: _nullableString(
      json['preparationTemplateId'],
      'schedule.preparationTemplateId',
    ),
    preparationTemplateName: _nullableString(
      json['preparationTemplateName'],
      'schedule.preparationTemplateName',
    ),
    preparationTemplateDeleted: _asBool(
      json['preparationTemplateDeleted'],
      'schedule.preparationTemplateDeleted',
    ),
    preparationFrozen: json['preparationFrozen'] == null
        ? false
        : _asBool(json['preparationFrozen'], 'schedule.preparationFrozen'),
    scoreContributionRecorded: _asBool(
      json['scoreContributionRecorded'],
      'schedule.scoreContributionRecorded',
    ),
  );
}

List<Map<String, Object?>> _preparationToJson(PreparationEntity value) => [
  for (final step in value.ordered.preparationStepList)
    {
      'id': step.id,
      'name': step.preparationName,
      'minutes': step.preparationTime.inMinutes,
      'nextId': step.nextPreparationId,
    },
];

PreparationEntity _preparationFromJson(List<dynamic> values) {
  if (values.length > BackupLimits.preparationSteps) {
    BackupLimits.exceeded('preparationSteps');
  }
  final preparation = PreparationEntity(
    preparationStepList: values.map((value) {
      final map = _asMap(value, 'preparationStep');
      return PreparationStepEntity(
        id: _asString(map['id'], 'preparationStep.id'),
        preparationName: _asString(map['name'], 'preparationStep.name'),
        preparationTime: Duration(
          minutes: _asNonNegativeInt(map['minutes'], 'preparationStep.minutes'),
        ),
        nextPreparationId: _nullableString(
          map['nextId'],
          'preparationStep.nextId',
        ),
      );
    }).toList(),
  );
  _validatePreparation(preparation);
  return preparation.ordered;
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$field must be an object.');
}

List<dynamic> _asList(Object? value, String field) {
  if (value is List<dynamic>) return value;
  throw FormatException('$field must be a list.');
}

String _asString(Object? value, String field) {
  if (value is String) {
    BackupLimits.string(
      value,
      identifier: field.endsWith('.id') || field.endsWith('Id'),
      note: field.endsWith('.note'),
    );
    return value;
  }
  throw FormatException('$field must be a string.');
}

String? _nullableString(Object? value, String field) =>
    value == null ? null : _asString(value, field);

int _asInt(Object? value, String field) {
  if (value is int) {
    return BackupLimits.integer(value, minimum: -BackupLimits.exactInteger);
  }
  throw FormatException('$field must be an integer.');
}

int _asNonNegativeInt(Object? value, String field) {
  final result = _asInt(value, field);
  if (result < 0) throw FormatException('$field must not be negative.');
  if (field.endsWith('Minutes') || field.endsWith('.minutes')) {
    BackupLimits.minutes(result);
  }
  return result;
}

int? _nullableInt(Object? value, String field) =>
    value == null ? null : _asInt(value, field);

bool _asBool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('$field must be a boolean.');
}

DateTime _asDate(Object? value, String field) {
  return BackupValueValidation.date(
    _asString(value, field),
    civilTime: field == 'schedule.civilTime',
  );
}

DateTime? _nullableDate(Object? value, String field) => value == null
    ? null
    : (field == 'schedule.startedAt' || field == 'schedule.finishedAt')
    ? BackupValueValidation.instant(_asString(value, field))
    : _asDate(value, field);

Object _canonicalDurable(BackupContent data) {
  final value = data.toJson()
    ..remove('cutoff')
    ..remove('sourceAppVersion')
    ..remove('sourcePlatform')
    ..remove('dataRevision');
  Object? canonical(Object? value, [String? field]) {
    if (value is Map) {
      return {
        for (final key in value.keys) key: canonical(value[key], key as String),
      };
    }
    if (value is List) {
      final items = value.map((e) => canonical(e)).toList();
      if (items.every((e) => e is Map && e.containsKey('id'))) {
        items.sort(
          (a, b) => (a as Map)['id'].toString().compareTo(
            (b as Map)['id'].toString(),
          ),
        );
      }
      return items;
    }
    if (value is String &&
        const {
          'civilTime',
          'startedAt',
          'finishedAt',
          'createdAt',
          'updatedAt',
        }.contains(field)) {
      return DateTime.parse(value).toUtc().toIso8601String();
    }
    return value;
  }

  return canonical(value)!;
}

DateTime _templateInstant(Object? value, String field) {
  final parsed = BackupValueValidation.instant(_asString(value, field));
  if (parsed.microsecondsSinceEpoch % Duration.microsecondsPerSecond != 0) {
    throw FormatException('$field has unsupported subsecond precision');
  }
  return parsed;
}
