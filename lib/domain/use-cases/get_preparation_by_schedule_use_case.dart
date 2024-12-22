import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class GetPreparationByScheduleIdUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  GetPreparationByScheduleIdUseCase(this.remoteDataSource);

  Future<PreparationEntity> call(String scheduleId) async {
    return await remoteDataSource.getPreparationByScheduleId(scheduleId);
  }
}
