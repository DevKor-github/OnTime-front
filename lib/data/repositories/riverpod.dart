import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/data/data_sources/riverpod.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'riverpod.g.dart';

@riverpod
ScheduleRepository scheduleRepository(Ref ref) {
  final scheduleRemoteDataSource = ref.read(scheduleRemoteDataSourceProvider);
  final scheduleLocalDataSource = ref.read(scheduleLocalDataSourceProvider);
  return ScheduleRepositoryImpl(
    scheduleRemoteDataSource: scheduleRemoteDataSource,
    scheduleLocalDataSource: scheduleLocalDataSource,
  );
}
