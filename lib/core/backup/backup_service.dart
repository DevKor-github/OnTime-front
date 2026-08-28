import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

enum BackupFreshness { neverExported, noChanges, unexportedChanges }

class BackupFreshnessStatus {
  const BackupFreshnessStatus({
    required this.freshness,
    this.lastExportedAt,
    this.reminderDue = false,
  });

  final BackupFreshness freshness;
  final DateTime? lastExportedAt;
  final bool reminderDue;
}

class BackupRestorePreview {
  const BackupRestorePreview({
    required this.cutoff,
    required this.sourceAppVersion,
    required this.sourcePlatform,
    required this.scheduleCount,
    required this.templateCount,
    required this.defaultPreparationStepCount,
  });

  final DateTime cutoff;
  final String sourceAppVersion;
  final String sourcePlatform;
  final int scheduleCount;
  final int templateCount;
  final int defaultPreparationStepCount;
}

class BackupRestoreCandidate {
  const BackupRestoreCandidate._(this._data, this.preview);

  final _BackupData _data;
  final BackupRestorePreview preview;
}

@lazySingleton
class BackupService {
  BackupService(
    this._database,
    this._metadataProvider, {
    @ignoreParam BackupCrypto? crypto,
  }) : _crypto = crypto ?? BackupCrypto();

  static const _typeGroup = XTypeGroup(
    label: 'OnTime Backup',
    extensions: ['ontimebackup'],
    mimeTypes: ['application/octet-stream'],
  );

  final AppDatabase _database;
  final AppMetadataProvider _metadataProvider;
  final BackupCrypto _crypto;

  Future<bool> exportToUserSelectedFile(String password) async {
    final snapshot = await _captureSnapshot();
    final encrypted = await _encryptSnapshot(snapshot, password);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_typeGroup],
      suggestedName: 'OnTime-${_fileDate(snapshot.cutoff)}.ontimebackup',
    );
    if (location == null) return false;
    await XFile.fromData(
      encrypted,
      name: 'OnTime-${_fileDate(snapshot.cutoff)}.ontimebackup',
      mimeType: 'application/octet-stream',
    ).saveTo(location.path);
    await _database.userDao.markExported(
      userId: localProfileId,
      revision: snapshot.dataRevision,
      cutoff: snapshot.cutoff,
    );
    return true;
  }

  Future<BackupRestoreCandidate?> selectAndPreviewRestore(
    String password,
  ) async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return null;
    return previewEncryptedBackup(await file.readAsBytes(), password);
  }

  /// Creates the same portable container used by the OS file export flow.
  Future<Uint8List> createEncryptedBackup(String password) async {
    return _encryptSnapshot(await _captureSnapshot(), password);
  }

  /// Fully decrypts, authenticates, parses and validates a backup before apply.
  Future<BackupRestoreCandidate> previewEncryptedBackup(
    Uint8List encrypted,
    String password,
  ) async {
    final decrypted = await _crypto.decrypt(
      container: encrypted,
      password: password,
    );
    final decoded = jsonDecode(utf8.decode(decrypted));
    final data = _BackupData.fromJson(_asMap(decoded, 'backup'));
    return BackupRestoreCandidate._(
      data,
      BackupRestorePreview(
        cutoff: data.cutoff,
        sourceAppVersion: data.sourceAppVersion,
        sourcePlatform: data.sourcePlatform,
        scheduleCount: data.schedules.length,
        templateCount: data.templates.length,
        defaultPreparationStepCount:
            data.defaultPreparation.preparationStepList.length,
      ),
    );
  }

  Future<Uint8List> _encryptSnapshot(
    _BackupData snapshot,
    String password,
  ) {
    return _crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(snapshot.toJson()))),
      password: password,
    );
  }

  Future<void> applyRestore(BackupRestoreCandidate candidate) async {
    final data = candidate._data;
    final profile = data.profile.valueOrNull!;
    await _database.transaction(() async {
      await _database.deleteAllDurableData();
      await _database
          .into(_database.users)
          .insert(
            UsersCompanion.insert(
              id: const Value(localProfileId),
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
              firstDurableDataAt: Value(data.cutoff),
              lastDurableDataAt: Value(data.cutoff),
            ),
          );
      await _database.preparationUserDao.createPreparationUser(
        data.defaultPreparation,
        localProfileId,
      );
      for (final schedule in data.schedules) {
        await _database.scheduleDao.createSchedule(
          schedule.toScheduleWithPlaceRow(),
        );
        final preparation = data.schedulePreparations[schedule.id];
        if (preparation != null && preparation.preparationStepList.isNotEmpty) {
          await _database.preparationScheduleDao.createPreparationSchedule(
            preparation,
            schedule.id,
          );
        }
      }
      for (final template in data.templates) {
        await _database.preparationTemplateDao.put(
          id: template.id,
          name: template.name,
          preparation: template.preparation,
          now: template.updatedAt,
        );
      }
    });
  }

  Future<BackupFreshnessStatus> getFreshness() async {
    final user = await (_database.select(
      _database.users,
    )..where((table) => table.id.equals(localProfileId))).getSingleOrNull();
    if (user?.lastExportedRevision == null) {
      return BackupFreshnessStatus(
        freshness: BackupFreshness.neverExported,
        reminderDue: _isOlderThanReminderBoundary(user?.firstDurableDataAt),
      );
    }
    return BackupFreshnessStatus(
      freshness: user!.lastExportedRevision == user.dataRevision
          ? BackupFreshness.noChanges
          : BackupFreshness.unexportedChanges,
      lastExportedAt: user.lastExportedAt,
      reminderDue:
          user.lastExportedRevision != user.dataRevision &&
          _isOlderThanReminderBoundary(user.lastDurableDataAt),
    );
  }

  bool _isOlderThanReminderBoundary(DateTime? value) =>
      value != null && DateTime.now().difference(value).inDays >= 30;

  Future<_BackupData> _captureSnapshot() async {
    return _database.transaction(() async {
      final cutoff = DateTime.now();
      final metadata = await _metadataProvider.getMetadata();
      final user = await (_database.select(
        _database.users,
      )..where((table) => table.id.equals(localProfileId))).getSingle();
      final scheduleRows = await _database.scheduleDao.getScheduleList();
      final schedulePreparations = <String, PreparationEntity>{};
      for (final row in scheduleRows) {
        schedulePreparations[row.schedule.id] = await _database
            .preparationScheduleDao
            .getPreparationSchedulesByScheduleId(row.schedule.id);
      }
      return _BackupData(
        cutoff: cutoff,
        sourceAppVersion: '${metadata.version}+${metadata.buildNumber}',
        sourcePlatform: _sourcePlatform(),
        dataRevision: user.dataRevision,
        profile: user.toUserEntity(),
        alarmsEnabled: user.alarmsEnabled,
        alarmOffsetMinutes: user.alarmOffsetMinutes,
        detailedNotificationContent: user.detailedNotificationContent,
        schedules: scheduleRows.map((row) => row.toScheduleEntity()).toList(),
        defaultPreparation: await _database.preparationUserDao
            .getPreparationUsersByUserId(localProfileId),
        schedulePreparations: schedulePreparations,
        templates: await _database.preparationTemplateDao.getAll(),
      );
    });
  }

  String _fileDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  String _sourcePlatform() {
    try {
      return DeviceInfoService.platformType.name;
    } catch (_) {
      return 'unknown';
    }
  }
}

class _BackupData {
  const _BackupData({
    required this.cutoff,
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
  });

  final DateTime cutoff;
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

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'cutoff': cutoff.toIso8601String(),
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
            'createdAt': template.createdAt.toIso8601String(),
            'updatedAt': template.updatedAt.toIso8601String(),
            'preparation': _preparationToJson(template.preparation),
          },
        )
        .toList(),
  };

  factory _BackupData.fromJson(Map<String, dynamic> json) {
    if (_asInt(json['formatVersion'], 'formatVersion') != 1) {
      throw const FormatException('Unsupported backup data version.');
    }
    final profile = _asMap(json['profile'], 'profile');
    final preferences = _asMap(json['preferences'], 'preferences');
    final schedulePreparations = _asMap(
      json['schedulePreparations'],
      'schedulePreparations',
    );
    final templates = _asList(json['templates'], 'templates');
    final result = _BackupData(
      cutoff: _asDate(json['cutoff'], 'cutoff'),
      sourceAppVersion: _asString(json['sourceAppVersion'], 'sourceAppVersion'),
      sourcePlatform: _asString(json['sourcePlatform'], 'sourcePlatform'),
      dataRevision: _asNonNegativeInt(json['dataRevision'], 'dataRevision'),
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
          createdAt: _asDate(map['createdAt'], 'template.createdAt'),
          updatedAt: _asDate(map['updatedAt'], 'template.updatedAt'),
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

void _validateBackupData(_BackupData data) {
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
    if (schedule.timeZoneId.isEmpty ||
        (schedule.occurrenceOffsetSeconds?.abs() ?? 0) > 24 * 60 * 60) {
      throw const FormatException('Schedule time-zone data is invalid.');
    }
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

void _validatePreparation(PreparationEntity preparation) {
  final ids = <String>{};
  for (final step in preparation.preparationStepList) {
    if (step.id.isEmpty || !ids.add(step.id)) {
      throw const FormatException(
        'Preparation step identifiers must be unique.',
      );
    }
  }
  for (final step in preparation.preparationStepList) {
    final nextId = step.nextPreparationId;
    if (nextId != null && !ids.contains(nextId)) {
      throw const FormatException(
        'Preparation step references an unknown next step.',
      );
    }
  }
}

Map<String, Object?> _scheduleToJson(ScheduleEntity value) => {
  'id': value.id,
  'place': {'id': value.place.id, 'name': value.place.placeName},
  'name': value.scheduleName,
  'civilTime': value.scheduleTime.toIso8601String(),
  'timeZoneId': value.timeZoneId,
  'occurrenceOffsetSeconds': value.occurrenceOffsetSeconds,
  'moveTimeMinutes': value.moveTime.inMinutes,
  'isChanged': value.isChanged,
  'spareTimeMinutes': value.scheduleSpareTime?.inMinutes,
  'note': value.scheduleNote,
  'latenessTime': value.latenessTime,
  'doneStatus': value.doneStatus.name,
  'finishedAt': value.finishedAt?.toIso8601String(),
  'preparationMode': value.preparationMode?.name,
  'preparationTemplateId': value.preparationTemplateId,
  'preparationTemplateName': value.preparationTemplateName,
  'preparationTemplateDeleted': value.preparationTemplateDeleted,
  'scoreContributionRecorded': value.scoreContributionRecorded,
};

ScheduleEntity _scheduleFromJson(Map<String, dynamic> json) {
  final place = _asMap(json['place'], 'schedule.place');
  final eligibleCount = _nullableInt(
    json['occurrenceOffsetSeconds'],
    'schedule.occurrenceOffsetSeconds',
  );
  return ScheduleEntity(
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
    scheduleSpareTime: _nullableInt(
      json['spareTimeMinutes'],
      'schedule.spareTimeMinutes',
    )?.let((minutes) => Duration(minutes: minutes)),
    scheduleNote: _asString(json['note'], 'schedule.note'),
    latenessTime: _asInt(json['latenessTime'], 'schedule.latenessTime'),
    doneStatus: ScheduleDoneStatus.values.byName(
      _asString(json['doneStatus'], 'schedule.doneStatus'),
    ),
    startedAt: null,
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
    preparationFrozen: false,
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
  return PreparationEntity(
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
  ).ordered;
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
  if (value is String) return value;
  throw FormatException('$field must be a string.');
}

String? _nullableString(Object? value, String field) =>
    value == null ? null : _asString(value, field);

int _asInt(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('$field must be an integer.');
}

int _asNonNegativeInt(Object? value, String field) {
  final result = _asInt(value, field);
  if (result < 0) throw FormatException('$field must not be negative.');
  return result;
}

int? _nullableInt(Object? value, String field) =>
    value == null ? null : _asInt(value, field);

bool _asBool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('$field must be a boolean.');
}

DateTime _asDate(Object? value, String field) {
  final parsed = DateTime.tryParse(_asString(value, field));
  if (parsed == null) throw FormatException('$field must be an ISO-8601 date.');
  return parsed;
}

DateTime? _nullableDate(Object? value, String field) =>
    value == null ? null : _asDate(value, field);

extension _Let<T> on T {
  R let<R>(R Function(T value) action) => action(this);
}
