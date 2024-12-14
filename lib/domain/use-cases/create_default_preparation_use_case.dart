import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class CreateDefaultPreparationUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  CreateDefaultPreparationUseCase(this.remoteDataSource);

  Future<void> call(PreparationEntity preparationEntity, String userId) async {
    await remoteDataSource.createDefaultPreparation(preparationEntity, userId);
  }
}
