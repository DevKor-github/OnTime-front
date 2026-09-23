import 'package:drift/drift.dart';

/// Immutable definitions can later also be owned by named user templates.
class PreparationDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get scope => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class PreparationDefinitionSteps extends Table {
  TextColumn get id => text()();
  TextColumn get definitionId =>
      text().references(PreparationDefinitions, #id)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get minutes =>
      integer().customConstraint('NOT NULL CHECK (minutes >= 0)')();
  IntColumn get position =>
      integer().customConstraint('NOT NULL CHECK (position >= 0)')();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {definitionId, position},
  ];
}

class RecurringScheduleSegments extends Table {
  TextColumn get id => text()();
  TextColumn get seriesId => text()();
  TextColumn get ruleJson => text()();
  TextColumn get scheduleJson => text()();
  TextColumn get preparationId =>
      text().references(PreparationDefinitions, #id)();

  /// Inclusive lower bound for the original civil slot, separate from rule anchor.
  TextColumn get fromSlot => text()();
  TextColumn get beforeSlot => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Frozen creation cutoff; reopening the app must not move the first slot.
  DateTimeColumn get preparationNotBefore => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class RecurringScheduleExclusions extends Table {
  TextColumn get segmentId =>
      text().references(RecurringScheduleSegments, #id)();
  TextColumn get slotKey => text()();
  IntColumn get ordinal => integer()();
  @override
  Set<Column> get primaryKey => {segmentId, slotKey};
}
