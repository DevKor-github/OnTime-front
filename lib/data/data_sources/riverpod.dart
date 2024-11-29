import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/dio/riverpod.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'riverpod.g.dart';

@riverpod
ScheduleRemoteDataSource scheduleRemoteDataSource(Ref ref) {
  final dio = ref.read(dioProvider);
  return ScheduleRemoteDataSourceImpl(dio);
}

@riverpod
ScheduleLocalDataSource scheduleLocalDataSource(Ref ref) {
  return ScheduleLocalDataSourceImpl(appDatabase: AppDatabase());
}
