import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class DeletePreparationUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  DeletePreparationUseCase(this.remoteDataSource);

  Future<PreparationEntity> call(PreparationEntity preparationEntity) async {
    return await remoteDataSource.deletePreparation(preparationEntity);
  }
}
