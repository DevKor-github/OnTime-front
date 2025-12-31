import 'package:mockito/annotations.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';

import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

@GenerateMocks(
  [
    ScheduleLocalDataSource,
    ScheduleRemoteDataSource,
    PreparationRemoteDataSource,
    PreparationLocalDataSource,
    AppDio,
    ErrorLoggerService,
  ],
)
void main() {}
