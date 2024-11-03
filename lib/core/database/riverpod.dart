import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'riverpod.g.dart';

@riverpod
AppDatabase appDatabse(Ref ref) {
  return AppDatabase();
}
