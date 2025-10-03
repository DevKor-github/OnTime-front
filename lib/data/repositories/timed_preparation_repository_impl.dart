import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Singleton(as: TimedPreparationRepository)
class TimedPreparationRepositoryImpl implements TimedPreparationRepository {
  final PreparationWithTimeLocalDataSource localDataSource;

  TimedPreparationRepositoryImpl({required this.localDataSource});

  @override
  Future<void> clearTimedPreparation(String scheduleId) {
    return localDataSource.clearPreparation(scheduleId);
  }

  @override
  Future<PreparationWithTimeEntity?> getTimedPreparation(String scheduleId) {
    return localDataSource.loadPreparation(scheduleId);
  }

  @override
  Future<void> saveTimedPreparation(
      String scheduleId, PreparationWithTimeEntity preparation) {
    return localDataSource.savePreparation(scheduleId, preparation);
  }
}
