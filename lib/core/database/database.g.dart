// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PlacesTable extends Places with TableInfo<$PlacesTable, Place> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _placeNameMeta =
      const VerificationMeta('placeName');
  @override
  late final GeneratedColumn<String> placeName = GeneratedColumn<String>(
      'place_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, placeName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(Insertable<Place> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('place_name')) {
      context.handle(_placeNameMeta,
          placeName.isAcceptableOrUnknown(data['place_name']!, _placeNameMeta));
    } else if (isInserting) {
      context.missing(_placeNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Place map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Place(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      placeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}place_name'])!,
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }
}

class Place extends DataClass implements Insertable<Place> {
  final int id;
  final String placeName;
  const Place({required this.id, required this.placeName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['place_name'] = Variable<String>(placeName);
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      id: Value(id),
      placeName: Value(placeName),
    );
  }

  factory Place.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Place(
      id: serializer.fromJson<int>(json['id']),
      placeName: serializer.fromJson<String>(json['placeName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'placeName': serializer.toJson<String>(placeName),
    };
  }

  Place copyWith({int? id, String? placeName}) => Place(
        id: id ?? this.id,
        placeName: placeName ?? this.placeName,
      );
  Place copyWithCompanion(PlacesCompanion data) {
    return Place(
      id: data.id.present ? data.id.value : this.id,
      placeName: data.placeName.present ? data.placeName.value : this.placeName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Place(')
          ..write('id: $id, ')
          ..write('placeName: $placeName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, placeName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Place &&
          other.id == this.id &&
          other.placeName == this.placeName);
}

class PlacesCompanion extends UpdateCompanion<Place> {
  final Value<int> id;
  final Value<String> placeName;
  const PlacesCompanion({
    this.id = const Value.absent(),
    this.placeName = const Value.absent(),
  });
  PlacesCompanion.insert({
    this.id = const Value.absent(),
    required String placeName,
  }) : placeName = Value(placeName);
  static Insertable<Place> custom({
    Expression<int>? id,
    Expression<String>? placeName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeName != null) 'place_name': placeName,
    });
  }

  PlacesCompanion copyWith({Value<int>? id, Value<String>? placeName}) {
    return PlacesCompanion(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (placeName.present) {
      map['place_name'] = Variable<String>(placeName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('id: $id, ')
          ..write('placeName: $placeName')
          ..write(')'))
        .toString();
  }
}

class $SchedulesTable extends Schedules
    with TableInfo<$SchedulesTable, Schedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _placeIdMeta =
      const VerificationMeta('placeId');
  @override
  late final GeneratedColumn<int> placeId = GeneratedColumn<int>(
      'place_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES places (id)'));
  static const VerificationMeta _scheduleNameMeta =
      const VerificationMeta('scheduleName');
  @override
  late final GeneratedColumn<String> scheduleName = GeneratedColumn<String>(
      'schedule_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduleTimeMeta =
      const VerificationMeta('scheduleTime');
  @override
  late final GeneratedColumn<DateTime> scheduleTime = GeneratedColumn<DateTime>(
      'schedule_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _moveTimeMeta =
      const VerificationMeta('moveTime');
  @override
  late final GeneratedColumn<DateTime> moveTime = GeneratedColumn<DateTime>(
      'move_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isChangedMeta =
      const VerificationMeta('isChanged');
  @override
  late final GeneratedColumn<bool> isChanged = GeneratedColumn<bool>(
      'is_changed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_changed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isStartedMeta =
      const VerificationMeta('isStarted');
  @override
  late final GeneratedColumn<bool> isStarted = GeneratedColumn<bool>(
      'is_started', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_started" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _scheduleSpareTimeMeta =
      const VerificationMeta('scheduleSpareTime');
  @override
  late final GeneratedColumn<DateTime> scheduleSpareTime =
      GeneratedColumn<DateTime>('schedule_spare_time', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _scheduleNoteMeta =
      const VerificationMeta('scheduleNote');
  @override
  late final GeneratedColumn<String> scheduleNote = GeneratedColumn<String>(
      'schedule_note', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        placeId,
        scheduleName,
        scheduleTime,
        moveTime,
        isChanged,
        isStarted,
        scheduleSpareTime,
        scheduleNote
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedules';
  @override
  VerificationContext validateIntegrity(Insertable<Schedule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('place_id')) {
      context.handle(_placeIdMeta,
          placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta));
    } else if (isInserting) {
      context.missing(_placeIdMeta);
    }
    if (data.containsKey('schedule_name')) {
      context.handle(
          _scheduleNameMeta,
          scheduleName.isAcceptableOrUnknown(
              data['schedule_name']!, _scheduleNameMeta));
    } else if (isInserting) {
      context.missing(_scheduleNameMeta);
    }
    if (data.containsKey('schedule_time')) {
      context.handle(
          _scheduleTimeMeta,
          scheduleTime.isAcceptableOrUnknown(
              data['schedule_time']!, _scheduleTimeMeta));
    } else if (isInserting) {
      context.missing(_scheduleTimeMeta);
    }
    if (data.containsKey('move_time')) {
      context.handle(_moveTimeMeta,
          moveTime.isAcceptableOrUnknown(data['move_time']!, _moveTimeMeta));
    } else if (isInserting) {
      context.missing(_moveTimeMeta);
    }
    if (data.containsKey('is_changed')) {
      context.handle(_isChangedMeta,
          isChanged.isAcceptableOrUnknown(data['is_changed']!, _isChangedMeta));
    }
    if (data.containsKey('is_started')) {
      context.handle(_isStartedMeta,
          isStarted.isAcceptableOrUnknown(data['is_started']!, _isStartedMeta));
    }
    if (data.containsKey('schedule_spare_time')) {
      context.handle(
          _scheduleSpareTimeMeta,
          scheduleSpareTime.isAcceptableOrUnknown(
              data['schedule_spare_time']!, _scheduleSpareTimeMeta));
    } else if (isInserting) {
      context.missing(_scheduleSpareTimeMeta);
    }
    if (data.containsKey('schedule_note')) {
      context.handle(
          _scheduleNoteMeta,
          scheduleNote.isAcceptableOrUnknown(
              data['schedule_note']!, _scheduleNoteMeta));
    } else if (isInserting) {
      context.missing(_scheduleNoteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Schedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Schedule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      placeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}place_id'])!,
      scheduleName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}schedule_name'])!,
      scheduleTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}schedule_time'])!,
      moveTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}move_time'])!,
      isChanged: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_changed'])!,
      isStarted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_started'])!,
      scheduleSpareTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}schedule_spare_time'])!,
      scheduleNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}schedule_note'])!,
    );
  }

  @override
  $SchedulesTable createAlias(String alias) {
    return $SchedulesTable(attachedDatabase, alias);
  }
}

class Schedule extends DataClass implements Insertable<Schedule> {
  final int id;
  final int placeId;
  final String scheduleName;
  final DateTime scheduleTime;
  final DateTime moveTime;
  final bool isChanged;
  final bool isStarted;
  final DateTime scheduleSpareTime;
  final String scheduleNote;
  const Schedule(
      {required this.id,
      required this.placeId,
      required this.scheduleName,
      required this.scheduleTime,
      required this.moveTime,
      required this.isChanged,
      required this.isStarted,
      required this.scheduleSpareTime,
      required this.scheduleNote});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['place_id'] = Variable<int>(placeId);
    map['schedule_name'] = Variable<String>(scheduleName);
    map['schedule_time'] = Variable<DateTime>(scheduleTime);
    map['move_time'] = Variable<DateTime>(moveTime);
    map['is_changed'] = Variable<bool>(isChanged);
    map['is_started'] = Variable<bool>(isStarted);
    map['schedule_spare_time'] = Variable<DateTime>(scheduleSpareTime);
    map['schedule_note'] = Variable<String>(scheduleNote);
    return map;
  }

  SchedulesCompanion toCompanion(bool nullToAbsent) {
    return SchedulesCompanion(
      id: Value(id),
      placeId: Value(placeId),
      scheduleName: Value(scheduleName),
      scheduleTime: Value(scheduleTime),
      moveTime: Value(moveTime),
      isChanged: Value(isChanged),
      isStarted: Value(isStarted),
      scheduleSpareTime: Value(scheduleSpareTime),
      scheduleNote: Value(scheduleNote),
    );
  }

  factory Schedule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Schedule(
      id: serializer.fromJson<int>(json['id']),
      placeId: serializer.fromJson<int>(json['placeId']),
      scheduleName: serializer.fromJson<String>(json['scheduleName']),
      scheduleTime: serializer.fromJson<DateTime>(json['scheduleTime']),
      moveTime: serializer.fromJson<DateTime>(json['moveTime']),
      isChanged: serializer.fromJson<bool>(json['isChanged']),
      isStarted: serializer.fromJson<bool>(json['isStarted']),
      scheduleSpareTime:
          serializer.fromJson<DateTime>(json['scheduleSpareTime']),
      scheduleNote: serializer.fromJson<String>(json['scheduleNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'placeId': serializer.toJson<int>(placeId),
      'scheduleName': serializer.toJson<String>(scheduleName),
      'scheduleTime': serializer.toJson<DateTime>(scheduleTime),
      'moveTime': serializer.toJson<DateTime>(moveTime),
      'isChanged': serializer.toJson<bool>(isChanged),
      'isStarted': serializer.toJson<bool>(isStarted),
      'scheduleSpareTime': serializer.toJson<DateTime>(scheduleSpareTime),
      'scheduleNote': serializer.toJson<String>(scheduleNote),
    };
  }

  Schedule copyWith(
          {int? id,
          int? placeId,
          String? scheduleName,
          DateTime? scheduleTime,
          DateTime? moveTime,
          bool? isChanged,
          bool? isStarted,
          DateTime? scheduleSpareTime,
          String? scheduleNote}) =>
      Schedule(
        id: id ?? this.id,
        placeId: placeId ?? this.placeId,
        scheduleName: scheduleName ?? this.scheduleName,
        scheduleTime: scheduleTime ?? this.scheduleTime,
        moveTime: moveTime ?? this.moveTime,
        isChanged: isChanged ?? this.isChanged,
        isStarted: isStarted ?? this.isStarted,
        scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
        scheduleNote: scheduleNote ?? this.scheduleNote,
      );
  Schedule copyWithCompanion(SchedulesCompanion data) {
    return Schedule(
      id: data.id.present ? data.id.value : this.id,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      scheduleName: data.scheduleName.present
          ? data.scheduleName.value
          : this.scheduleName,
      scheduleTime: data.scheduleTime.present
          ? data.scheduleTime.value
          : this.scheduleTime,
      moveTime: data.moveTime.present ? data.moveTime.value : this.moveTime,
      isChanged: data.isChanged.present ? data.isChanged.value : this.isChanged,
      isStarted: data.isStarted.present ? data.isStarted.value : this.isStarted,
      scheduleSpareTime: data.scheduleSpareTime.present
          ? data.scheduleSpareTime.value
          : this.scheduleSpareTime,
      scheduleNote: data.scheduleNote.present
          ? data.scheduleNote.value
          : this.scheduleNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Schedule(')
          ..write('id: $id, ')
          ..write('placeId: $placeId, ')
          ..write('scheduleName: $scheduleName, ')
          ..write('scheduleTime: $scheduleTime, ')
          ..write('moveTime: $moveTime, ')
          ..write('isChanged: $isChanged, ')
          ..write('isStarted: $isStarted, ')
          ..write('scheduleSpareTime: $scheduleSpareTime, ')
          ..write('scheduleNote: $scheduleNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, placeId, scheduleName, scheduleTime,
      moveTime, isChanged, isStarted, scheduleSpareTime, scheduleNote);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Schedule &&
          other.id == this.id &&
          other.placeId == this.placeId &&
          other.scheduleName == this.scheduleName &&
          other.scheduleTime == this.scheduleTime &&
          other.moveTime == this.moveTime &&
          other.isChanged == this.isChanged &&
          other.isStarted == this.isStarted &&
          other.scheduleSpareTime == this.scheduleSpareTime &&
          other.scheduleNote == this.scheduleNote);
}

class SchedulesCompanion extends UpdateCompanion<Schedule> {
  final Value<int> id;
  final Value<int> placeId;
  final Value<String> scheduleName;
  final Value<DateTime> scheduleTime;
  final Value<DateTime> moveTime;
  final Value<bool> isChanged;
  final Value<bool> isStarted;
  final Value<DateTime> scheduleSpareTime;
  final Value<String> scheduleNote;
  const SchedulesCompanion({
    this.id = const Value.absent(),
    this.placeId = const Value.absent(),
    this.scheduleName = const Value.absent(),
    this.scheduleTime = const Value.absent(),
    this.moveTime = const Value.absent(),
    this.isChanged = const Value.absent(),
    this.isStarted = const Value.absent(),
    this.scheduleSpareTime = const Value.absent(),
    this.scheduleNote = const Value.absent(),
  });
  SchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int placeId,
    required String scheduleName,
    required DateTime scheduleTime,
    required DateTime moveTime,
    this.isChanged = const Value.absent(),
    this.isStarted = const Value.absent(),
    required DateTime scheduleSpareTime,
    required String scheduleNote,
  })  : placeId = Value(placeId),
        scheduleName = Value(scheduleName),
        scheduleTime = Value(scheduleTime),
        moveTime = Value(moveTime),
        scheduleSpareTime = Value(scheduleSpareTime),
        scheduleNote = Value(scheduleNote);
  static Insertable<Schedule> custom({
    Expression<int>? id,
    Expression<int>? placeId,
    Expression<String>? scheduleName,
    Expression<DateTime>? scheduleTime,
    Expression<DateTime>? moveTime,
    Expression<bool>? isChanged,
    Expression<bool>? isStarted,
    Expression<DateTime>? scheduleSpareTime,
    Expression<String>? scheduleNote,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeId != null) 'place_id': placeId,
      if (scheduleName != null) 'schedule_name': scheduleName,
      if (scheduleTime != null) 'schedule_time': scheduleTime,
      if (moveTime != null) 'move_time': moveTime,
      if (isChanged != null) 'is_changed': isChanged,
      if (isStarted != null) 'is_started': isStarted,
      if (scheduleSpareTime != null) 'schedule_spare_time': scheduleSpareTime,
      if (scheduleNote != null) 'schedule_note': scheduleNote,
    });
  }

  SchedulesCompanion copyWith(
      {Value<int>? id,
      Value<int>? placeId,
      Value<String>? scheduleName,
      Value<DateTime>? scheduleTime,
      Value<DateTime>? moveTime,
      Value<bool>? isChanged,
      Value<bool>? isStarted,
      Value<DateTime>? scheduleSpareTime,
      Value<String>? scheduleNote}) {
    return SchedulesCompanion(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      scheduleName: scheduleName ?? this.scheduleName,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      moveTime: moveTime ?? this.moveTime,
      isChanged: isChanged ?? this.isChanged,
      isStarted: isStarted ?? this.isStarted,
      scheduleSpareTime: scheduleSpareTime ?? this.scheduleSpareTime,
      scheduleNote: scheduleNote ?? this.scheduleNote,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<int>(placeId.value);
    }
    if (scheduleName.present) {
      map['schedule_name'] = Variable<String>(scheduleName.value);
    }
    if (scheduleTime.present) {
      map['schedule_time'] = Variable<DateTime>(scheduleTime.value);
    }
    if (moveTime.present) {
      map['move_time'] = Variable<DateTime>(moveTime.value);
    }
    if (isChanged.present) {
      map['is_changed'] = Variable<bool>(isChanged.value);
    }
    if (isStarted.present) {
      map['is_started'] = Variable<bool>(isStarted.value);
    }
    if (scheduleSpareTime.present) {
      map['schedule_spare_time'] = Variable<DateTime>(scheduleSpareTime.value);
    }
    if (scheduleNote.present) {
      map['schedule_note'] = Variable<String>(scheduleNote.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedulesCompanion(')
          ..write('id: $id, ')
          ..write('placeId: $placeId, ')
          ..write('scheduleName: $scheduleName, ')
          ..write('scheduleTime: $scheduleTime, ')
          ..write('moveTime: $moveTime, ')
          ..write('isChanged: $isChanged, ')
          ..write('isStarted: $isStarted, ')
          ..write('scheduleSpareTime: $scheduleSpareTime, ')
          ..write('scheduleNote: $scheduleNote')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $SchedulesTable schedules = $SchedulesTable(this);
  late final ScheduleDao scheduleDao = ScheduleDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [places, schedules];
}

typedef $$PlacesTableCreateCompanionBuilder = PlacesCompanion Function({
  Value<int> id,
  required String placeName,
});
typedef $$PlacesTableUpdateCompanionBuilder = PlacesCompanion Function({
  Value<int> id,
  Value<String> placeName,
});

final class $$PlacesTableReferences
    extends BaseReferences<_$AppDatabase, $PlacesTable, Place> {
  $$PlacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SchedulesTable, List<Schedule>>
      _schedulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.schedules,
          aliasName: $_aliasNameGenerator(db.places.id, db.schedules.placeId));

  $$SchedulesTableProcessedTableManager get schedulesRefs {
    final manager = $$SchedulesTableTableManager($_db, $_db.schedules)
        .filter((f) => f.placeId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_schedulesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlacesTableFilterComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get placeName => $composableBuilder(
      column: $table.placeName, builder: (column) => ColumnFilters(column));

  Expression<bool> schedulesRefs(
      Expression<bool> Function($$SchedulesTableFilterComposer f) f) {
    final $$SchedulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SchedulesTableFilterComposer(
              $db: $db,
              $table: $db.schedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlacesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get placeName => $composableBuilder(
      column: $table.placeName, builder: (column) => ColumnOrderings(column));
}

class $$PlacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get placeName =>
      $composableBuilder(column: $table.placeName, builder: (column) => column);

  Expression<T> schedulesRefs<T extends Object>(
      Expression<T> Function($$SchedulesTableAnnotationComposer a) f) {
    final $$SchedulesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SchedulesTableAnnotationComposer(
              $db: $db,
              $table: $db.schedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlacesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlacesTable,
    Place,
    $$PlacesTableFilterComposer,
    $$PlacesTableOrderingComposer,
    $$PlacesTableAnnotationComposer,
    $$PlacesTableCreateCompanionBuilder,
    $$PlacesTableUpdateCompanionBuilder,
    (Place, $$PlacesTableReferences),
    Place,
    PrefetchHooks Function({bool schedulesRefs})> {
  $$PlacesTableTableManager(_$AppDatabase db, $PlacesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> placeName = const Value.absent(),
          }) =>
              PlacesCompanion(
            id: id,
            placeName: placeName,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String placeName,
          }) =>
              PlacesCompanion.insert(
            id: id,
            placeName: placeName,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PlacesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({schedulesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (schedulesRefs) db.schedules],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (schedulesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$PlacesTableReferences._schedulesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlacesTableReferences(db, table, p0)
                                .schedulesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.placeId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlacesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlacesTable,
    Place,
    $$PlacesTableFilterComposer,
    $$PlacesTableOrderingComposer,
    $$PlacesTableAnnotationComposer,
    $$PlacesTableCreateCompanionBuilder,
    $$PlacesTableUpdateCompanionBuilder,
    (Place, $$PlacesTableReferences),
    Place,
    PrefetchHooks Function({bool schedulesRefs})>;
typedef $$SchedulesTableCreateCompanionBuilder = SchedulesCompanion Function({
  Value<int> id,
  required int placeId,
  required String scheduleName,
  required DateTime scheduleTime,
  required DateTime moveTime,
  Value<bool> isChanged,
  Value<bool> isStarted,
  required DateTime scheduleSpareTime,
  required String scheduleNote,
});
typedef $$SchedulesTableUpdateCompanionBuilder = SchedulesCompanion Function({
  Value<int> id,
  Value<int> placeId,
  Value<String> scheduleName,
  Value<DateTime> scheduleTime,
  Value<DateTime> moveTime,
  Value<bool> isChanged,
  Value<bool> isStarted,
  Value<DateTime> scheduleSpareTime,
  Value<String> scheduleNote,
});

final class $$SchedulesTableReferences
    extends BaseReferences<_$AppDatabase, $SchedulesTable, Schedule> {
  $$SchedulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeIdTable(_$AppDatabase db) => db.places
      .createAlias($_aliasNameGenerator(db.schedules.placeId, db.places.id));

  $$PlacesTableProcessedTableManager? get placeId {
    if ($_item.placeId == null) return null;
    final manager = $$PlacesTableTableManager($_db, $_db.places)
        .filter((f) => f.id($_item.placeId!));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduleName => $composableBuilder(
      column: $table.scheduleName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduleTime => $composableBuilder(
      column: $table.scheduleTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get moveTime => $composableBuilder(
      column: $table.moveTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isChanged => $composableBuilder(
      column: $table.isChanged, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStarted => $composableBuilder(
      column: $table.isStarted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduleSpareTime => $composableBuilder(
      column: $table.scheduleSpareTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduleNote => $composableBuilder(
      column: $table.scheduleNote, builder: (column) => ColumnFilters(column));

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableFilterComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduleName => $composableBuilder(
      column: $table.scheduleName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduleTime => $composableBuilder(
      column: $table.scheduleTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get moveTime => $composableBuilder(
      column: $table.moveTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isChanged => $composableBuilder(
      column: $table.isChanged, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStarted => $composableBuilder(
      column: $table.isStarted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduleSpareTime => $composableBuilder(
      column: $table.scheduleSpareTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduleNote => $composableBuilder(
      column: $table.scheduleNote,
      builder: (column) => ColumnOrderings(column));

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableOrderingComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scheduleName => $composableBuilder(
      column: $table.scheduleName, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduleTime => $composableBuilder(
      column: $table.scheduleTime, builder: (column) => column);

  GeneratedColumn<DateTime> get moveTime =>
      $composableBuilder(column: $table.moveTime, builder: (column) => column);

  GeneratedColumn<bool> get isChanged =>
      $composableBuilder(column: $table.isChanged, builder: (column) => column);

  GeneratedColumn<bool> get isStarted =>
      $composableBuilder(column: $table.isStarted, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduleSpareTime => $composableBuilder(
      column: $table.scheduleSpareTime, builder: (column) => column);

  GeneratedColumn<String> get scheduleNote => $composableBuilder(
      column: $table.scheduleNote, builder: (column) => column);

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableAnnotationComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SchedulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SchedulesTable,
    Schedule,
    $$SchedulesTableFilterComposer,
    $$SchedulesTableOrderingComposer,
    $$SchedulesTableAnnotationComposer,
    $$SchedulesTableCreateCompanionBuilder,
    $$SchedulesTableUpdateCompanionBuilder,
    (Schedule, $$SchedulesTableReferences),
    Schedule,
    PrefetchHooks Function({bool placeId})> {
  $$SchedulesTableTableManager(_$AppDatabase db, $SchedulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> placeId = const Value.absent(),
            Value<String> scheduleName = const Value.absent(),
            Value<DateTime> scheduleTime = const Value.absent(),
            Value<DateTime> moveTime = const Value.absent(),
            Value<bool> isChanged = const Value.absent(),
            Value<bool> isStarted = const Value.absent(),
            Value<DateTime> scheduleSpareTime = const Value.absent(),
            Value<String> scheduleNote = const Value.absent(),
          }) =>
              SchedulesCompanion(
            id: id,
            placeId: placeId,
            scheduleName: scheduleName,
            scheduleTime: scheduleTime,
            moveTime: moveTime,
            isChanged: isChanged,
            isStarted: isStarted,
            scheduleSpareTime: scheduleSpareTime,
            scheduleNote: scheduleNote,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int placeId,
            required String scheduleName,
            required DateTime scheduleTime,
            required DateTime moveTime,
            Value<bool> isChanged = const Value.absent(),
            Value<bool> isStarted = const Value.absent(),
            required DateTime scheduleSpareTime,
            required String scheduleNote,
          }) =>
              SchedulesCompanion.insert(
            id: id,
            placeId: placeId,
            scheduleName: scheduleName,
            scheduleTime: scheduleTime,
            moveTime: moveTime,
            isChanged: isChanged,
            isStarted: isStarted,
            scheduleSpareTime: scheduleSpareTime,
            scheduleNote: scheduleNote,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SchedulesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({placeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (placeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.placeId,
                    referencedTable:
                        $$SchedulesTableReferences._placeIdTable(db),
                    referencedColumn:
                        $$SchedulesTableReferences._placeIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SchedulesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SchedulesTable,
    Schedule,
    $$SchedulesTableFilterComposer,
    $$SchedulesTableOrderingComposer,
    $$SchedulesTableAnnotationComposer,
    $$SchedulesTableCreateCompanionBuilder,
    $$SchedulesTableUpdateCompanionBuilder,
    (Schedule, $$SchedulesTableReferences),
    Schedule,
    PrefetchHooks Function({bool placeId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$SchedulesTableTableManager get schedules =>
      $$SchedulesTableTableManager(_db, _db.schedules);
}
