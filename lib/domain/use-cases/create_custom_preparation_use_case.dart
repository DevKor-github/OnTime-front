import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class CreateCustomPreparationUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  CreateCustomPreparationUseCase(this.remoteDataSource);

  Future<void> call(
      PreparationEntity preparationEntity, String scheduleId) async {
    await remoteDataSource.createCustomPreparation(
        preparationEntity, scheduleId);
  }
}
