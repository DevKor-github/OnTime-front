import 'package:mockito/annotations.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';

@GenerateMocks(
  [
    ScheduleLocalDataSource,
    ScheduleRemoteDataSource,
  ],
)
void main() {}
