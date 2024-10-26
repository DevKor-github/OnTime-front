import 'package:drift/drift.dart';

class Places extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get placeName => text()();
}
