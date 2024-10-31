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

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 320),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _passwordMeta =
      const VerificationMeta('password');
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
      'password', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 30),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 30),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _spareTimeMeta =
      const VerificationMeta('spareTime');
  @override
  late final GeneratedColumn<int> spareTime = GeneratedColumn<int>(
      'spare_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, email, password, name, spareTime, note, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('password')) {
      context.handle(_passwordMeta,
          password.isAcceptableOrUnknown(data['password']!, _passwordMeta));
    } else if (isInserting) {
      context.missing(_passwordMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('spare_time')) {
      context.handle(_spareTimeMeta,
          spareTime.isAcceptableOrUnknown(data['spare_time']!, _spareTimeMeta));
    } else if (isInserting) {
      context.missing(_spareTimeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      password: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      spareTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}spare_time'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String email;
  final String password;
  final String name;
  final int spareTime;
  final String note;
  final double score;
  const User(
      {required this.id,
      required this.email,
      required this.password,
      required this.name,
      required this.spareTime,
      required this.note,
      required this.score});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['email'] = Variable<String>(email);
    map['password'] = Variable<String>(password);
    map['name'] = Variable<String>(name);
    map['spare_time'] = Variable<int>(spareTime);
    map['note'] = Variable<String>(note);
    map['score'] = Variable<double>(score);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email: Value(email),
      password: Value(password),
      name: Value(name),
      spareTime: Value(spareTime),
      note: Value(note),
      score: Value(score),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      password: serializer.fromJson<String>(json['password']),
      name: serializer.fromJson<String>(json['name']),
      spareTime: serializer.fromJson<int>(json['spareTime']),
      note: serializer.fromJson<String>(json['note']),
      score: serializer.fromJson<double>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'email': serializer.toJson<String>(email),
      'password': serializer.toJson<String>(password),
      'name': serializer.toJson<String>(name),
      'spareTime': serializer.toJson<int>(spareTime),
      'note': serializer.toJson<String>(note),
      'score': serializer.toJson<double>(score),
    };
  }

  User copyWith(
          {int? id,
          String? email,
          String? password,
          String? name,
          int? spareTime,
          String? note,
          double? score}) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        password: password ?? this.password,
        name: name ?? this.name,
        spareTime: spareTime ?? this.spareTime,
        note: note ?? this.note,
        score: score ?? this.score,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      password: data.password.present ? data.password.value : this.password,
      name: data.name.present ? data.name.value : this.name,
      spareTime: data.spareTime.present ? data.spareTime.value : this.spareTime,
      note: data.note.present ? data.note.value : this.note,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('password: $password, ')
          ..write('name: $name, ')
          ..write('spareTime: $spareTime, ')
          ..write('note: $note, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, email, password, name, spareTime, note, score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.email == this.email &&
          other.password == this.password &&
          other.name == this.name &&
          other.spareTime == this.spareTime &&
          other.note == this.note &&
          other.score == this.score);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> email;
  final Value<String> password;
  final Value<String> name;
  final Value<int> spareTime;
  final Value<String> note;
  final Value<double> score;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.password = const Value.absent(),
    this.name = const Value.absent(),
    this.spareTime = const Value.absent(),
    this.note = const Value.absent(),
    this.score = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String email,
    required String password,
    required String name,
    required int spareTime,
    required String note,
    required double score,
  })  : email = Value(email),
        password = Value(password),
        name = Value(name),
        spareTime = Value(spareTime),
        note = Value(note),
        score = Value(score);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? email,
    Expression<String>? password,
    Expression<String>? name,
    Expression<int>? spareTime,
    Expression<String>? note,
    Expression<double>? score,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (name != null) 'name': name,
      if (spareTime != null) 'spare_time': spareTime,
      if (note != null) 'note': note,
      if (score != null) 'score': score,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String>? email,
      Value<String>? password,
      Value<String>? name,
      Value<int>? spareTime,
      Value<String>? note,
      Value<double>? score}) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      spareTime: spareTime ?? this.spareTime,
      note: note ?? this.note,
      score: score ?? this.score,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (spareTime.present) {
      map['spare_time'] = Variable<int>(spareTime.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('password: $password, ')
          ..write('name: $name, ')
          ..write('spareTime: $spareTime, ')
          ..write('note: $note, ')
          ..write('score: $score')
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
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
        userId,
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
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
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
  final int userId;
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
      required this.userId,
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
    map['user_id'] = Variable<int>(userId);
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
      userId: Value(userId),
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
      userId: serializer.fromJson<int>(json['userId']),
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
      'userId': serializer.toJson<int>(userId),
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
          int? userId,
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
        userId: userId ?? this.userId,
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
      userId: data.userId.present ? data.userId.value : this.userId,
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
          ..write('userId: $userId, ')
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
  int get hashCode => Object.hash(
      id,
      userId,
      placeId,
      scheduleName,
      scheduleTime,
      moveTime,
      isChanged,
      isStarted,
      scheduleSpareTime,
      scheduleNote);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Schedule &&
          other.id == this.id &&
          other.userId == this.userId &&
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
  final Value<int> userId;
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
    this.userId = const Value.absent(),
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
    required int userId,
    required int placeId,
    required String scheduleName,
    required DateTime scheduleTime,
    required DateTime moveTime,
    this.isChanged = const Value.absent(),
    this.isStarted = const Value.absent(),
    required DateTime scheduleSpareTime,
    required String scheduleNote,
  })  : userId = Value(userId),
        placeId = Value(placeId),
        scheduleName = Value(scheduleName),
        scheduleTime = Value(scheduleTime),
        moveTime = Value(moveTime),
        scheduleSpareTime = Value(scheduleSpareTime),
        scheduleNote = Value(scheduleNote);
  static Insertable<Schedule> custom({
    Expression<int>? id,
    Expression<int>? userId,
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
      if (userId != null) 'user_id': userId,
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
      Value<int>? userId,
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
      userId: userId ?? this.userId,
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
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
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
          ..write('userId: $userId, ')
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

class $PreparationSchedulesTable extends PreparationSchedules
    with TableInfo<$PreparationSchedulesTable, PreparationSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreparationSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _scheduleIdMeta =
      const VerificationMeta('scheduleId');
  @override
  late final GeneratedColumn<int> scheduleId = GeneratedColumn<int>(
      'schedule_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES schedules (id)'));
  static const VerificationMeta _preparationNameMeta =
      const VerificationMeta('preparationName');
  @override
  late final GeneratedColumn<String> preparationName = GeneratedColumn<String>(
      'preparation_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 30),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _preparationTimeMeta =
      const VerificationMeta('preparationTime');
  @override
  late final GeneratedColumn<int> preparationTime = GeneratedColumn<int>(
      'preparation_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, scheduleId, preparationName, preparationTime, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preparation_schedules';
  @override
  VerificationContext validateIntegrity(
      Insertable<PreparationSchedule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
          _scheduleIdMeta,
          scheduleId.isAcceptableOrUnknown(
              data['schedule_id']!, _scheduleIdMeta));
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('preparation_name')) {
      context.handle(
          _preparationNameMeta,
          preparationName.isAcceptableOrUnknown(
              data['preparation_name']!, _preparationNameMeta));
    } else if (isInserting) {
      context.missing(_preparationNameMeta);
    }
    if (data.containsKey('preparation_time')) {
      context.handle(
          _preparationTimeMeta,
          preparationTime.isAcceptableOrUnknown(
              data['preparation_time']!, _preparationTimeMeta));
    } else if (isInserting) {
      context.missing(_preparationTimeMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PreparationSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreparationSchedule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      scheduleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schedule_id'])!,
      preparationName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preparation_name'])!,
      preparationTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}preparation_time'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $PreparationSchedulesTable createAlias(String alias) {
    return $PreparationSchedulesTable(attachedDatabase, alias);
  }
}

class PreparationSchedule extends DataClass
    implements Insertable<PreparationSchedule> {
  final int id;
  final int scheduleId;
  final String preparationName;
  final int preparationTime;
  final int order;
  const PreparationSchedule(
      {required this.id,
      required this.scheduleId,
      required this.preparationName,
      required this.preparationTime,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schedule_id'] = Variable<int>(scheduleId);
    map['preparation_name'] = Variable<String>(preparationName);
    map['preparation_time'] = Variable<int>(preparationTime);
    map['order'] = Variable<int>(order);
    return map;
  }

  PreparationSchedulesCompanion toCompanion(bool nullToAbsent) {
    return PreparationSchedulesCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      preparationName: Value(preparationName),
      preparationTime: Value(preparationTime),
      order: Value(order),
    );
  }

  factory PreparationSchedule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreparationSchedule(
      id: serializer.fromJson<int>(json['id']),
      scheduleId: serializer.fromJson<int>(json['scheduleId']),
      preparationName: serializer.fromJson<String>(json['preparationName']),
      preparationTime: serializer.fromJson<int>(json['preparationTime']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduleId': serializer.toJson<int>(scheduleId),
      'preparationName': serializer.toJson<String>(preparationName),
      'preparationTime': serializer.toJson<int>(preparationTime),
      'order': serializer.toJson<int>(order),
    };
  }

  PreparationSchedule copyWith(
          {int? id,
          int? scheduleId,
          String? preparationName,
          int? preparationTime,
          int? order}) =>
      PreparationSchedule(
        id: id ?? this.id,
        scheduleId: scheduleId ?? this.scheduleId,
        preparationName: preparationName ?? this.preparationName,
        preparationTime: preparationTime ?? this.preparationTime,
        order: order ?? this.order,
      );
  PreparationSchedule copyWithCompanion(PreparationSchedulesCompanion data) {
    return PreparationSchedule(
      id: data.id.present ? data.id.value : this.id,
      scheduleId:
          data.scheduleId.present ? data.scheduleId.value : this.scheduleId,
      preparationName: data.preparationName.present
          ? data.preparationName.value
          : this.preparationName,
      preparationTime: data.preparationTime.present
          ? data.preparationTime.value
          : this.preparationTime,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreparationSchedule(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('preparationName: $preparationName, ')
          ..write('preparationTime: $preparationTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scheduleId, preparationName, preparationTime, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreparationSchedule &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.preparationName == this.preparationName &&
          other.preparationTime == this.preparationTime &&
          other.order == this.order);
}

class PreparationSchedulesCompanion
    extends UpdateCompanion<PreparationSchedule> {
  final Value<int> id;
  final Value<int> scheduleId;
  final Value<String> preparationName;
  final Value<int> preparationTime;
  final Value<int> order;
  const PreparationSchedulesCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.preparationName = const Value.absent(),
    this.preparationTime = const Value.absent(),
    this.order = const Value.absent(),
  });
  PreparationSchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int scheduleId,
    required String preparationName,
    required int preparationTime,
    required int order,
  })  : scheduleId = Value(scheduleId),
        preparationName = Value(preparationName),
        preparationTime = Value(preparationTime),
        order = Value(order);
  static Insertable<PreparationSchedule> custom({
    Expression<int>? id,
    Expression<int>? scheduleId,
    Expression<String>? preparationName,
    Expression<int>? preparationTime,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (preparationName != null) 'preparation_name': preparationName,
      if (preparationTime != null) 'preparation_time': preparationTime,
      if (order != null) 'order': order,
    });
  }

  PreparationSchedulesCompanion copyWith(
      {Value<int>? id,
      Value<int>? scheduleId,
      Value<String>? preparationName,
      Value<int>? preparationTime,
      Value<int>? order}) {
    return PreparationSchedulesCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<int>(scheduleId.value);
    }
    if (preparationName.present) {
      map['preparation_name'] = Variable<String>(preparationName.value);
    }
    if (preparationTime.present) {
      map['preparation_time'] = Variable<int>(preparationTime.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreparationSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('preparationName: $preparationName, ')
          ..write('preparationTime: $preparationTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class $PreparationUsersTable extends PreparationUsers
    with TableInfo<$PreparationUsersTable, PreparationUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreparationUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES users (id)'));
  static const VerificationMeta _preparationNameMeta =
      const VerificationMeta('preparationName');
  @override
  late final GeneratedColumn<String> preparationName = GeneratedColumn<String>(
      'preparation_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 30),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _preparationTimeMeta =
      const VerificationMeta('preparationTime');
  @override
  late final GeneratedColumn<int> preparationTime = GeneratedColumn<int>(
      'preparation_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, preparationName, preparationTime, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preparation_users';
  @override
  VerificationContext validateIntegrity(Insertable<PreparationUser> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('preparation_name')) {
      context.handle(
          _preparationNameMeta,
          preparationName.isAcceptableOrUnknown(
              data['preparation_name']!, _preparationNameMeta));
    } else if (isInserting) {
      context.missing(_preparationNameMeta);
    }
    if (data.containsKey('preparation_time')) {
      context.handle(
          _preparationTimeMeta,
          preparationTime.isAcceptableOrUnknown(
              data['preparation_time']!, _preparationTimeMeta));
    } else if (isInserting) {
      context.missing(_preparationTimeMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PreparationUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreparationUser(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
      preparationName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preparation_name'])!,
      preparationTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}preparation_time'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $PreparationUsersTable createAlias(String alias) {
    return $PreparationUsersTable(attachedDatabase, alias);
  }
}

class PreparationUser extends DataClass implements Insertable<PreparationUser> {
  final int id;
  final int userId;
  final String preparationName;
  final int preparationTime;
  final int order;
  const PreparationUser(
      {required this.id,
      required this.userId,
      required this.preparationName,
      required this.preparationTime,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<int>(userId);
    map['preparation_name'] = Variable<String>(preparationName);
    map['preparation_time'] = Variable<int>(preparationTime);
    map['order'] = Variable<int>(order);
    return map;
  }

  PreparationUsersCompanion toCompanion(bool nullToAbsent) {
    return PreparationUsersCompanion(
      id: Value(id),
      userId: Value(userId),
      preparationName: Value(preparationName),
      preparationTime: Value(preparationTime),
      order: Value(order),
    );
  }

  factory PreparationUser.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreparationUser(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<int>(json['userId']),
      preparationName: serializer.fromJson<String>(json['preparationName']),
      preparationTime: serializer.fromJson<int>(json['preparationTime']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<int>(userId),
      'preparationName': serializer.toJson<String>(preparationName),
      'preparationTime': serializer.toJson<int>(preparationTime),
      'order': serializer.toJson<int>(order),
    };
  }

  PreparationUser copyWith(
          {int? id,
          int? userId,
          String? preparationName,
          int? preparationTime,
          int? order}) =>
      PreparationUser(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        preparationName: preparationName ?? this.preparationName,
        preparationTime: preparationTime ?? this.preparationTime,
        order: order ?? this.order,
      );
  PreparationUser copyWithCompanion(PreparationUsersCompanion data) {
    return PreparationUser(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      preparationName: data.preparationName.present
          ? data.preparationName.value
          : this.preparationName,
      preparationTime: data.preparationTime.present
          ? data.preparationTime.value
          : this.preparationTime,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreparationUser(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('preparationName: $preparationName, ')
          ..write('preparationTime: $preparationTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, preparationName, preparationTime, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreparationUser &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.preparationName == this.preparationName &&
          other.preparationTime == this.preparationTime &&
          other.order == this.order);
}

class PreparationUsersCompanion extends UpdateCompanion<PreparationUser> {
  final Value<int> id;
  final Value<int> userId;
  final Value<String> preparationName;
  final Value<int> preparationTime;
  final Value<int> order;
  const PreparationUsersCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.preparationName = const Value.absent(),
    this.preparationTime = const Value.absent(),
    this.order = const Value.absent(),
  });
  PreparationUsersCompanion.insert({
    this.id = const Value.absent(),
    required int userId,
    required String preparationName,
    required int preparationTime,
    required int order,
  })  : userId = Value(userId),
        preparationName = Value(preparationName),
        preparationTime = Value(preparationTime),
        order = Value(order);
  static Insertable<PreparationUser> custom({
    Expression<int>? id,
    Expression<int>? userId,
    Expression<String>? preparationName,
    Expression<int>? preparationTime,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (preparationName != null) 'preparation_name': preparationName,
      if (preparationTime != null) 'preparation_time': preparationTime,
      if (order != null) 'order': order,
    });
  }

  PreparationUsersCompanion copyWith(
      {Value<int>? id,
      Value<int>? userId,
      Value<String>? preparationName,
      Value<int>? preparationTime,
      Value<int>? order}) {
    return PreparationUsersCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (preparationName.present) {
      map['preparation_name'] = Variable<String>(preparationName.value);
    }
    if (preparationTime.present) {
      map['preparation_time'] = Variable<int>(preparationTime.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreparationUsersCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('preparationName: $preparationName, ')
          ..write('preparationTime: $preparationTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $SchedulesTable schedules = $SchedulesTable(this);
  late final $PreparationSchedulesTable preparationSchedules =
      $PreparationSchedulesTable(this);
  late final $PreparationUsersTable preparationUsers =
      $PreparationUsersTable(this);
  late final ScheduleDao scheduleDao = ScheduleDao(this as AppDatabase);
  late final UserDao userDao = UserDao(this as AppDatabase);
  late final PreparationScheduleDao preparationScheduleDao =
      PreparationScheduleDao(this as AppDatabase);
  late final PreparationUserDao preparationUserDao =
      PreparationUserDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [places, users, schedules, preparationSchedules, preparationUsers];
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
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String email,
  required String password,
  required String name,
  required int spareTime,
  required String note,
  required double score,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> email,
  Value<String> password,
  Value<String> name,
  Value<int> spareTime,
  Value<String> note,
  Value<double> score,
});

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SchedulesTable, List<Schedule>>
      _schedulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.schedules,
          aliasName: $_aliasNameGenerator(db.users.id, db.schedules.userId));

  $$SchedulesTableProcessedTableManager get schedulesRefs {
    final manager = $$SchedulesTableTableManager($_db, $_db.schedules)
        .filter((f) => f.userId.id($_item.id));

    final cache = $_typedResult.readTableOrNull(_schedulesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PreparationUsersTable, List<PreparationUser>>
      _preparationUsersRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.preparationUsers,
              aliasName: $_aliasNameGenerator(
                  db.users.id, db.preparationUsers.userId));

  $$PreparationUsersTableProcessedTableManager get preparationUsersRefs {
    final manager =
        $$PreparationUsersTableTableManager($_db, $_db.preparationUsers)
            .filter((f) => f.userId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_preparationUsersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get spareTime => $composableBuilder(
      column: $table.spareTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  Expression<bool> schedulesRefs(
      Expression<bool> Function($$SchedulesTableFilterComposer f) f) {
    final $$SchedulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.userId,
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

  Expression<bool> preparationUsersRefs(
      Expression<bool> Function($$PreparationUsersTableFilterComposer f) f) {
    final $$PreparationUsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.preparationUsers,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PreparationUsersTableFilterComposer(
              $db: $db,
              $table: $db.preparationUsers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get spareTime => $composableBuilder(
      column: $table.spareTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get spareTime =>
      $composableBuilder(column: $table.spareTime, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  Expression<T> schedulesRefs<T extends Object>(
      Expression<T> Function($$SchedulesTableAnnotationComposer a) f) {
    final $$SchedulesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.userId,
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

  Expression<T> preparationUsersRefs<T extends Object>(
      Expression<T> Function($$PreparationUsersTableAnnotationComposer a) f) {
    final $$PreparationUsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.preparationUsers,
        getReferencedColumn: (t) => t.userId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PreparationUsersTableAnnotationComposer(
              $db: $db,
              $table: $db.preparationUsers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool schedulesRefs, bool preparationUsersRefs})> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> password = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> spareTime = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<double> score = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            email: email,
            password: password,
            name: name,
            spareTime: spareTime,
            note: note,
            score: score,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String email,
            required String password,
            required String name,
            required int spareTime,
            required String note,
            required double score,
          }) =>
              UsersCompanion.insert(
            id: id,
            email: email,
            password: password,
            name: name,
            spareTime: spareTime,
            note: note,
            score: score,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$UsersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {schedulesRefs = false, preparationUsersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (schedulesRefs) db.schedules,
                if (preparationUsersRefs) db.preparationUsers
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (schedulesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$UsersTableReferences._schedulesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsersTableReferences(db, table, p0).schedulesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.userId == item.id),
                        typedResults: items),
                  if (preparationUsersRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$UsersTableReferences
                            ._preparationUsersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsersTableReferences(db, table, p0)
                                .preparationUsersRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.userId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, $$UsersTableReferences),
    User,
    PrefetchHooks Function({bool schedulesRefs, bool preparationUsersRefs})>;
typedef $$SchedulesTableCreateCompanionBuilder = SchedulesCompanion Function({
  Value<int> id,
  required int userId,
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
  Value<int> userId,
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

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users
      .createAlias($_aliasNameGenerator(db.schedules.userId, db.users.id));

  $$UsersTableProcessedTableManager? get userId {
    if ($_item.userId == null) return null;
    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.id($_item.userId!));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

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

  static MultiTypedResultKey<$PreparationSchedulesTable,
      List<PreparationSchedule>> _preparationSchedulesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.preparationSchedules,
          aliasName: $_aliasNameGenerator(
              db.schedules.id, db.preparationSchedules.scheduleId));

  $$PreparationSchedulesTableProcessedTableManager
      get preparationSchedulesRefs {
    final manager =
        $$PreparationSchedulesTableTableManager($_db, $_db.preparationSchedules)
            .filter((f) => f.scheduleId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_preparationSchedulesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
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

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

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

  Expression<bool> preparationSchedulesRefs(
      Expression<bool> Function($$PreparationSchedulesTableFilterComposer f)
          f) {
    final $$PreparationSchedulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.preparationSchedules,
        getReferencedColumn: (t) => t.scheduleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PreparationSchedulesTableFilterComposer(
              $db: $db,
              $table: $db.preparationSchedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
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

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableOrderingComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

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

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

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

  Expression<T> preparationSchedulesRefs<T extends Object>(
      Expression<T> Function($$PreparationSchedulesTableAnnotationComposer a)
          f) {
    final $$PreparationSchedulesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.preparationSchedules,
            getReferencedColumn: (t) => t.scheduleId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$PreparationSchedulesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.preparationSchedules,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
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
    PrefetchHooks Function(
        {bool userId, bool placeId, bool preparationSchedulesRefs})> {
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
            Value<int> userId = const Value.absent(),
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
            userId: userId,
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
            required int userId,
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
            userId: userId,
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
          prefetchHooksCallback: (
              {userId = false,
              placeId = false,
              preparationSchedulesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (preparationSchedulesRefs) db.preparationSchedules
              ],
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
                if (userId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.userId,
                    referencedTable:
                        $$SchedulesTableReferences._userIdTable(db),
                    referencedColumn:
                        $$SchedulesTableReferences._userIdTable(db).id,
                  ) as T;
                }
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
                return [
                  if (preparationSchedulesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$SchedulesTableReferences
                            ._preparationSchedulesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SchedulesTableReferences(db, table, p0)
                                .preparationSchedulesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.scheduleId == item.id),
                        typedResults: items)
                ];
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
    PrefetchHooks Function(
        {bool userId, bool placeId, bool preparationSchedulesRefs})>;
typedef $$PreparationSchedulesTableCreateCompanionBuilder
    = PreparationSchedulesCompanion Function({
  Value<int> id,
  required int scheduleId,
  required String preparationName,
  required int preparationTime,
  required int order,
});
typedef $$PreparationSchedulesTableUpdateCompanionBuilder
    = PreparationSchedulesCompanion Function({
  Value<int> id,
  Value<int> scheduleId,
  Value<String> preparationName,
  Value<int> preparationTime,
  Value<int> order,
});

final class $$PreparationSchedulesTableReferences extends BaseReferences<
    _$AppDatabase, $PreparationSchedulesTable, PreparationSchedule> {
  $$PreparationSchedulesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SchedulesTable _scheduleIdTable(_$AppDatabase db) =>
      db.schedules.createAlias($_aliasNameGenerator(
          db.preparationSchedules.scheduleId, db.schedules.id));

  $$SchedulesTableProcessedTableManager? get scheduleId {
    if ($_item.scheduleId == null) return null;
    final manager = $$SchedulesTableTableManager($_db, $_db.schedules)
        .filter((f) => f.id($_item.scheduleId!));
    final item = $_typedResult.readTableOrNull(_scheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PreparationSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $PreparationSchedulesTable> {
  $$PreparationSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preparationName => $composableBuilder(
      column: $table.preparationName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  $$SchedulesTableFilterComposer get scheduleId {
    final $$SchedulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scheduleId,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$PreparationSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreparationSchedulesTable> {
  $$PreparationSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preparationName => $composableBuilder(
      column: $table.preparationName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  $$SchedulesTableOrderingComposer get scheduleId {
    final $$SchedulesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scheduleId,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SchedulesTableOrderingComposer(
              $db: $db,
              $table: $db.schedules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PreparationSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreparationSchedulesTable> {
  $$PreparationSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get preparationName => $composableBuilder(
      column: $table.preparationName, builder: (column) => column);

  GeneratedColumn<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  $$SchedulesTableAnnotationComposer get scheduleId {
    final $$SchedulesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.scheduleId,
        referencedTable: $db.schedules,
        getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$PreparationSchedulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PreparationSchedulesTable,
    PreparationSchedule,
    $$PreparationSchedulesTableFilterComposer,
    $$PreparationSchedulesTableOrderingComposer,
    $$PreparationSchedulesTableAnnotationComposer,
    $$PreparationSchedulesTableCreateCompanionBuilder,
    $$PreparationSchedulesTableUpdateCompanionBuilder,
    (PreparationSchedule, $$PreparationSchedulesTableReferences),
    PreparationSchedule,
    PrefetchHooks Function({bool scheduleId})> {
  $$PreparationSchedulesTableTableManager(
      _$AppDatabase db, $PreparationSchedulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreparationSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreparationSchedulesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreparationSchedulesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> scheduleId = const Value.absent(),
            Value<String> preparationName = const Value.absent(),
            Value<int> preparationTime = const Value.absent(),
            Value<int> order = const Value.absent(),
          }) =>
              PreparationSchedulesCompanion(
            id: id,
            scheduleId: scheduleId,
            preparationName: preparationName,
            preparationTime: preparationTime,
            order: order,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int scheduleId,
            required String preparationName,
            required int preparationTime,
            required int order,
          }) =>
              PreparationSchedulesCompanion.insert(
            id: id,
            scheduleId: scheduleId,
            preparationName: preparationName,
            preparationTime: preparationTime,
            order: order,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PreparationSchedulesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({scheduleId = false}) {
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
                if (scheduleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.scheduleId,
                    referencedTable: $$PreparationSchedulesTableReferences
                        ._scheduleIdTable(db),
                    referencedColumn: $$PreparationSchedulesTableReferences
                        ._scheduleIdTable(db)
                        .id,
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

typedef $$PreparationSchedulesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PreparationSchedulesTable,
        PreparationSchedule,
        $$PreparationSchedulesTableFilterComposer,
        $$PreparationSchedulesTableOrderingComposer,
        $$PreparationSchedulesTableAnnotationComposer,
        $$PreparationSchedulesTableCreateCompanionBuilder,
        $$PreparationSchedulesTableUpdateCompanionBuilder,
        (PreparationSchedule, $$PreparationSchedulesTableReferences),
        PreparationSchedule,
        PrefetchHooks Function({bool scheduleId})>;
typedef $$PreparationUsersTableCreateCompanionBuilder
    = PreparationUsersCompanion Function({
  Value<int> id,
  required int userId,
  required String preparationName,
  required int preparationTime,
  required int order,
});
typedef $$PreparationUsersTableUpdateCompanionBuilder
    = PreparationUsersCompanion Function({
  Value<int> id,
  Value<int> userId,
  Value<String> preparationName,
  Value<int> preparationTime,
  Value<int> order,
});

final class $$PreparationUsersTableReferences extends BaseReferences<
    _$AppDatabase, $PreparationUsersTable, PreparationUser> {
  $$PreparationUsersTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
      $_aliasNameGenerator(db.preparationUsers.userId, db.users.id));

  $$UsersTableProcessedTableManager? get userId {
    if ($_item.userId == null) return null;
    final manager = $$UsersTableTableManager($_db, $_db.users)
        .filter((f) => f.id($_item.userId!));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PreparationUsersTableFilterComposer
    extends Composer<_$AppDatabase, $PreparationUsersTable> {
  $$PreparationUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preparationName => $composableBuilder(
      column: $table.preparationName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableFilterComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PreparationUsersTableOrderingComposer
    extends Composer<_$AppDatabase, $PreparationUsersTable> {
  $$PreparationUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preparationName => $composableBuilder(
      column: $table.preparationName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableOrderingComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PreparationUsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreparationUsersTable> {
  $$PreparationUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get preparationName => $composableBuilder(
      column: $table.preparationName, builder: (column) => column);

  GeneratedColumn<int> get preparationTime => $composableBuilder(
      column: $table.preparationTime, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.userId,
        referencedTable: $db.users,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsersTableAnnotationComposer(
              $db: $db,
              $table: $db.users,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PreparationUsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PreparationUsersTable,
    PreparationUser,
    $$PreparationUsersTableFilterComposer,
    $$PreparationUsersTableOrderingComposer,
    $$PreparationUsersTableAnnotationComposer,
    $$PreparationUsersTableCreateCompanionBuilder,
    $$PreparationUsersTableUpdateCompanionBuilder,
    (PreparationUser, $$PreparationUsersTableReferences),
    PreparationUser,
    PrefetchHooks Function({bool userId})> {
  $$PreparationUsersTableTableManager(
      _$AppDatabase db, $PreparationUsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreparationUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreparationUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreparationUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> userId = const Value.absent(),
            Value<String> preparationName = const Value.absent(),
            Value<int> preparationTime = const Value.absent(),
            Value<int> order = const Value.absent(),
          }) =>
              PreparationUsersCompanion(
            id: id,
            userId: userId,
            preparationName: preparationName,
            preparationTime: preparationTime,
            order: order,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int userId,
            required String preparationName,
            required int preparationTime,
            required int order,
          }) =>
              PreparationUsersCompanion.insert(
            id: id,
            userId: userId,
            preparationName: preparationName,
            preparationTime: preparationTime,
            order: order,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PreparationUsersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
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
                if (userId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.userId,
                    referencedTable:
                        $$PreparationUsersTableReferences._userIdTable(db),
                    referencedColumn:
                        $$PreparationUsersTableReferences._userIdTable(db).id,
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

typedef $$PreparationUsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PreparationUsersTable,
    PreparationUser,
    $$PreparationUsersTableFilterComposer,
    $$PreparationUsersTableOrderingComposer,
    $$PreparationUsersTableAnnotationComposer,
    $$PreparationUsersTableCreateCompanionBuilder,
    $$PreparationUsersTableUpdateCompanionBuilder,
    (PreparationUser, $$PreparationUsersTableReferences),
    PreparationUser,
    PrefetchHooks Function({bool userId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$SchedulesTableTableManager get schedules =>
      $$SchedulesTableTableManager(_db, _db.schedules);
  $$PreparationSchedulesTableTableManager get preparationSchedules =>
      $$PreparationSchedulesTableTableManager(_db, _db.preparationSchedules);
  $$PreparationUsersTableTableManager get preparationUsers =>
      $$PreparationUsersTableTableManager(_db, _db.preparationUsers);
}
